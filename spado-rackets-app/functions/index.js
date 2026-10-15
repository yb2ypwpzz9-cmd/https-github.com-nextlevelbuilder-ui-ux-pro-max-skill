/**
 * Cloud Functions de Spado Rackets.
 *
 * Aquí vive lo que la app no puede hacer por sí misma sin abrir agujeros:
 *
 *  - Comprobar el código de vinculación y unir una alumna a su familia.
 *  - Crear cuentas de staff y Dirección (sólo Dirección puede pedirlo).
 *  - Mantener quién participa en cada chat de grupo y en los avisos.
 *  - Contadores de no leídos y notificaciones push.
 *
 * Despliegue:  firebase deploy --only functions
 */

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentWritten, onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import { logger } from 'firebase-functions';
import { randomInt } from 'node:crypto';

initializeApp();
const db = getFirestore();

// Región más cercana a República Dominicana y tope de instancias para que un
// pico inesperado no dispare la factura.
setGlobalOptions({ region: 'us-east1', maxInstances: 10 });

const ROLES_CLUB = ['staff', 'direccion'];

// ------------------------------------------------------------------ utilidades

/** Nombre visible, igual que `AppUser.nombreVisible` en la app. Nunca vacío. */
function nombreVisible(user) {
  const nombre = String(user?.displayName ?? '').trim();
  if (nombre) return nombre;
  const correo = String(user?.email ?? '').trim();
  return (correo.split('@')[0] || 'Sin nombre');
}

async function notificar(uids, { title, body, data = {} }) {
  const unicos = [...new Set(uids.filter(Boolean))];
  for (const uid of unicos) {
    const snap = await db.doc(`users/${uid}`).get();
    const tokens = snap.get('fcmTokens');
    if (!Array.isArray(tokens) || tokens.length === 0) continue;

    const r = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      webpush: { fcmOptions: { link: '/' } },
    });

    // Tokens caducados (navegador reinstalado, permisos quitados): fuera.
    const muertos = [];
    r.responses.forEach((res, i) => {
      const code = res.error?.code ?? '';
      if (code.includes('registration-token-not-registered') ||
          code.includes('invalid-registration-token') ||
          code.includes('invalid-argument')) {
        muertos.push(tokens[i]);
      }
    });
    if (muertos.length) {
      await snap.ref.update({ fcmTokens: FieldValue.arrayRemove(...muertos) });
    }
  }
}

async function uidsDireccion() {
  const s = await db.collection('users').where('role', '==', 'direccion').get();
  return s.docs.map((d) => d.id);
}

/**
 * Recalcula los participantes del canal de avisos y de cada chat de grupo.
 *
 * Con un club pequeño (decenas de usuarios) es más simple y más seguro
 * recalcularlo todo que llevar altas y bajas una a una: no hay estados
 * intermedios que se queden mal.
 *
 *   avisos      → todos los usuarios
 *   g_{grupo}   → familias y staff de ese grupo + Dirección
 */
async function recalcularParticipantes() {
  const [usuarios, grupos] = await Promise.all([
    db.collection('users').get(),
    db.collection('grupos').get(),
  ]);

  const todos = usuarios.docs.map((d) => d.id).sort();
  const direccion = usuarios.docs
    .filter((d) => d.get('role') === 'direccion')
    .map((d) => d.id);

  const batch = db.batch();

  batch.set(db.doc('conversaciones/avisos'), {
    tipo: 'avisos',
    titulo: 'Avisos del club',
    participantes: todos,
  }, { merge: true });

  for (const g of grupos.docs) {
    const delGrupo = usuarios.docs
      .filter((u) => {
        const grupos = u.get('grupos');
        return Array.isArray(grupos) && grupos.includes(g.id);
      })
      .map((u) => u.id);

    batch.set(db.doc(`conversaciones/g_${g.id}`), {
      tipo: 'grupo',
      grupo: g.id,
      titulo: String(g.get('nombre') ?? 'Grupo'),
      participantes: [...new Set([...delGrupo, ...direccion])].sort(),
    }, { merge: true });
  }

  await batch.commit();
}

// --------------------------------------------------------- vincular alumna

/**
 * Une una alumna a la cuenta de su familia a partir del código del club.
 *
 * Esto no puede hacerlo la app: una regla de Firestore no puede comprobar un
 * código —lo aporta quien escribe—, así que abrir esa escritura dejaría a
 * cualquiera con una cuenta adoptar a una menor ajena. Aquí el código se
 * comprueba y se marca como usado: uno por alumna, una sola vez.
 */
