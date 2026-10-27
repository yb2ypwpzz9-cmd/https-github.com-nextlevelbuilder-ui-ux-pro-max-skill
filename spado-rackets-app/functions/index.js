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
import { getStorage } from 'firebase-admin/storage';
import { onDocumentWritten, onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { setGlobalOptions } from 'firebase-functions/v2';
import { logger } from 'firebase-functions';
import { randomInt } from 'node:crypto';

initializeApp({ storageBucket: `${process.env.GCLOUD_PROJECT}.firebasestorage.app` });
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
    if (!Array.isArray(tokens) || tokens.length === 0) {
      logger.info(`push "${title}": ${uid} no tiene dispositivos con avisos activados`);
      continue;
    }

    const r = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      webpush: { fcmOptions: { link: '/' } },
    });
    logger.info(
      `push "${title}" a ${uid}: ${r.successCount} enviados, ${r.failureCount} fallidos` +
      (r.failureCount ? ` (${r.responses.filter((x) => !x.success).map((x) => x.error?.code).join(', ')})` : ''),
    );

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
    // Grupo interno sin chat propio.
    if (g.get('sinChat') === true) continue;
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

  // Sin correo verificado, cualquiera podría registrarse con el email de otra
  // familia (o con uno inventado) y probar códigos.
  if (req.auth?.token?.email_verified !== true) {
    throw new HttpsError(
      'failed-precondition',
      'Verifica tu correo (te hemos enviado un enlace) antes de vincular a la alumna.',
    );
  }

  const codigo = String(req.data?.codigo ?? '').trim().toUpperCase();
  if (!codigo || codigo.length > 20) {
    throw new HttpsError('invalid-argument', 'Escribe el código que te dio el club.');
  }

  // Tope de fallos: por cuenta y para todo el club. Con decenas de familias,
  // pasar de aquí es un ataque, no un despiste.
  const claveUsuario = `vincular_${uid}`;
  const [porUsuario, global] = await Promise.all([
    fallosRecientes(claveUsuario),
    fallosRecientes('vincular_global'),
  ]);
  if (porUsuario >= MAX_FALLOS_USUARIO || global >= MAX_FALLOS_GLOBAL) {
    logger.warn(`Vinculación bloqueada por exceso de fallos (uid ${uid})`);
    throw new HttpsError(
      'resource-exhausted',
      'Demasiados intentos. Espera una hora o contacta con el club.',
    );
  }

  const usuario = await db.doc(`users/${uid}`).get();
  if (!usuario.exists) {
    throw new HttpsError('failed-precondition', 'Termina primero de crear tu cuenta.');
  }
  if (usuario.get('role') !== 'familia') {
    throw new HttpsError('permission-denied', 'Sólo las familias vinculan alumnas.');
  }

  try {
    return await db.runTransaction(async (tx) => {
      const encontrados = await tx.get(
        db.collection('codigosVinculacion').where('codigo', '==', codigo).limit(1),
      );
      if (encontrados.empty) throw new CodigoRechazado('no existe');
      const codigoDoc = encontrados.docs[0];
      if (codigoDoc.get('usadoPor') && codigoDoc.get('usadoPor') !== uid) {
        throw new CodigoRechazado('ya usado');
      }

      const alumnaRef = db.doc(`alumnas/${codigoDoc.get('alumnaId')}`);
      const alumna = await tx.get(alumnaRef);
      if (!alumna.exists) throw new CodigoRechazado('alumna eliminada');
      const actual = alumna.get('familiaUid');
      if (actual && actual !== uid) throw new CodigoRechazado('alumna de otra cuenta');

      // Si Dirección dio de alta el correo de la familia, sólo ese correo
      // (ya verificado) puede usar el código.
      const previo = String(alumna.get('emailFamilia') ?? '').trim().toLowerCase();
      const correo = String(req.auth?.token?.email ?? '').trim().toLowerCase();
      if (previo && previo !== correo) throw new CodigoRechazado('correo reservado');

      // Si la ficha no tenía contacto, se rellena con los datos de la cuenta.
      const contacto = {};
      if (!alumna.get('contactoNombre') && usuario.get('displayName')) {
        contacto.contactoNombre = String(usuario.get('displayName')).slice(0, 120);
      }
      if (!alumna.get('contactoTelefono') && usuario.get('phone')) {
        contacto.contactoTelefono = String(usuario.get('phone')).slice(0, 30);
      }
      tx.update(alumnaRef, { familiaUid: uid, ...contacto });
      tx.update(codigoDoc.ref, { usadoPor: uid, usadoEn: FieldValue.serverTimestamp() });
      // Los grupos de la familia los recalcula `sincronizarAlumna`; se adelanta
      // aquí para que al terminar el registro ya vea a su hija.
      tx.set(db.doc(`users/${uid}`), {
        grupos: FieldValue.arrayUnion(alumna.get('grupo')),
        codigoPendiente: FieldValue.delete(),
      }, { merge: true });

      logger.info(`Alumna ${alumna.id} vinculada a ${uid}`);
      return { nombre: alumna.get('nombre') ?? '' };
    });
  } catch (e) {
    if (e instanceof CodigoRechazado) {
      await Promise.all([anotarFallo(claveUsuario), anotarFallo('vincular_global')]);
      logger.warn(`Código rechazado (${e.motivo}) para ${uid}`);
      // Un único mensaje: distinguir "no existe" de "ya usado" o "reservado"
      // permitiría averiguar qué códigos son reales.
      throw new HttpsError(
        'not-found',
        'Código no válido o no disponible. Revísalo o contacta con el club.',
      );
    }
    throw e;
  }
});

