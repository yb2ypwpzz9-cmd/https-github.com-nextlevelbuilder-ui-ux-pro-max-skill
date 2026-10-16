/**
 * Pruebas de las reglas de seguridad contra los emuladores.
 *
 *   npm run test:reglas
 *
 * Cada prueba es un intento real de saltarse un permiso. Si una regla se
 * relaja por error, aquí sale en rojo antes de llegar a producción.
 */
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, collection, getDocs, query, where,
  serverTimestamp, writeBatch, Timestamp,
} from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

let env;

const DIR = 'dir1';
const STAFF = 'staff1';
const STAFF2 = 'staff2';
const FAM = 'fam1';
const FAM2 = 'fam2';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-spado-rackets',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
    storage: { rules: readFileSync('storage.rules', 'utf8') },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const set = (p, d) => setDoc(doc(db, p), d);
    await set(`users/${DIR}`, { role: 'direccion', grupos: [] });
    await set(`users/${STAFF}`, { role: 'staff', grupos: ['g1'] });
    await set(`users/${STAFF2}`, { role: 'staff', grupos: ['g2'] });
    await set(`users/${FAM}`, { role: 'familia', grupos: ['g1'] });
    await set(`users/${FAM2}`, { role: 'familia', grupos: ['g2'] });
    await set(`directorio/${STAFF}`, { nombre: 'Laura', rol: 'staff' });
    await set(`directorio/${FAM}`, { nombre: 'María', rol: 'familia' });
    await set(`directorio/${FAM2}`, { nombre: 'José', rol: 'familia' });
    await set('grupos/g1', { nombre: 'Tenis', cuotaMensual: 3500, moneda: 'DOP', dias: [1] });
    await set('grupos/g2', { nombre: 'Pádel', cuotaMensual: 80, moneda: 'USD', dias: [2] });
    await set('alumnas/a1', { nombre: 'Lucía', grupo: 'g1', familiaUid: FAM, activa: true });
    await set('alumnas/a2', { nombre: 'Sofía', grupo: 'g2', familiaUid: FAM2, activa: true });
    await set('codigosVinculacion/a1', { codigo: 'ABC123', alumnaId: 'a1' });
    await set('asistencias/g1_2026-10-01_a1', { grupo: 'g1', fecha: '2026-10-01', alumnaId: 'a1', familiaUid: FAM, estado: 'presente' });
    await set('asistencias/g2_2026-10-01_a2', { grupo: 'g2', fecha: '2026-10-01', alumnaId: 'a2', familiaUid: FAM2, estado: 'falta' });
    await set('pagos/a1_2026-10', { alumnaId: 'a1', familiaUid: FAM, periodo: '2026-10', importe: 3500, moneda: 'DOP', estado: 'pendiente' });
    await set('pagos/a2_2026-10', { alumnaId: 'a2', familiaUid: FAM2, periodo: '2026-10', importe: 80, moneda: 'USD', estado: 'pendiente' });
    await set('conversaciones/avisos', { tipo: 'avisos', participantes: [DIR, STAFF, STAFF2, FAM, FAM2], sinLeer: {} });
    await set('conversaciones/g_g2', { tipo: 'grupo', grupo: 'g2', participantes: [DIR, STAFF2, FAM2], sinLeer: {} });
  });
});

const dia = (desplazamiento = 0) =>
  new Date(Date.now() + desplazamiento * 86400000).toISOString().slice(0, 10);
const HOY = dia(0);

const como = (uid) => env.authenticatedContext(uid).firestore();
const storageDe = (uid) => env.authenticatedContext(uid).storage();