export const vincularAlumna = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión para vincular.');

  const codigo = String(req.data?.codigo ?? '').trim().toUpperCase();
  if (!codigo || codigo.length > 20) {
    throw new HttpsError('invalid-argument', 'Escribe el código que te dio el club.');
  }

  const usuario = await db.doc(`users/${uid}`).get();
  if (usuario.exists && usuario.get('role') !== 'familia') {
    throw new HttpsError('permission-denied', 'Sólo las familias vinculan alumnas.');
  }

  return db.runTransaction(async (tx) => {
    const encontrados = await tx.get(
      db.collection('codigosVinculacion').where('codigo', '==', codigo).limit(1),
    );
    if (encontrados.empty) {
      throw new HttpsError('not-found', 'Código no válido. Revísalo o contacta con el club.');
    }
    const codigoDoc = encontrados.docs[0];
    if (codigoDoc.get('usadoPor')) {
      throw new HttpsError('already-exists', 'Ese código ya se usó. Contacta con el club.');
    }

    const alumnaRef = db.doc(`alumnas/${codigoDoc.get('alumnaId')}`);
    const alumna = await tx.get(alumnaRef);
    if (!alumna.exists) {
      throw new HttpsError('not-found', 'Esa alumna ya no está en el club.');
    }
    const actual = alumna.get('familiaUid');
    if (actual && actual !== uid) {
      throw new HttpsError('already-exists', 'Esa alumna ya está vinculada a otra cuenta.');
    }

    // Si Dirección dio de alta el correo de la familia, sólo ese correo puede
    // usar el código. Es lo que impide que alguien con un código ajeno
    // (fotografiado, reenviado) se registre con otro correo.
    const previo = String(alumna.get('emailFamilia') ?? '').trim().toLowerCase();
    const correo = String(req.auth?.token?.email ?? '').trim().toLowerCase();
    if (previo && previo !== correo) {
      throw new HttpsError(
        'permission-denied',
        'Este código está reservado a otro correo. Regístrate con el email que diste al club.',
      );
    }

    tx.update(alumnaRef, { familiaUid: uid });
    tx.update(codigoDoc.ref, { usadoPor: uid, usadoEn: FieldValue.serverTimestamp() });
    // Los grupos de la familia los recalcula `sincronizarAlumna`; se adelanta
    // aquí para que al terminar el registro ya vea a su hija.
    tx.set(db.doc(`users/${uid}`), {
      grupos: FieldValue.arrayUnion(alumna.get('grupo')),
    }, { merge: true });

    logger.info(`Alumna ${alumna.id} vinculada a ${uid}`);
    return { nombre: alumna.get('nombre') ?? '' };
  });
});

// --------------------------------------------------- cuentas del club

/**
 * Crea una cuenta de staff o Dirección. Sólo la puede pedir Dirección.
 * Devuelve una contraseña provisional que Dirección entrega en mano; la
 * persona la cambia desde "Más".
 */
export const crearCuentaClub = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión.');
  const quien = await db.doc(`users/${uid}`).get();
  if (quien.get('role') !== 'direccion') {
    throw new HttpsError('permission-denied', 'Sólo Dirección puede crear cuentas.');
  }

  const email = String(req.data?.email ?? '').trim().toLowerCase();
  const nombre = String(req.data?.nombre ?? '').trim().slice(0, 80);
  const rol = String(req.data?.rol ?? '');
  const grupos = Array.isArray(req.data?.grupos)
    ? req.data.grupos.filter((g) => typeof g === 'string' && g).slice(0, 30)
    : [];

  if (!email.includes('@') || nombre.length < 2 || !ROLES_CLUB.includes(rol)) {
    throw new HttpsError('invalid-argument', 'Revisa el nombre, el email y el rol.');
  }

  // Sin caracteres que se confundan al dictarla.
  const letras = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  const password = Array.from({ length: 10 }, () => letras[randomInt(letras.length)]).join('');

  let nuevo;
  try {
    nuevo = await getAuth().createUser({ email, password, displayName: nombre });
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'Ya existe una cuenta con ese email.');
    }
    throw new HttpsError('internal', 'No se pudo crear la cuenta.');
  }

  await db.doc(`users/${nuevo.uid}`).set({
    uid: nuevo.uid,
    email,
    role: rol,
    displayName: nombre,
    grupos: rol === 'staff' ? grupos : [],
    createdAt: FieldValue.serverTimestamp(),
    creadoPor: uid,
  });

  logger.info(`Cuenta ${rol} creada para ${email} por ${uid}`);
  return { passwordProvisional: password };
});