class CodigoRechazado extends Error {
  constructor(motivo) {
    super(motivo);
    this.motivo = motivo;
  }
}

const VENTANA_MS = 60 * 60 * 1000;
const MAX_FALLOS_USUARIO = 5;
const MAX_FALLOS_GLOBAL = 40;

async function fallosRecientes(clave) {
  const d = await db.doc(`limites/${clave}`).get();
  const ahora = Date.now();
  return (d.get('fallos') ?? []).filter((t) => ahora - t < VENTANA_MS).length;
}

async function anotarFallo(clave) {
  const ref = db.doc(`limites/${clave}`);
  await db.runTransaction(async (tx) => {
    const d = await tx.get(ref);
    const ahora = Date.now();
    const fallos = [...(d.get('fallos') ?? []).filter((t) => ahora - t < VENTANA_MS), ahora];
    tx.set(ref, { fallos: fallos.slice(-100) });
  });
}

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
  const todosLosGrupos = String(req.data?.rol ?? '') === 'staff' || req.data?.todosLosGrupos === true;
  const grupos = todosLosGrupos
    ? (await db.collection('grupos').get()).docs.map((g) => g.id)
    : Array.isArray(req.data?.grupos)
      ? req.data.grupos.filter((g) => typeof g === 'string' && g).slice(0, 30)
      : [];

  if (!email.includes('@') || nombre.length < 2 || !ROLES_CLUB.includes(rol)) {
    throw new HttpsError('invalid-argument', 'Revisa el nombre, el email y el rol.');
  }

  // La persona elige su contraseña al activar la cuenta con el código; hasta
  // entonces la cuenta tiene una clave aleatoria que nadie conoce.
  const password = Array.from({ length: 24 }, () => ALFABETO_CLAVE[randomInt(ALFABETO_CLAVE.length)]).join('');
  const codigo = generarCodigoActivacion();

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
    todosLosGrupos: rol === 'staff' && todosLosGrupos,
    createdAt: FieldValue.serverTimestamp(),
    creadoPor: uid,
    pendienteActivacion: true,
  });
  await guardarCodigoActivacion(nuevo.uid, email, codigo);

  logger.info(`Cuenta ${rol} creada (${nuevo.uid}) por ${uid}`);
  return { codigoActivacion: codigo };
});

// ------------------------------------------------- activación de cuentas

const ALFABETO_CLAVE = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
const ALFABETO_CODIGO = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const VIGENCIA_CODIGO_MS = 14 * 24 * 60 * 60 * 1000;

function generarCodigoActivacion() {
  return Array.from({ length: 8 }, () => ALFABETO_CODIGO[randomInt(ALFABETO_CODIGO.length)]).join('');
}

async function guardarCodigoActivacion(uid, email, codigo) {
  await db.doc(`activaciones/${uid}`).set({
    email: String(email ?? '').toLowerCase(),
    codigo,
    expiraEn: Date.now() + VIGENCIA_CODIGO_MS,
  });
}

/**
 * Primer acceso del equipo: con el correo que dio de alta Dirección y el
 * código que le entregó, la persona elige su contraseña. No requiere sesión,
 * así que tiene tope de fallos por correo y para todo el club, y siempre
 * responde lo mismo si algo no cuadra.
 */