describe('usuarios', () => {
  test('una familia nueva no puede darse grupos ni otro rol', async () => {
    const db = como('nuevo');
    await assertFails(setDoc(doc(db, 'users/nuevo'), { uid: 'nuevo', email: 'a@b.c', role: 'familia', grupos: ['g1'] }));
    await assertFails(setDoc(doc(db, 'users/nuevo'), { uid: 'nuevo', email: 'a@b.c', role: 'direccion', grupos: [] }));
    await assertSucceeds(setDoc(doc(db, 'users/nuevo'), { uid: 'nuevo', email: 'a@b.c', role: 'familia', grupos: [] }));
  });

  test('nadie cambia su propio rol ni sus grupos', async () => {
    await assertFails(updateDoc(doc(como(FAM), `users/${FAM}`), { role: 'direccion' }));
    await assertFails(updateDoc(doc(como(FAM), `users/${FAM}`), { grupos: ['g1', 'g2'] }));
    await assertFails(updateDoc(doc(como(STAFF), `users/${STAFF}`), { grupos: ['g1', 'g2'] }));
    await assertSucceeds(updateDoc(doc(como(FAM), `users/${FAM}`), { phone: '8090000000' }));
  });

  test('una familia no lee el perfil de otra', async () => {
    await assertFails(getDoc(doc(como(FAM), `users/${FAM2}`)));
  });
});

describe('alumnas y códigos', () => {
  test('la familia ve a su hija y no a la ajena', async () => {
    await assertSucceeds(getDoc(doc(como(FAM), 'alumnas/a1')));
    await assertFails(getDoc(doc(como(FAM), 'alumnas/a2')));
  });

  test('el staff sólo ve alumnas de sus grupos', async () => {
    await assertSucceeds(getDocs(query(collection(como(STAFF), 'alumnas'), where('grupo', 'in', ['g1']))));
    await assertFails(getDoc(doc(como(STAFF), 'alumnas/a2')));
  });

  test('nadie se apunta como familia de una alumna desde la app', async () => {
    await assertFails(updateDoc(doc(como(FAM2), 'alumnas/a1'), { familiaUid: FAM2 }));
    await assertFails(updateDoc(doc(como(DIR), 'alumnas/a1'), { familiaUid: FAM2 }));
  });

  test('sólo Dirección ve los códigos', async () => {
    await assertFails(getDocs(collection(como(FAM), 'codigosVinculacion')));
    await assertFails(getDocs(collection(como(STAFF), 'codigosVinculacion')));
    await assertSucceeds(getDocs(collection(como(DIR), 'codigosVinculacion')));
  });
});

describe('asistencia', () => {
  test('la familia sólo consulta las marcas de sus hijas', async () => {
    await assertSucceeds(getDocs(query(collection(como(FAM), 'asistencias'), where('familiaUid', '==', FAM))));
    await assertFails(getDoc(doc(como(FAM), 'asistencias/g2_2026-10-01_a2')));
  });

  const marca = (grupo, alumna, familiaUid, uid, extra = {}) => ({
    grupo, fecha: HOY, alumnaId: alumna, alumnaNombre: 'x', familiaUid,
    estado: 'presente', marcadoPor: uid, marcadoPorNombre: 'Laura',
    marcadoEn: serverTimestamp(), ...extra,
  });

  test('el staff pasa lista en su grupo y no en el ajeno', async () => {
    await assertSucceeds(setDoc(doc(como(STAFF), `asistencias/g1_${HOY}_a1`), marca('g1', 'a1', FAM, STAFF)));
    await assertFails(setDoc(doc(como(STAFF), `asistencias/g2_${HOY}_a2`), marca('g2', 'a2', FAM2, STAFF)));
  });

  test('no se puede enseñar una marca a otra familia', async () => {
    await assertFails(setDoc(doc(como(STAFF), `asistencias/g1_${HOY}_a1`), marca('g1', 'a1', FAM2, STAFF)));
  });

  test('una familia no puede marcarse asistencia', async () => {
    await assertFails(setDoc(doc(como(FAM), `asistencias/g1_${HOY}_a1`), marca('g1', 'a1', FAM, FAM)));
  });

  test('el staff no pasa lista de fechas lejanas ni falsea la hora o el nombre', async () => {
    const lejos = dia(-60);
    await assertFails(setDoc(doc(como(STAFF), `asistencias/g1_${lejos}_a1`), marca('g1', 'a1', FAM, STAFF, { fecha: lejos })));
    await assertFails(setDoc(doc(como(STAFF), `asistencias/g1_${HOY}_a1`), marca('g1', 'a1', FAM, STAFF, { marcadoEn: Timestamp.fromDate(new Date('2000-01-01')) })));
    await assertFails(setDoc(doc(como(STAFF), `asistencias/g1_${HOY}_a1`), marca('g1', 'a1', FAM, STAFF, { marcadoPorNombre: 'Otro' })));
  });

  test('un entrenador no pisa la marca de otro; Dirección sí corrige', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `asistencias/g1_${HOY}_a1`), marca('g1', 'a1', FAM, 'otro-staff')));
    await assertFails(setDoc(doc(como(STAFF), `asistencias/g1_${HOY}_a1`), marca('g1', 'a1', FAM, STAFF, { estado: 'falta' })));
    await assertSucceeds(setDoc(doc(como(DIR), `asistencias/g1_${HOY}_a1`), marca('g1', 'a1', FAM, DIR, { estado: 'falta', marcadoPorNombre: 'Rafael' })));
  });
});