// --------------------------------------------------- sincronizaciones

/**
 * Cada cambio de usuario mantiene el directorio (nombre y rol, lo único que
 * otros pueden ver) y, si cambian rol o grupos, los participantes del chat.
 */
export const sincronizarUsuario = onDocumentWritten('users/{uid}', async (event) => {
  const { uid } = event.params;
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();

  if (!despues) {
    await db.doc(`directorio/${uid}`).delete().catch(() => {});
    await recalcularParticipantes();
    return;
  }

  const rol = ['familia', 'staff', 'direccion'].includes(despues.role) ? despues.role : 'familia';
  const grupos = Array.isArray(despues.grupos) ? [...new Set(despues.grupos)].sort() : [];
  const nombre = nombreVisible(despues);

  const mismoNombre = antes && nombreVisible(antes) === nombre;
  const mismoRol = antes && antes.role === despues.role;
  const mismosGrupos = antes &&
    JSON.stringify([...new Set(antes.grupos ?? [])].sort()) === JSON.stringify(grupos);

  // Guardar un token de avisos no debe reescribir nada.
  if (!(mismoNombre && mismoRol && mismosGrupos)) {
    await db.doc(`directorio/${uid}`).set(
      { nombre, rol, grupos, actualizadoEn: FieldValue.serverTimestamp() },
      { merge: true },
    );
  }
  if (!(mismoRol && mismosGrupos)) await recalcularParticipantes();
});

/**
 * Los grupos de una familia salen de sus alumnas. Se recalculan para la
 * familia que gana una alumna y para la que la pierde.
 */
export const sincronizarAlumna = onDocumentWritten('alumnas/{id}', async (event) => {
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();
  if (antes?.familiaUid === despues?.familiaUid &&
      antes?.grupo === despues?.grupo &&
      antes?.activa === despues?.activa) return;

  // Cuotas generadas antes de que la familia se registrara: pasan a ser suyas.
  if (despues?.familiaUid && antes?.familiaUid !== despues.familiaUid) {
    const sueltas = await db.collection('pagos')
      .where('alumnaId', '==', event.params.id)
      .where('familiaUid', '==', '')
      .get();
    if (!sueltas.empty) {
      const batch = db.batch();
      sueltas.docs.forEach((d) => batch.update(d.ref, { familiaUid: despues.familiaUid }));
      await batch.commit();
    }
  }

  for (const uid of new Set([antes?.familiaUid, despues?.familiaUid].filter(Boolean))) {
    const ref = db.doc(`users/${uid}`);
    const user = await ref.get();
    if (!user.exists || user.get('role') !== 'familia') continue;

    const hijas = await db.collection('alumnas').where('familiaUid', '==', uid).get();
    const grupos = [...new Set(
      hijas.docs.filter((d) => d.get('activa') !== false).map((d) => d.get('grupo')).filter(Boolean),
    )].sort();
    await ref.update({ grupos });
  }
});

export const sincronizarGrupo = onDocumentWritten('grupos/{id}', async (event) => {
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();
  if (antes && despues && antes.nombre === despues.nombre) return;

  // Grupo eliminado: se borra su chat y se quita de las cuentas del staff.
  if (antes && !despues) {
    const { id } = event.params;
    await db.recursiveDelete(db.doc(`conversaciones/g_${id}`));
    const conEl = await db.collection('users').where('grupos', 'array-contains', id).get();
    for (const u of conEl.docs) {
      await u.ref.update({ grupos: FieldValue.arrayRemove(id) });
    }
  }
  await recalcularParticipantes();
});

// ------------------------------------------------------------- mensajes

/**
 * Al llegar un mensaje: último mensaje, contadores de no leídos de los demás
 * y aviso push. Se hace aquí y no en la app para que nadie pueda inflar ni
 * borrar los contadores de otro.
 */
