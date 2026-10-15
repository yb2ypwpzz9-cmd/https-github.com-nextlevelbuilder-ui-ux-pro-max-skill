# Spado Rackets — app web

App de gestión de la escuela de raquetas: **fichaje del staff, asistencia, chat interno y cuotas con justificante**. Flutter Web + Firebase, la misma arquitectura que Spado Soccer. Se publica en Netlify; no pasa por las tiendas.

| Perfil | Qué hace |
|---|---|
| **Dirección** | Panel (staff en jornada, asistencia, justificantes por revisar, cuotas vencidas) · fichajes y horas del staff con mapa · asistencia por grupo · generar cuotas del mes, validar o rechazar justificantes, registrar cobros en efectivo · alumnas y códigos · grupos, horarios y cuota (RD$ o US$) · cuentas del equipo · datos bancarios · todos los chats |
| **Staff** | Fichar entrada y salida (hora del servidor + ubicación) · pasar lista (P / F / J) de sus grupos · sus horas · chat |
| **Familias** | Su hija, asistencia y %, avisar de una falta · cuotas pagadas y pendientes · datos bancarios con copiar · adjuntar justificante (foto o PDF) · chat |

**Chat** (sustituye a los grupos de WhatsApp): *Avisos del club* (publican Dirección y staff), un chat por grupo (familias del grupo + su entrenador + Dirección) y mensajes privados con el club. Una familia nunca puede escribir a otra.

## Seguridad

Cada permiso se vuelve a comprobar en el servidor, no en la app:

- **Reglas de Firestore y Storage** (`firestore.rules`, `storage.rules`) con **29 pruebas** que intentan saltárselas: `npm run test:reglas`. Cubren, entre otras cosas: nadie se da otro rol ni grupos; el fichaje usa la hora del servidor y no se edita; una familia sólo ve sus hijas, sus cuotas y sus marcas; no se puede marcar una cuota como pagada desde la app; nadie firma un mensaje como otro; los justificantes sólo los abre quien los subió y Dirección.
- **Cloud Functions** (`functions/index.js`): el código de vinculación se comprueba en servidor (uno por alumna, un solo uso), las cuentas del club sólo las crea Dirección, y los contadores de chat y avisos los lleva el servidor.
- **Cabeceras de seguridad** para Netlify en `web/_headers`.

## Puesta en marcha (una sola vez)

Necesitas: Flutter, Node 22 y Firebase CLI (`npm i -g firebase-tools`).

1. **Proyecto Firebase.** Crea uno nuevo en la consola (recomendado: separado de Soccer, para que los datos de cada negocio no se mezclen) en plan **Blaze** (hace falta para Functions; con 10 alumnas el coste real es ~0).
   Activa **Authentication → Email/contraseña**, **Firestore** (modo producción, región `nam5` o `us-east1`) y **Storage**. Añade una **app web** y ejecuta:
   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<id-del-proyecto> --platforms=web
   ```
   Eso rellena `lib/firebase_options.dart`. Pon el mismo id en `.firebaserc`.
2. **Desplegar reglas, índices y funciones:**
   ```sh
   firebase deploy --only firestore:rules,firestore:indexes,storage
   (cd functions && npm install) && firebase deploy --only functions
   ```
   Al desplegar Storage, Firebase pide un permiso entre servicios (las reglas leen el rol en Firestore): acéptalo.
3. **Primera cuenta de Dirección** (con una clave de servicio descargada de la consola, nunca al repositorio):
   ```sh
   npm install
   export GOOGLE_APPLICATION_CREDENTIALS=/ruta/serviceAccount.json
   npm run crear-direccion -- correo@spadorackets.com "Nombre Apellido"
   ```
   El resto de cuentas (staff, otra dirección) se crean desde la app: **Más → Equipo**.
4. **Cargar grupos, alumnas y datos bancarios**: copia `scripts/datos_club.ejemplo.json` a `scripts/datos_club.json`, rellénalo y `npm run cargar-datos -- scripts/datos_club.json`. Genera `codigos_generados.csv` con el código de cada familia. También se puede hacer desde la app (**Más → Alumnas y códigos**).
5. **Compilar y publicar en Netlify:**
   ```sh
   flutter build web --release
   npx netlify-cli deploy --dir=build/web --prod
   ```
   O arrastra la carpeta `build/web` en Netlify. `web/_headers` y `web/_redirects` ya van incluidos.
6. **Avisos push (opcional):** consola de Firebase → Cloud Messaging → certificado web push → copia la clave pública en `ClubConfig.vapidKey` y la configuración en `web/firebase-messaging-sw.js`. En iPhone sólo llegan si la app está añadida a la pantalla de inicio.
7. En **Authentication → Configuración → Dominios autorizados**, añade el dominio de Netlify.

## Cómo lo usan las familias

1. Dirección da de alta a la alumna → la app genera un **código de 6 caracteres**.
2. La familia abre el enlace → **Crear cuenta con mi código**. Con dos hijas: segundo código en **Más → Vincular otra alumna**.
3. En el móvil: *Compartir → Añadir a pantalla de inicio*.

## Probar en local sin tocar datos reales

```sh
firebase emulators:start --project demo-spado-rackets --only auth,firestore,storage
npm run demo-emulador              # 10 alumnas, 3 grupos, fichajes, cuotas y chats de ejemplo
flutter run -d chrome --dart-define=EMULADOR=true
```
Cuentas de demostración (contraseña `spado1234`): `direccion@`, `laura@`, `carlos@`, `garcia@`, `lopez@demo.spado`.

## Decisiones que conviene revisar

- **Moneda**: cada grupo tiene su cuota en RD$ o US$; se pueden publicar varias cuentas bancarias.
- **Pagos**: la familia transfiere y sube el justificante; Dirección lo valida a mano. No hay cobro con tarjeta.
- **Vencimiento**: las cuotas pasan a "Vencida" a partir del día 11 (`ClubConfig.diaVencimientoCuota`). No hay recargos ni bloqueo automáticos como en Soccer; se pueden añadir.
- **Ubicación**: fichar la exige (`ClubConfig.fichajeExigeUbicacion`). No se comprueba un radio: se guarda dónde fichó y Dirección lo ve en el mapa.
- **Registro de jornada (España, art. 34.9 ET)**: los fichajes no se pueden editar desde la app. Si el negocio opera en RD esto no aplica; conviene confirmarlo.
- **Datos de menores**: antes de abrir a las familias, publicar política de privacidad y recoger consentimiento (en Soccer hay textos base en `lib/config/textos_legales.dart`).