describe('fichaje', () => {
  const llegada = (uid, hora, extra = {}) => ({
    staffUid: uid, staffNombre: 'Laura', fecha: HOY, entrada: hora,
    entradaLat: 18.58, entradaLng: -68.4, entradaPrecision: 20, ...extra,
  });

  test('se ficha con la hora del servidor, no la del móvil', async () => {
    const db = como(STAFF);
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, Timestamp.fromDate(new Date('2026-10-01T08:00:00')))));
    await assertSucceeds(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp())));
  });

  test('el fichaje exige ubicación válida y la fecha de hoy', async () => {
    const db = como(STAFF);
    const sin = llegada(STAFF, serverTimestamp()); delete sin.entradaLat; delete sin.entradaLng;
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), sin));
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp(), { entradaLat: 'x' })));
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp(), { entradaLat: 200 })));
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp(), { entradaPrecision: -5 })));
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp(), { staffNombre: 'Ana Direccion' })));
    const viejo = dia(-30);
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${viejo}`), llegada(STAFF, serverTimestamp(), { fecha: viejo })));
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp(), { fecha: 'cualquier cosa' })));
  });

  test('nadie ficha por otro y una familia no ficha', async () => {
    await assertFails(setDoc(doc(como(STAFF2), `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp())));
    await assertFails(setDoc(doc(como(STAFF2), `jornadas/${STAFF2}_${HOY}`), llegada(STAFF, serverTimestamp())));
    await assertFails(setDoc(doc(como(FAM), `jornadas/${FAM}_${HOY}`), llegada(FAM, serverTimestamp())));
  });

  test('una sola llegada al día y el fichaje no se edita', async () => {
    const db = como(STAFF);
    await assertSucceeds(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp())));
    await assertFails(setDoc(doc(db, `jornadas/${STAFF}_${HOY}`), llegada(STAFF, serverTimestamp())));
    await assertFails(updateDoc(doc(db, `jornadas/${STAFF}_${HOY}`), { entrada: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, `jornadas/${STAFF}_${HOY}`), { salida: serverTimestamp() }));
  });

  test('un entrenador no ve los fichajes de otro; Dirección sí', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'jornadas/j9'), { staffUid: STAFF2, entrada: Timestamp.now() }));
    await assertFails(getDoc(doc(como(STAFF), 'jornadas/j9')));
    await assertSucceeds(getDoc(doc(como(DIR), 'jornadas/j9')));
  });
});

