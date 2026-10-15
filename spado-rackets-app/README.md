# Spado Rackets — app web

Gestión de la escuela de raquetas: **fichaje del entrenador, asistencia, chat interno y cuotas con justificante**. Flutter Web + Firebase, la misma arquitectura que Spado Soccer, con un proyecto de Firebase **propio y separado**. Se publica en Netlify; no pasa por las tiendas.

| Perfil | Qué hace |
|---|---|
| **Dirección** | Panel (entrenadores que han fichado hoy, asistencia, justificantes por revisar, cuotas vencidas) · fichajes con mapa · asistencia por grupo · **generar los avisos de cuota** (una alumna, varias o todas) · **validar o rechazar el justificante** que sube cada familia · alumnas y códigos · grupos y cuota en RD$ · cuentas del equipo · datos bancarios · todos los chats |
| **Staff (entrenador)** | **Fichar llegada** (hora del servidor + ubicación, una vez al día) · pasar lista (P / F / J) de sus grupos · chat |
| **Familias** | Su hija, asistencia y %, avisar de una falta · su cuota y su importe (solo ven la suya) · cuentas bancarias con botón de copiar · adjuntar el justificante de pago · chat con el entrenador o con Dirección |

## Cómo funciona el cobro

1. Dirección **genera el aviso de cuota** del mes (Pagos → *Generar cuotas*): elige alumnas, un grupo entero, o todas; con la cuota de su grupo o un importe único. La familia lo ve en su pestaña Pagos y recibe un aviso.
2. La familia **transfiere** a una de las cuentas del club (Banco Popular en RD$ o Banreservas en US$) **dentro de los 5 primeros días del mes** y **sube el justificante**.
3. Dirección **valida** el justificante (la cuota pasa a *Pagada*) o lo **rechaza** con un motivo que ve la familia.

No hay pago con tarjeta, ni recargos por mora, ni se envía ningún recibo: solo se valida el justificante que sube la familia. Las cuotas se cobran en RD$. Pasado el día 5, una cuota sin pagar se marca *Vencida* (solo es un aviso visual).

## Asistencia

El entrenador pasa lista; a la familia solo le llega la **confirmación** de que su hija está en el entrenamiento. Una familia puede avisar de una falta desde la app y el entrenador la ve ya marcada como justificada.

## Registro de familias

Las familias se registran ellas mismas con su email, con el **código de 6 caracteres** que Dirección genera al dar de alta a la alumna. Si Dirección anota el **email de la familia** en la ficha de la alumna, solo ese correo podrá usar el código. Una familia con dos hijas usa un segundo código en *Más → Vincular otra alumna*. Las cuentas de **staff** las crea Dirección (*Más → Equipo*) y se les entrega una contraseña provisional.
*(Más adelante: un enlace para que las familias creen ellas la ficha de cada alumna.)*

## Seguridad

Cada permiso se comprueba también en el servidor, no solo en la app:

- **Reglas de Firestore y Storage** con **29 pruebas** que intentan saltárselas: `npm run test:reglas`. Cubren que nadie se da otro rol ni grupos, que el fichaje usa la hora del servidor y no se edita, que cada familia solo ve sus hijas, cuotas y marcas, que no se puede marcar una cuota como pagada desde la app, que nadie firma un mensaje como otro y que un justificante solo lo abre quien lo subió y Dirección.
- **Cloud Functions**: el código de vinculación se comprueba en servidor (uno por alumna, un solo uso, y solo con el correo reservado si lo hay), las cuentas del club solo las crea Dirección, y los contadores de chat y los avisos los lleva el servidor.
- **Privacidad**: política y condiciones de uso accesibles sin cuenta, y consentimiento obligatorio al registrarse (se guarda cuándo y con qué versión). **Los textos son una base: los debe revisar un abogado** y hay que poner el correo del club (`lib/config/textos_legales.dart`).
- Cabeceras de seguridad para Netlify en `web/_headers`.

## Puesta en marcha (una sola vez)

Necesitas: Flutter, Node 22 y Firebase CLI (`npm i -g firebase-tools`).

1. **Proyecto Firebase nuevo** (separado de Soccer) en plan **Blaze** (hace falta para Functions; con 10 alumnas el coste real es ~0). Activa **Authentication → Email/contraseña**, **Firestore** (producción) y **Storage**. Añade una **app web** y ejecuta:
   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<id-del-proyecto> --platforms=web
   ```
   Pon el mismo id en `.firebaserc`.
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
4. **Cargar grupos, alumnas y datos bancarios** (o hacerlo a mano desde la app): copia `scripts/datos_club.ejemplo.json` a `scripts/datos_club.json`, rellénalo y `npm run cargar-datos -- scripts/datos_club.json`. Genera `codigos_generados.csv` con el código de cada familia. Las cuentas bancarias oficiales ya vienen precargadas en la app.
5. **Compilar y publicar en Netlify:**
   ```sh
   flutter build web --release
   npx netlify-cli deploy --dir=build/web --prod
   ```
   `web/_headers` y `web/_redirects` ya van incluidos. En **Authentication → Configuración → Dominios autorizados** añade el dominio de Netlify.
6. **Avisos push (opcional):** consola de Firebase → Cloud Messaging → certificado web push → clave pública en `ClubConfig.vapidKey` y configuración en `web/firebase-messaging-sw.js`. En iPhone solo llegan si la app está añadida a la pantalla de inicio.

## Probar en local sin tocar datos reales

```sh
firebase emulators:start --project demo-spado-rackets --only auth,firestore,storage
npm run demo-emulador              # 10 alumnas, 3 grupos, fichajes, cuotas y chats de ejemplo
flutter run -d chrome --dart-define=EMULADOR=true
```
Cuentas de demostración (contraseña `spado1234`): `direccion@`, `laura@`, `carlos@`, `garcia@`, `lopez@demo.spado`.

## Pendiente

- Conectar el proyecto de Firebase y publicar (pasos 1–5).
- Cargar los listados reales de grupos, alumnas, horarios y días.
- Revisión legal de los textos y correo de contacto del club.
- Opcional más adelante: enlace para que las familias creen la ficha de cada alumna; avisos push.
