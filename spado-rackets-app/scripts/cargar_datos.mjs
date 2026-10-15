/**
 * Carga grupos y alumnas desde un JSON y genera el código de cada familia.
 *
 * Pensado para la carga inicial con los listados del club. Después, lo normal
 * es dar de alta desde la app (Más → Alumnas y códigos).
 *
 * Uso:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/ruta/serviceAccount.json
 *   npm run cargar-datos -- scripts/datos_club.json
 *
 * Formato: ver scripts/datos_club.ejemplo.json.
 * Escribe `codigos_generados.csv` (alumna, grupo, código) para repartirlos.
 * Ese CSV tiene datos de menores: no se sube al repositorio.
 *
 * Es idempotente por nombre: si una alumna ya existe en ese grupo con el
 * mismo nombre, no se duplica.
 */
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, writeFileSync } from 'node:fs';
import { randomInt } from 'node:crypto';

const archivo = process.argv[2];
if (!archivo) {
  console.error('Uso: npm run cargar-datos -- ruta/al/datos.json');
  process.exit(1);
}

const usarEmulador = !!process.env.FIRESTORE_EMULATOR_HOST;
initializeApp(usarEmulador ? { projectId: 'demo-spado-rackets' } : { credential: applicationDefault() });
const db = getFirestore();

const datos = JSON.parse(readFileSync(archivo, 'utf8'));
const letras = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const nuevoCodigo = () => Array.from({ length: 6 }, () => letras[randomInt(letras.length)]).join('');

const filas = [['alumna', 'grupo', 'codigo', 'email_familia']];

for (const g of datos.grupos ?? []) {
  const grupoRef = g.id ? db.doc(`grupos/${g.id}`) : db.collection('grupos').doc();
  await grupoRef.set({
    nombre: g.nombre,
    deporte: g.deporte ?? 'Tenis',
    dias: g.dias ?? [],
    horaInicio: g.horaInicio ?? '',
    duracionMinutos: g.duracionMinutos ?? 60,
    pista: g.pista ?? '',
    cuotaMensual: Number(g.cuotaMensual ?? 0),
    moneda: (g.moneda ?? 'DOP').toUpperCase(),
    activo: true,
  }, { merge: true });

  const existentes = await db.collection('alumnas').where('grupo', '==', grupoRef.id).get();
  const nombres = new Set(existentes.docs.map((d) => String(d.get('nombre')).toLowerCase()));

  for (const entrada of g.alumnas ?? []) {
    // Una alumna puede ser un nombre, o { "nombre": "...", "email": "familia@correo.com" }.
    const nombre = typeof entrada === 'string' ? entrada : entrada.nombre;
    const emailFamilia = typeof entrada === 'string' ? '' : String(entrada.email ?? '').trim().toLowerCase();
    if (nombres.has(nombre.toLowerCase())) {
      console.log(`= ${nombre} ya existe en ${g.nombre}`);
      continue;
    }
    const alumna = db.collection('alumnas').doc();
    const codigo = nuevoCodigo();
    await db.batch()
      .set(alumna, { nombre, grupo: grupoRef.id, activa: true, ...(emailFamilia ? { emailFamilia } : {}), creadaEn: FieldValue.serverTimestamp() })
      .set(db.doc(`codigosVinculacion/${alumna.id}`), {
        codigo, alumnaId: alumna.id, grupo: grupoRef.id, creadoEn: FieldValue.serverTimestamp(),
      })
      .commit();
    filas.push([nombre, g.nombre, codigo, emailFamilia]);
    console.log(`+ ${nombre} (${g.nombre}) → ${codigo}`);
  }
}

if (datos.cuentasBancarias) {
  await db.doc('ajustes/club').set({
    cuentas: datos.cuentasBancarias,
    instrucciones: datos.instruccionesPago ?? '',
  }, { merge: true });
  console.log('Datos bancarios guardados.');
}

writeFileSync('codigos_generados.csv', filas.map((f) => f.map((c) => `"${c}"`).join(',')).join('\n'));
console.log(`\n${filas.length - 1} códigos nuevos en codigos_generados.csv`);