describe('pagos', () => {
  const subir = (uid) => ({
    comprobantePath: `comprobantes/${uid}/a1_2026-10_1.pdf`,
    comprobanteNombre: 'j.pdf', estado: 'en_revision', subidoEn: serverTimestamp(), motivoRechazo: null,
  });

  test('la familia sube su justificante y la cuota pasa a revisión', async () => {
    await assertSucceeds(updateDoc(doc(como(FAM), 'pagos/a1_2026-10'), subir(FAM)));
  });

  test('la familia no puede marcar pagada ni cambiar el importe', async () => {
    await assertFails(updateDoc(doc(como(FAM), 'pagos/a1_2026-10'), { estado: 'pagado' }));
    await assertFails(updateDoc(doc(como(FAM), 'pagos/a1_2026-10'), { ...subir(FAM), importe: 1 }));
  });

  test('no se puede apuntar a un archivo de otra familia ni tocar su cuota', async () => {
    await assertFails(updateDoc(doc(como(FAM), 'pagos/a1_2026-10'), subir(FAM2)));
    await assertFails(updateDoc(doc(como(FAM), 'pagos/a2_2026-10'), subir(FAM)));
    await assertFails(getDoc(doc(como(FAM), 'pagos/a2_2026-10')));
  });

  test('sólo Dirección crea cuotas y las valida', async () => {
    const cuota = { alumnaId: 'a1', familiaUid: FAM, periodo: '2026-11', importe: 3500, moneda: 'DOP', estado: 'pendiente' };
    await assertFails(setDoc(doc(como(STAFF), 'pagos/a1_2026-11'), cuota));
    await assertSucceeds(setDoc(doc(como(DIR), 'pagos/a1_2026-11'), cuota));
    await assertSucceeds(updateDoc(doc(como(DIR), 'pagos/a1_2026-10'), { estado: 'pagado' }));
  });

  test('sólo Dirección cambia los datos bancarios', async () => {
    await assertFails(setDoc(doc(como(FAM), 'ajustes/club'), { cuentas: [] }));
    await assertFails(setDoc(doc(como(STAFF), 'ajustes/club'), { cuentas: [] }));
    await assertSucceeds(setDoc(doc(como(DIR), 'ajustes/club'), { cuentas: [] }));
  });
});

describe('chat', () => {
  const mensaje = (uid, nombre, rol, texto = 'Hola') => ({
    texto, autorUid: uid, autorNombre: nombre, autorRol: rol, creadoEn: serverTimestamp(),
  });

  test('una familia no publica en avisos; el staff sí', async () => {
    await assertFails(setDoc(doc(como(FAM), 'conversaciones/avisos/mensajes/m1'), mensaje(FAM, 'María', 'familia')));
    await assertSucceeds(setDoc(doc(como(STAFF), 'conversaciones/avisos/mensajes/m2'), mensaje(STAFF, 'Laura', 'staff')));
  });

  test('nadie firma con otro nombre ni otro rol', async () => {
    await assertFails(setDoc(doc(como(FAM), 'conversaciones/avisos/mensajes/m1'), mensaje(FAM, 'Dirección Spado', 'direccion')));
    await assertFails(setDoc(doc(como(STAFF), 'conversaciones/avisos/mensajes/m1'), mensaje(STAFF, 'Dirección Spado', 'staff')));
  });

  test('una familia no lee el chat de un grupo que no es el suyo', async () => {
    await assertFails(getDoc(doc(como(FAM), 'conversaciones/g_g2')));
    await assertFails(getDocs(collection(como(FAM), 'conversaciones/g_g2/mensajes')));
  });

  const directa = (a, b, nombres) => {
    const [x, y] = [a, b].sort();
    return { id: `d_${x}_${y}`, datos: { tipo: 'directa', participantes: [x, y], nombres, sinLeer: {} } };
  };

  test('una familia escribe al club, pero no a otra familia', async () => {
    const ok = directa(FAM, STAFF, {});
    // Conversación y primer mensaje en el mismo lote, como hace la app.
    const db = como(FAM);
    const b1 = writeBatch(db);
    b1.set(doc(db, `conversaciones/${ok.id}`), ok.datos);
    b1.set(doc(db, `conversaciones/${ok.id}/mensajes/m1`), mensaje(FAM, 'María', 'familia'));
    await assertSucceeds(b1.commit());

    const mal = directa(FAM, FAM2, {});
    await assertFails(setDoc(doc(como(FAM), `conversaciones/${mal.id}`), mal.datos));
  });

  test('nadie lee una conversación privada ajena', async () => {
    const c = directa(FAM2, STAFF2, {});
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), `conversaciones/${c.id}`), c.datos));
    await assertFails(getDoc(doc(como(FAM), `conversaciones/${c.id}`)));
    await assertFails(getDocs(collection(como(STAFF), `conversaciones/${c.id}/mensajes`)));
  });

  test('cada uno sólo pone a cero su propio contador', async () => {
    await assertSucceeds(updateDoc(doc(como(FAM), 'conversaciones/avisos'), { [`sinLeer.${FAM}`]: 0 }));
    await assertFails(updateDoc(doc(como(FAM), 'conversaciones/avisos'), { [`sinLeer.${FAM2}`]: 0 }));
    await assertFails(updateDoc(doc(como(FAM), 'conversaciones/avisos'), { participantes: [FAM] }));
  });
});