export const activarCuenta = onCall(async (req) => {
  const email = String(req.data?.email ?? '').trim().toLowerCase();
  const codigo = String(req.data?.codigo ?? '').trim().toUpperCase();
  const password = String(req.data?.password ?? '');
  if (!email.includes('@') || email.length > 120 || !codigo || codigo.length > 20) {
    throw new HttpsError('invalid-argument', 'Escribe tu correo y el código.');
  }
  if (password.length < 8 || password.length > 128) {
    throw new HttpsError('invalid-argument', 'La contraseña debe tener al menos 8 caracteres.');
  }

  const claveCorreo = `activar_${email}`;
  const [porCorreo, global] = await Promise.all([
    fallosRecientes(claveCorreo),
    fallosRecientes('activar_global'),
  ]);
  if (porCorreo >= MAX_FALLOS_USUARIO || global >= MAX_FALLOS_GLOBAL) {
    throw new HttpsError('resource-exhausted', 'Demasiados intentos. Espera una hora o avisa a Dirección.');
  }

  const rechazar = async () => {
    await Promise.all([anotarFallo(claveCorreo), anotarFallo('activar_global')]);
    throw new HttpsError('not-found', 'Código no válido o caducado. Pídele uno nuevo a Dirección.');
  };

  const encontrado = await db.collection('activaciones').where('email', '==', email).limit(1).get();
  if (encontrado.empty) return rechazar();
  const act = encontrado.docs[0];
  if (act.get('codigo') !== codigo || Date.now() > Number(act.get('expiraEn') ?? 0)) return rechazar();

  try {
    await getAuth().updateUser(act.id, { password, emailVerified: true });
  } catch (e) {
    throw new HttpsError('internal', 'No se pudo activar la cuenta.');
  }
  await db.doc(`users/${act.id}`).update({ pendienteActivacion: FieldValue.delete() });
  await act.ref.delete();
  logger.info(`Cuenta ${act.id} activada`);
  return { ok: true };
});

/** Comprueba que quien llama es Dirección y que el destino es una cuenta del club. */
async function cuentaDelClubParaGestionar(req) {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión.');
  const quien = await db.doc(`users/${uid}`).get();
  if (quien.get('role') !== 'direccion') {
    throw new HttpsError('permission-denied', 'Sólo Dirección puede gestionar cuentas.');
  }
  const destino = String(req.data?.uid ?? '');
  if (!destino || destino.length > 128) {
    throw new HttpsError('invalid-argument', 'Falta la cuenta.');
  }
  const doc = await db.doc(`users/${destino}`).get();
  if (!doc.exists) {
    throw new HttpsError('not-found', 'No existe esa cuenta.');
  }
  return { uid, destino, doc };
}

/** Elimina una cuenta (staff, Dirección o familia), acceso incluido. */
export const eliminarCuentaClub = onCall(async (req) => {
  const { uid, destino, doc } = await cuentaDelClubParaGestionar(req);
  if (destino === uid) {
    throw new HttpsError('failed-precondition', 'No puedes eliminar tu propia cuenta desde aquí.');
  }
  if (doc.get('role') === 'direccion') {
    const dirs = await db.collection('users').where('role', '==', 'direccion').get();
    if (dirs.size <= 1) {
      throw new HttpsError('failed-precondition', 'Tiene que quedar al menos una cuenta de Dirección.');
    }
  }
  await borrarCuentaYDatos(destino);
  logger.info(`Cuenta ${destino} eliminada por ${uid}`);
  return { ok: true };
});

/** Genera una contraseña provisional nueva para una cuenta del club. */
export const restablecerPasswordCuentaClub = onCall(async (req) => {
  const { uid, destino, doc } = await cuentaDelClubParaGestionar(req);

  // Cuenta que aún no se ha activado: se genera un código nuevo.
  if (doc.get('pendienteActivacion') === true) {
    const codigo = generarCodigoActivacion();
    await guardarCodigoActivacion(destino, doc.get('email'), codigo);
    return { codigoActivacion: codigo };
  }

  const letras = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  const password = Array.from({ length: 10 }, () => letras[randomInt(letras.length)]).join('');
  try {
    await getAuth().updateUser(destino, { password });
    await db.doc(`users/${destino}`).update({ debeCambiarPassword: true });
  } catch (e) {
    throw new HttpsError('internal', 'No se pudo cambiar la contraseña.');
  }
  logger.info(`Contraseña de ${destino} restablecida por ${uid}`);
  return { passwordProvisional: password };
});

// ------------------------------------------- derechos de la persona usuaria

