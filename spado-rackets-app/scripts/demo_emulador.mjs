/**
 * Datos de DEMOSTRACIÓN para los emuladores locales. Nunca contra producción:
 * el script se niega a arrancar si no ve los emuladores.
 *
 *   firebase emulators:start --project demo-spado-rackets
 *   npm run demo-emulador
 *   flutter run -d chrome --dart-define=EMULADOR=true
 *
 * Cuentas (contraseña para todas: spado1234):
 *   direccion@demo.spado   Dirección
 *   laura@demo.spado       Staff (Tenis Iniciación, Tenis Competición)
 *   carlos@demo.spado      Staff (Pádel)
 *   garcia@demo.spado      Familia (Lucía y Martina)
 *   lopez@demo.spado       Familia (Sofía)
 */
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';

for (const v of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
  if (!process.env[v]) {
    process.env[v] = v.startsWith('FIRESTORE') ? 'localhost:8080' : 'localhost:9099';
  }
}

initializeApp({ projectId: 'demo-spado-rackets' });
const db = getFirestore();
const auth = getAuth();
const PASS = 'spado1234';

async function usuario(email, nombre, role, grupos = []) {
  let u;
  try {
    u = await auth.getUserByEmail(email);
  } catch {
    u = await auth.createUser({ email, password: PASS, displayName: nombre });
  }
  await db.doc(`users/${u.uid}`).set({
    uid: u.uid, email, role, displayName: nombre, grupos,
    createdAt: FieldValue.serverTimestamp(),
  });
  // Lo que en producción escribe la función `sincronizarUsuario`.
  await db.doc(`directorio/${u.uid}`).set({ nombre, rol: role, grupos });
  return u.uid;
}

const pad = (n) => String(n).padStart(2, '0');
const clave = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const hoy = new Date();

// Grupos
const grupos = [
  { id: 'tenis-ini', nombre: 'Tenis Iniciación', deporte: 'Tenis', dias: [1, 3, 5], horaInicio: '16:30', duracionMinutos: 60, pista: 'Pista 1', cuotaMensual: 3500, moneda: 'DOP', activo: true },
  { id: 'tenis-comp', nombre: 'Tenis Competición', deporte: 'Tenis', dias: [2, 4], horaInicio: '17:30', duracionMinutos: 90, pista: 'Pista central', cuotaMensual: 5000, moneda: 'DOP', activo: true },
  { id: 'padel', nombre: 'Pádel Juvenil', deporte: 'Pádel', dias: [1, 2, 3, 4, 5, 6], horaInicio: '18:00', duracionMinutos: 60, pista: 'Pista de pádel', cuotaMensual: 80, moneda: 'USD', activo: true },
];
for (const { id, ...g } of grupos) await db.doc(`grupos/${id}`).set(g);

const direccion = await usuario('direccion@demo.spado', 'Ana Spado', 'direccion');
const laura = await usuario('laura@demo.spado', 'Laura Martínez', 'staff', ['tenis-ini', 'tenis-comp']);
const carlos = await usuario('carlos@demo.spado', 'Carlos Peña', 'staff', ['padel']);
const garcia = await usuario('garcia@demo.spado', 'María García', 'familia', ['tenis-ini', 'padel']);
const lopez = await usuario('lopez@demo.spado', 'José López', 'familia', ['tenis-ini']);

// 10 alumnas de ejemplo
const alumnas = [
  ['lucia', 'Lucía García', 'tenis-ini', garcia],
  ['martina', 'Martina García', 'padel', garcia],
  ['sofia', 'Sofía López', 'tenis-ini', lopez],
  ['valeria', 'Valeria Núñez', 'tenis-ini', null],
  ['camila', 'Camila Reyes', 'tenis-ini', null],
  ['isabella', 'Isabella Santos', 'tenis-comp', null],
  ['daniela', 'Daniela Ortiz', 'tenis-comp', null],
  ['paula', 'Paula Jiménez', 'tenis-comp', null],
  ['emma', 'Emma Rosario', 'padel', null],
  ['alba', 'Alba Méndez', 'padel', null],
];
const codigos = ['K7M2QX', 'P3R8TW', 'H9N4BV', 'D6F2ZL', 'Q8W3ER', 'T5Y7UP', 'A2S9DF', 'G4H6JK', 'Z3X8CV', 'B7N2MQ'];
for (const [i, [id, nombre, grupo, familiaUid]] of alumnas.entries()) {
  await db.doc(`alumnas/${id}`).set({ nombre, grupo, activa: true, ...(familiaUid ? { familiaUid } : {}) });
  await db.doc(`codigosVinculacion/${id}`).set({
    codigo: codigos[i], alumnaId: id, grupo, ...(familiaUid ? { usadoPor: familiaUid } : {}),
  });
}

// Asistencia de las últimas 3 semanas
const patron = ['presente', 'presente', 'presente', 'falta', 'presente', 'justificada', 'presente'];
for (let i = 21; i >= 1; i--) {
  const d = new Date(hoy); d.setDate(d.getDate() - i);
  const wd = d.getDay() === 0 ? 7 : d.getDay();
  for (const g of grupos) {
    if (!g.dias.includes(wd)) continue;
    const coach = g.id === 'padel' ? [carlos, 'Carlos Peña'] : [laura, 'Laura Martínez'];
    for (const [j, [id, nombre, grupo, familiaUid]] of alumnas.entries()) {
      if (grupo !== g.id) continue;
      const fecha = clave(d);
      await db.doc(`asistencias/${g.id}_${fecha}_${id}`).set({
        grupo: g.id, fecha, alumnaId: id, alumnaNombre: nombre, familiaUid: familiaUid ?? '',
        estado: patron[(i + j * 2) % patron.length], marcadoPor: coach[0], marcadoPorNombre: coach[1],
        marcadoEn: Timestamp.fromDate(new Date(d.setHours(19, 0, 0, 0))),
      });
    }
  }
}