describe('gastos', () => {
  const gasto = (uid, extra = {}) => ({
    concepto: 'Alquiler de pistas', categoria: 'pistas', importe: 15000,
    fecha: '2026-10-01', creadoEn: serverTimestamp(), creadoPor: uid, ...extra,
  });

  test('sólo Dirección registra y lee gastos', async () => {
    await assertSucceeds(setDoc(doc(como(DIR), 'gastos/g1'), gasto(DIR)));
    await assertFails(setDoc(doc(como(FAM), 'gastos/g2'), gasto(FAM)));
    await assertFails(setDoc(doc(como(STAFF), 'gastos/g3'), gasto(STAFF)));
    await assertFails(getDoc(doc(como(FAM), 'gastos/g1')));
    await assertFails(getDoc(doc(como(STAFF), 'gastos/g1')));
    await assertSucceeds(getDoc(doc(como(DIR), 'gastos/g1')));
  });

  test('un gasto mal formado se rechaza', async () => {
    const db = como(DIR);
    await assertFails(setDoc(doc(db, 'gastos/m1'), gasto(DIR, { importe: -5 })));
    await assertFails(setDoc(doc(db, 'gastos/m2'), gasto(DIR, { categoria: 'otra' })));
    await assertFails(setDoc(doc(db, 'gastos/m3'), gasto(DIR, { fecha: 'ayer' })));
    await assertFails(setDoc(doc(db, 'gastos/m4'), gasto(DIR, { extra: 'x' })));
  });
});

describe('justificantes (Storage)', () => {
  const pdf = new Uint8Array([37, 80, 68, 70]);

  // Que la familia vinculada SÍ pueda subir depende de `firestore.get(...)`
  // desde Storage, que el emulador no resuelve (ver nota más abajo).
  test('cada familia sólo sube a su carpeta', async () => {
    await assertFails(uploadBytes(ref(storageDe(FAM), `comprobantes/${FAM2}/a.pdf`), pdf, { contentType: 'application/pdf' }));
  });

  test('sólo imágenes o PDF', async () => {
    await assertFails(uploadBytes(ref(storageDe(FAM), `comprobantes/${FAM}/a.html`), pdf, { contentType: 'text/html' }));
  });

  // Que Dirección SÍ pueda abrirlo depende de `firestore.get(...)` desde las
  // reglas de Storage, una consulta entre servicios que el emulador no
  // resuelve (devuelve null). En producción funciona tras conceder el permiso
  // que pide Firebase al desplegar Storage. Aquí se prueba la negación, que es
  // la que protege los datos.
  test('una familia no abre el justificante de otra; la suya sí', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      uploadBytes(ref(ctx.storage(), `comprobantes/${FAM2}/b.pdf`), pdf, { contentType: 'application/pdf' }));
    await assertFails(getBytes(ref(storageDe(FAM), `comprobantes/${FAM2}/b.pdf`)));
    await assertSucceeds(getBytes(ref(storageDe(FAM2), `comprobantes/${FAM2}/b.pdf`)));
  });
});

describe('acceso al club sin alumna vinculada', () => {
  const NUEVA = 'nueva1';
  beforeEach(() => env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), `users/${NUEVA}`), { role: 'familia', grupos: [] })));

  test('una cuenta sin alumna no ve cuentas bancarias ni cuotas de grupo', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'ajustes/club'), { cuentas: [{ numero: '123' }] }));
    await assertFails(getDoc(doc(como(NUEVA), 'ajustes/club')));
    await assertFails(getDoc(doc(como(NUEVA), 'grupos/g1')));
    await assertSucceeds(getDoc(doc(como(FAM), 'ajustes/club')));
    await assertSucceeds(getDoc(doc(como(FAM), 'grupos/g1')));
    await assertSucceeds(getDoc(doc(como(STAFF), 'ajustes/club')));
  });

  test('el justificante solo apunta a la carpeta propia y sin trucos de ruta', async () => {
    const base = { comprobantePath: `comprobantes/${FAM}/x.pdf`, comprobanteNombre: 'x.pdf', estado: 'en_revision', subidoEn: serverTimestamp(), motivoRechazo: null };
    await assertFails(updateDoc(doc(como(FAM), 'pagos/a1_2026-10'), { ...base, comprobantePath: `comprobantes/${FAM}/../${FAM2}/x.pdf` }));
    await assertFails(updateDoc(doc(como(FAM), 'pagos/a1_2026-10'), { ...base, comprobantePath: `comprobantes/${FAM}/sub/x.pdf` }));
    await assertFails(updateDoc(doc(como(FAM), 'pagos/a1_2026-10'), { ...base, comprobanteNombre: 'a'.repeat(300) }));
    await assertSucceeds(updateDoc(doc(como(FAM), 'pagos/a1_2026-10'), base));
  });
});