function aJson(doc) {
  const limpiar = (v) => {
    if (v && typeof v.toDate === 'function') return v.toDate().toISOString();
    if (Array.isArray(v)) return v.map(limpiar);
    if (v && typeof v === 'object') {
      return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, limpiar(x)]));
    }
    return v;
  };
  return { id: doc.id, ...limpiar(doc.data()) };
}

/**
 * Devuelve todos los datos personales de quien llama, para que pueda
 * descargarlos (derecho de acceso y portabilidad).
 */
export const exportarMisDatos = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión.');

  const perfil = await db.doc(`users/${uid}`).get();
  if (!perfil.exists) throw new HttpsError('not-found', 'No hay datos de tu cuenta.');
  const datosPerfil = aJson(perfil);
  delete datosPerfil.fcmTokens; // identificadores técnicos del dispositivo

  const lista = async (coleccion, campo) =>
    (await db.collection(coleccion).where(campo, '==', uid).get()).docs.map(aJson);

  const [alumnas, pagos, asistencias, ausencias, jornadas] = await Promise.all([
    lista('alumnas', 'familiaUid'),
    lista('pagos', 'familiaUid'),
    lista('asistencias', 'familiaUid'),
    lista('ausencias', 'familiaUid'),
    lista('jornadas', 'staffUid'),
  ]);

  const convs = await db.collection('conversaciones').where('participantes', 'array-contains', uid).get();
  const mensajes = [];
  for (const c of convs.docs) {
    const propios = await c.ref.collection('mensajes').where('autorUid', '==', uid).get();
    for (const m of propios.docs) mensajes.push({ conversacion: c.id, ...aJson(m) });
  }

  return {
    generadoEn: new Date().toISOString(),
    cuenta: datosPerfil,
    alumnas, cuotas: pagos, asistencia: asistencias, ausenciasAvisadas: ausencias,
    fichajes: jornadas, mensajesEscritos: mensajes,
  };
});

/**
 * Borra una cuenta y sus datos personales (ver `eliminarMiCuenta`). La usan
 * la propia persona y Dirección.
 */