// Fichajes de la última semana
for (let i = 6; i >= 1; i--) {
  const d = new Date(hoy); d.setDate(d.getDate() - i);
  if (d.getDay() === 0) continue;
  const e = new Date(d); e.setHours(16, 5 + i, 0, 0);
  const s = new Date(d); s.setHours(19, 40 + i, 0, 0);
  await db.collection('jornadas').add({
    staffUid: laura, staffNombre: 'Laura Martínez', entrada: Timestamp.fromDate(e), salida: Timestamp.fromDate(s),
    entradaLat: 18.4861, entradaLng: -69.9312, entradaPrecision: 12,
  });
}
// Carlos, en jornada ahora mismo
const ahora = new Date(hoy); ahora.setMinutes(ahora.getMinutes() - 75);
await db.collection('jornadas').add({
  staffUid: carlos, staffNombre: 'Carlos Peña', entrada: Timestamp.fromDate(ahora), salida: null,
  entradaLat: 18.4855, entradaLng: -69.9301, entradaPrecision: 9,
});

// Cuotas: mes anterior pagado, mes actual variado
const periodo = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
const mesActual = periodo(hoy);
const anterior = periodo(new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1));
for (const [id, nombre, grupo, familiaUid] of alumnas) {
  if (!familiaUid) continue;
  const g = grupos.find((x) => x.id === grupo);
  const base = { alumnaId: id, alumnaNombre: nombre, grupo, familiaUid, concepto: `Cuota ${g.nombre}`, importe: g.cuotaMensual, moneda: g.moneda, creadoEn: FieldValue.serverTimestamp() };
  await db.doc(`pagos/${id}_${anterior}`).set({ ...base, periodo: anterior, estado: 'pagado', resueltoEn: FieldValue.serverTimestamp(), resueltoPorNombre: 'Ana Spado' });
  await db.doc(`pagos/${id}_${mesActual}`).set({
    ...base, periodo: mesActual,
    estado: id === 'sofia' ? 'en_revision' : id === 'martina' ? 'pagado' : 'pendiente',
    ...(id === 'sofia' ? { comprobantePath: `comprobantes/${lopez}/demo.pdf`, comprobanteNombre: 'transferencia_popular.pdf', subidoEn: FieldValue.serverTimestamp() } : {}),
  });
}

await db.doc('ajustes/club').set({
  cuentas: [
    { banco: 'Banco Popular Dominicano', numero: '812345678', tipo: 'Corriente', titular: 'Spado Rackets SRL', documento: 'RNC 1-32-00000-0', moneda: 'DOP' },
    { banco: 'Banco Popular Dominicano', numero: '798765432', tipo: 'Ahorros', titular: 'Spado Rackets SRL', documento: '', moneda: 'USD' },
  ],
  instrucciones: 'En el concepto de la transferencia pon el nombre de la alumna y el mes. Ejemplo: Lucía García octubre.',
});

// Chat (en producción, participantes y contadores los lleva el servidor)
const todos = [direccion, laura, carlos, garcia, lopez].sort();
const minutos = (m) => Timestamp.fromDate(new Date(Date.now() - m * 60000));
await db.doc('conversaciones/avisos').set({
  tipo: 'avisos', titulo: 'Avisos del club', participantes: todos,
  ultimoMensaje: 'El sábado no hay clases por el torneo interclubes. ¡Os esperamos animando!',
  ultimoAutor: 'Ana Spado', ultimoMensajeEn: minutos(90),
  sinLeer: { [garcia]: 1, [lopez]: 1, [laura]: 0, [carlos]: 1 },
});
for (const [t, texto] of [[2900, 'Bienvenidas a la app de Spado Rackets. A partir de hoy los avisos del club se publican aquí, no en WhatsApp.'], [90, 'El sábado no hay clases por el torneo interclubes. ¡Os esperamos animando!']]) {
  await db.collection('conversaciones/avisos/mensajes').add({ texto, autorUid: direccion, autorNombre: 'Ana Spado', autorRol: 'direccion', creadoEn: minutos(t) });
}
await db.doc('conversaciones/g_tenis-ini').set({
  tipo: 'grupo', grupo: 'tenis-ini', titulo: 'Tenis Iniciación',
  participantes: [direccion, laura, garcia, lopez].sort(),
  ultimoMensaje: '¡Perfecto, gracias Laura!', ultimoAutor: 'José López', ultimoMensajeEn: minutos(30),
  sinLeer: { [garcia]: 2, [laura]: 1 },
});
for (const [t, uid, nombre, rol, texto] of [
  [180, laura, 'Laura Martínez', 'staff', 'Mañana entrenamos en la Pista 1. Traed agua y gorra, que se prevé calor.'],
  [30, lopez, 'José López', 'familia', '¡Perfecto, gracias Laura!'],
]) {
  await db.collection('conversaciones/g_tenis-ini/mensajes').add({ texto, autorUid: uid, autorNombre: nombre, autorRol: rol, creadoEn: minutos(t) });
}
await db.doc('conversaciones/g_tenis-comp').set({ tipo: 'grupo', grupo: 'tenis-comp', titulo: 'Tenis Competición', participantes: [direccion, laura].sort(), sinLeer: {} });
await db.doc('conversaciones/g_padel').set({ tipo: 'grupo', grupo: 'padel', titulo: 'Pádel Juvenil', participantes: [direccion, carlos, garcia].sort(), sinLeer: {} });

console.log('Datos de demostración cargados. Contraseña de todas las cuentas: spado1234');
process.exit(0);