describe('pasos obligatorios del primer acceso', () => {
  test('quitar la marca de contraseña provisional, y solo eso', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), `users/${STAFF}`), { debeCambiarPassword: true }));
    const db = como(STAFF);
    await assertFails(updateDoc(doc(db, `users/${STAFF}`), { debeCambiarPassword: false, role: 'direccion' }));
    await assertSucceeds(updateDoc(doc(db, `users/${STAFF}`), { debeCambiarPassword: false }));
    // Ya sin la marca, no se puede volver a ponerla desde la app.
    await assertFails(updateDoc(doc(db, `users/${STAFF}`), { debeCambiarPassword: true }));
  });

  test('el staff firma el aviso de ubicación con la hora del servidor', async () => {
    const db = como(STAFF);
    await assertFails(updateDoc(doc(db, `users/${STAFF}`), { avisoUbicacionVersion: '2026-10', avisoUbicacionEn: Timestamp.fromDate(new Date('2000-01-01')) }));
    await assertSucceeds(updateDoc(doc(db, `users/${STAFF}`), { avisoUbicacionVersion: '2026-10', avisoUbicacionEn: serverTimestamp() }));
    await assertFails(updateDoc(doc(como(FAM), `users/${FAM}`), { avisoUbicacionVersion: '2026-10', avisoUbicacionEn: serverTimestamp() }));
  });
});

describe('ficha de la alumna: nivel, nacimiento y foto', () => {
  const ficha = (extra = {}) => ({ nombre: 'Ana', grupo: 'g1', activa: true, ...extra });

  test('Dirección guarda nivel, fecha y foto válidos', async () => {
    await assertSucceeds(setDoc(doc(como(DIR), 'alumnas/n1'), ficha({
      nivel: 'intermedio', fechaNacimiento: Timestamp.fromDate(new Date('2016-05-02')), fotoPath: 'fotos/n1/1.jpg' })));
  });

  test('se rechazan niveles raros y rutas de foto ajenas', async () => {
    await assertFails(setDoc(doc(como(DIR), 'alumnas/n2'), ficha({ nivel: 'dios' })));
    await assertFails(setDoc(doc(como(DIR), 'alumnas/n3'), ficha({ fotoPath: 'fotos/otra/1.jpg' })));
    await assertFails(setDoc(doc(como(DIR), 'alumnas/n4'), ficha({ fotoPath: 'fotos/n4/../x.jpg' })));
    await assertFails(setDoc(doc(como(DIR), 'alumnas/n5'), ficha({ fechaNacimiento: '2016-05-02' })));
  });

  test('la familia solo cambia la foto de SU hija', async () => {
    await assertSucceeds(updateDoc(doc(como(FAM), 'alumnas/a1'), { fotoPath: 'fotos/a1/1.jpg' }));
    await assertFails(updateDoc(doc(como(FAM), 'alumnas/a1'), { fotoPath: 'fotos/a2/1.jpg' }));
    await assertFails(updateDoc(doc(como(FAM), 'alumnas/a1'), { fotoPath: 'fotos/a1/1.jpg', nombre: 'Otra' }));
    await assertFails(updateDoc(doc(como(FAM), 'alumnas/a2'), { fotoPath: 'fotos/a2/1.jpg' }));
  });

  test('una familia o el staff no editan la ficha', async () => {
    await assertFails(updateDoc(doc(como(FAM), 'alumnas/a1'), { nivel: 'avanzado' }));
    await assertFails(updateDoc(doc(como(STAFF), 'alumnas/a1'), { nivel: 'avanzado' }));
  });
});