async function borrarCuentaYDatos(uid) {
  const w = db.bulkWriter();

  // Familia: se desliga de sus hijas (la ficha queda para el club).
  const alumnas = await db.collection('alumnas').where('familiaUid', '==', uid).get();
  for (const a of alumnas.docs) {
    w.update(a.ref, { familiaUid: FieldValue.delete(), emailFamilia: FieldValue.delete() });
    w.update(db.doc(`codigosVinculacion/${a.id}`), { usadoPor: FieldValue.delete() })
      .catch(() => {});
  }
  for (const [coleccion, borrar] of [['pagos', false], ['asistencias', false], ['ausencias', true]]) {
    const docs = await db.collection(coleccion).where('familiaUid', '==', uid).get();
    for (const d of docs.docs) {
      if (borrar) w.delete(d.ref);
      else w.update(d.ref, { familiaUid: '' });
    }
  }

  // Chat: las conversaciones privadas se borran; en los grupos, el nombre se
  // sustituye en sus mensajes.
  const convs = await db.collection('conversaciones').where('participantes', 'array-contains', uid).get();
  for (const c of convs.docs) {
    if (c.get('tipo') === 'directa') {
      await db.recursiveDelete(c.ref);
      continue;
    }
    const propios = await c.ref.collection('mensajes').where('autorUid', '==', uid).get();
    for (const m of propios.docs) {
      w.update(m.ref, { autorNombre: 'Cuenta eliminada', autorUid: 'eliminada' });
    }
  }
  await w.close();

  try {
    await getStorage().bucket().deleteFiles({ prefix: `comprobantes/${uid}/` });
  } catch (e) {
    logger.error(`No se pudieron borrar los justificantes de ${uid}: ${e.message}`);
  }

  await db.doc(`users/${uid}`).delete();
  try {
    await getAuth().deleteUser(uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw new HttpsError('internal', 'No se pudo cerrar el acceso.');
  }
}

/**
 * Elimina la cuenta de quien llama y sus datos personales (derecho de
 * supresión). Exige haber iniciado sesión hace poco. Se conserva lo que el
 * club necesita por contabilidad y control (cuotas sin nombre de cuenta,
 * asistencia y fichajes), desligado de la cuenta.
 */
export const eliminarMiCuenta = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión.');

  const reciente = Date.now() / 1000 - Number(req.auth?.token?.auth_time ?? 0) < 600;
  if (!reciente) {
    throw new HttpsError('failed-precondition', 'Por seguridad, vuelve a escribir tu contraseña.');
  }

  const perfil = await db.doc(`users/${uid}`).get();
  const rol = perfil.get('role');
  if (rol === 'direccion') {
    const dirs = await db.collection('users').where('role', '==', 'direccion').get();
    if (dirs.size <= 1) {
      throw new HttpsError('failed-precondition', 'Eres la única cuenta de Dirección: crea otra antes de eliminar esta.');
    }
  }

  await borrarCuentaYDatos(uid);
  logger.info(`Cuenta ${uid} (${rol}) eliminada por su titular`);
  return { ok: true };
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

/** Staff con acceso a todos los grupos: su lista sigue a la de grupos. */
async function sincronizarStaffTodosLosGrupos() {
  const [todos, staff] = await Promise.all([
    db.collection('grupos').get(),
    db.collection('users').where('role', '==', 'staff').get(),
  ]);
  const ids = todos.docs.map((g) => g.id).sort();
  for (const u of staff.docs) {
    const actuales = [...new Set(u.get('grupos') ?? [])].sort();
    if (JSON.stringify(actuales) !== JSON.stringify(ids)) {
      await u.ref.update({ grupos: ids });
    }
  }
}

export const sincronizarGrupo = onDocumentWritten('grupos/{id}', async (event) => {
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();
  if (antes && despues && antes.nombre === despues.nombre) return;

  // Grupo nuevo o eliminado: el staff con "todos los grupos" se mantiene al día.
  if (!antes || !despues) await sincronizarStaffTodosLosGrupos();

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
    logger.info(`mensaje en ${conversacionId} (${conv.tipo}): ${destinatarios.length} destinatarios`);

    const cambios = {
      ultimoMensaje: texto.slice(0, 140),
      ultimoAutor: m.autorNombre ?? '',
      ultimoMensajeEn: m.creadoEn ?? FieldValue.serverTimestamp(),
    };
    for (const uid of destinatarios) cambios[`sinLeer.${uid}`] = FieldValue.increment(1);
    await ref.update(cambios);

    // Las notificaciones se ven en la pantalla bloqueada: solo los avisos
    // generales del club (públicos para todas las familias) llevan texto; el
    // resto avisa de que hay algo nuevo, sin nombres ni contenido.
    await notificar(destinatarios, conv.tipo === 'avisos'
      ? { title: 'Aviso del club', body: texto.slice(0, 120), data: { tipo: 'chat', conversacionId } }
      : { title: 'Mensaje nuevo', body: 'Tienes un mensaje nuevo en Spado Rackets.', data: { tipo: 'chat', conversacionId } });
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
  await notificar([despues.familiaUid], {
    // Solo el nombre de pila: se ve en la pantalla bloqueada.
    title: `${String(despues.alumnaNombre ?? '').trim().split(' ')[0] || 'Tu hija'} ya está en el entrenamiento`,
    body: 'El entrenador ha confirmado su asistencia.',
    data: { tipo: 'asistencia' },
  });
});

/** Aviso a la familia cuando Dirección genera su cuota del mes. */
export const avisarCuotaNueva = onDocumentCreated('pagos/{id}', async (event) => {
  const p = event.data?.data();
  if (p?.historico) return; // cargada del histórico: no se avisa
  if (!p?.familiaUid) return; // aún sin cuenta: se avisará al asociarla en la app
  const vence = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(p.venceEn ?? ''));
  await notificar([p.familiaUid], {
    title: 'Nueva cuota',
    body: vence
      ? `Tienes una cuota nueva. Plazo: hasta el ${vence[3]}/${vence[2]}/${vence[1]}.`
      : 'Tienes una cuota nueva. Plazo: hasta el día 5.',
    data: { tipo: 'cuota' },
  });
});

const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

/** Año y mes (`yyyy-MM`) de hoy en la hora de República Dominicana. */
function periodoActualDelClub() {
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Santo_Domingo', year: 'numeric', month: '2-digit',
  }).formatToParts(new Date());
  const anio = partes.find((x) => x.type === 'year').value;
  const mes = partes.find((x) => x.type === 'month').value;
  return `${anio}-${mes}`;
}

/**
 * El día 1 de cada mes, a las 8:00 de República Dominicana, según lo que
 * Dirección haya elegido en Pagos → Cuotas automáticas:
 *   off   → no hace nada (Dirección las genera a mano).
 *   aviso → avisa a Dirección para que las genere ella.
 *   auto  → genera la cuota de cada persona activa con cuota asignada. Nunca
 *           toca una cuota que ya exista. Cada cuota nueva avisa a su familia
 *           (`avisarCuotaNueva`).
 */
