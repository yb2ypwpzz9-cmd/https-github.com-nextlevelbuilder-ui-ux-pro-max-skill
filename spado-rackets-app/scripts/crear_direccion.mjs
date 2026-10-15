/**
 * Crea la PRIMERA cuenta de Dirección. Sólo hace falta una vez: a partir de
 * ahí, Dirección crea el resto de cuentas desde la app (Más → Equipo).
 *
 * Uso:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/ruta/serviceAccount.json
 *   npm run crear-direccion -- direccion@spadorackets.com "Nombre Apellido"
 *
 * La clave de servicio se descarga en la consola de Firebase:
 * Configuración del proyecto → Cuentas de servicio → Generar nueva clave.
 * NUNCA se sube al repositorio (está en .gitignore).
 */
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { randomInt } from 'node:crypto';

const [email, ...resto] = process.argv.slice(2);
const nombre = resto.join(' ').trim();
if (!email?.includes('@') || !nombre) {
  console.error('Uso: npm run crear-direccion -- email@dominio.com "Nombre Apellido"');
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });

const letras = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
const password = Array.from({ length: 12 }, () => letras[randomInt(letras.length)]).join('');

const user = await getAuth().createUser({ email, password, displayName: nombre });
await getFirestore().doc(`users/${user.uid}`).set({
  uid: user.uid,
  email,
  role: 'direccion',
  displayName: nombre,
  grupos: [],
  createdAt: FieldValue.serverTimestamp(),
});

console.log('\nCuenta de Dirección creada.');
console.log(`  Email:       ${email}`);
console.log(`  Contraseña:  ${password}`);
console.log('\nCámbiala al entrar: Más → Cambiar contraseña.\n');