export const alCrearMensaje = onDocumentCreated(
  'conversaciones/{conversacionId}/mensajes/{mensajeId}',
  async (event) => {
    const m = event.data?.data();
    if (!m) return;
    const { conversacionId } = event.params;
    const ref = db.doc(`conversaciones/${conversacionId}`);
    const conv = (await ref.get()).data();
    if (!conv) return;

    const destinatarios = (conv.participantes ?? []).filter((u) => u !== m.autorUid);
    const texto = String(m.texto ?? '');

    const cambios = {
      ultimoMensaje: texto.slice(0, 140),
      ultimoAutor: m.autorNombre ?? '',
      ultimoMensajeEn: m.creadoEn ?? FieldValue.serverTimestamp(),
    };
    for (const uid of destinatarios) cambios[`sinLeer.${uid}`] = FieldValue.increment(1);
    await ref.update(cambios);

    const titulo = conv.tipo === 'avisos'
      ? 'Aviso del club'
      : conv.tipo === 'grupo' ? (conv.titulo || 'Grupo') : (m.autorNombre || 'Mensaje');
    await notificar(destinatarios, {
      title: titulo,
      body: conv.tipo === 'directa' ? texto.slice(0, 120) : `${m.autorNombre}: ${texto.slice(0, 110)}`,
      data: { tipo: 'chat', conversacionId },
    });
  },
);

// ---------------------------------------------------------------- pagos

/**
 * Confirmación a la familia cuando el entrenador pasa lista y su hija está
 * presente. Es lo único que reciben de la asistencia: ni fichajes ni listas.
 */
export const avisarAsistencia = onDocumentWritten('asistencias/{id}', async (event) => {
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();
  if (!despues || despues.estado !== 'presente' || antes?.estado === 'presente') return;
  if (!despues.familiaUid) return;
  const grupo = await db.doc(`grupos/${despues.grupo}`).get();
  await notificar([despues.familiaUid], {
    title: `${String(despues.alumnaNombre ?? 'Tu hija').split(' ')[0]} está en el entrenamiento`,
    body: `El entrenador ha confirmado su asistencia${grupo.exists ? ` a ${grupo.get('nombre')}` : ''}.`,
    data: { tipo: 'asistencia' },
  });
});

/** Aviso a la familia cuando Dirección genera su cuota del mes. */
export const avisarCuotaNueva = onDocumentCreated('pagos/{id}', async (event) => {
  const p = event.data?.data();
  if (!p?.familiaUid) return; // aún sin cuenta: se avisará al asociarla en la app
  const importe = Number(p.importe ?? 0).toLocaleString('en-US', { minimumFractionDigits: 2 });
  await notificar([p.familiaUid], {
    title: 'Nueva cuota',
    body: `${String(p.alumnaNombre ?? '').split(' ')[0]} · ${p.periodo}: US$ ${importe}. Plazo: hasta el día 5.`,
    data: { tipo: 'cuota' },
  });
});

/** Avisa a la familia cuando se valida o rechaza su pago, y a Dirección
 *  cuando llega un justificante nuevo. */
export const avisarPago = onDocumentWritten('pagos/{id}', async (event) => {
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();
  if (!despues || antes?.estado === despues.estado) return;

  const quien = despues.alumnaNombre ?? 'la alumna';
  const mes = despues.periodo ?? '';

  if (despues.estado === 'en_revision') {
    await notificar(await uidsDireccion(), {
      title: 'Justificante recibido',
      body: `${quien} · ${mes}. Pendiente de revisar.`,
      data: { tipo: 'pago' },
    });
  } else if (despues.estado === 'pagado' && antes?.estado) {
    await notificar([despues.familiaUid], {
      title: 'Pago confirmado',
      body: `La cuota de ${quien} (${mes}) está pagada. ¡Gracias!`,
      data: { tipo: 'pago' },
    });
  } else if (despues.estado === 'rechazado') {
    await notificar([despues.familiaUid], {
      title: 'Revisa tu justificante',
      body: despues.motivoRechazo || `No se pudo validar el pago de ${quien}.`,
      data: { tipo: 'pago' },
    });
  }
});

/** Avisa al staff del grupo cuando una familia comunica una falta. */
export const avisarAusencia = onDocumentCreated('ausencias/{id}', async (event) => {
  const a = event.data?.data();
  if (!a?.grupo) return;
  const staff = await db.collection('users')
    .where('role', '==', 'staff')
    .where('grupos', 'array-contains', a.grupo)
    .get();
  await notificar(staff.docs.map((d) => d.id), {
    title: 'Falta avisada',
    body: `${a.alumnaNombre} no vendrá el ${a.fecha}${a.motivo ? ` · ${a.motivo}` : ''}`,
    data: { tipo: 'ausencia' },
  });
});