export const cuotasMensuales = onSchedule(
  { schedule: '0 8 1 * *', timeZone: 'America/Santo_Domingo' },
  async () => {
    const modo = (await db.doc('ajustes/club').get()).get('cuotasAuto') ?? 'off';
    if (modo !== 'aviso' && modo !== 'auto') return;

    const periodo = periodoActualDelClub();
    const etiqueta = `${MESES[Number(periodo.slice(5)) - 1]} ${periodo.slice(0, 4)}`;

    if (modo === 'aviso') {
      await notificar(await uidsDireccion(), {
        title: 'Cuotas del mes',
        body: `Empieza ${etiqueta}: genera las cuotas desde Pagos.`,
        data: { tipo: 'cuota' },
      });
      return;
    }

    const [alumnas, existentes] = await Promise.all([
      db.collection('alumnas').get(),
      db.collection('pagos').where('periodo', '==', periodo).get(),
    ]);
    const yaTienen = new Set(existentes.docs.map((d) => d.id));

    const nuevas = [];
    for (const a of alumnas.docs) {
      const importe = Number(a.get('cuotaMensual') ?? 0);
      const id = `${a.id}_${periodo}`;
      if (a.get('activa') === false || !(importe > 0) || yaTienen.has(id)) continue;
      nuevas.push({
        id,
        datos: {
          alumnaId: a.id,
          alumnaNombre: String(a.get('nombre') ?? ''),
          grupo: String(a.get('grupo') ?? ''),
          familiaUid: String(a.get('familiaUid') ?? ''),
          periodo,
          concepto: 'Cuota mensual',
          importe,
          moneda: 'USD',
          estado: 'pendiente',
          generadaAuto: true,
          creadoEn: FieldValue.serverTimestamp(),
        },
      });
    }

    for (let i = 0; i < nuevas.length; i += 400) {
      const batch = db.batch();
      for (const n of nuevas.slice(i, i + 400)) {
        batch.create(db.doc(`pagos/${n.id}`), n.datos);
      }
      await batch.commit();
    }
    logger.info(`Cuotas automáticas de ${periodo}: ${nuevas.length} creadas.`);

    await notificar(await uidsDireccion(), {
      title: 'Cuotas generadas',
      body: nuevas.length === 0
        ? `No había cuotas nuevas para ${etiqueta}.`
        : `Se generaron ${nuevas.length} cuotas de ${etiqueta}.`,
      data: { tipo: 'cuota' },
    });
  },
);

/** Avisa a la familia cuando se valida o rechaza su pago, y a Dirección
 *  cuando llega un justificante nuevo. */
export const avisarPago = onDocumentWritten('pagos/{id}', async (event) => {
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();
  if (!despues || antes?.estado === despues.estado) return;

  if (despues.estado === 'en_revision') {
    await notificar(await uidsDireccion(), {
      title: 'Justificante recibido',
      body: 'Hay un justificante pendiente de revisar.',
      data: { tipo: 'pago' },
    });
  } else if (despues.estado === 'pagado' && antes?.estado) {
    await notificar([despues.familiaUid], {
      title: 'Pago confirmado',
      body: 'Tu cuota está pagada. ¡Gracias!',
      data: { tipo: 'pago' },
    });
  } else if (despues.estado === 'rechazado') {
    await notificar([despues.familiaUid], {
      title: 'Revisa tu justificante',
      body: 'No se pudo validar tu pago. Abre la app para ver el motivo.',
      data: { tipo: 'pago' },
    });
  }
});

/**
 * Avisa a la familia cuando el club cambia la clase de su hijo o hija un día.
 * Solo el primer cambio de cada tanda lleva `avisar`, para no mandar un aviso
 * por cada semana.
 */
export const avisarCambioClase = onDocumentCreated('cambiosClase/{id}', async (event) => {
  const c = event.data?.data();
  if (!c?.familiaUid || c.avisar !== true) return;
  await notificar([c.familiaUid], {
    title: 'Cambio de clase',
    body: 'Hay un cambio en el horario de la clase. Míralo en la app.',
    data: { tipo: 'cambioClase' },
  });
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
    body: 'Una familia ha avisado de una falta. Míralo en la app.',
    data: { tipo: 'ausencia' },
  });
});
