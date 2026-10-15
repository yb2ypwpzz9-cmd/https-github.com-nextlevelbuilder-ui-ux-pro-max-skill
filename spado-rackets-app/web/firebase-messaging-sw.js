// Service worker de avisos push (Firebase Cloud Messaging).
//
// Recibe los avisos cuando la app está cerrada o en segundo plano. Necesita la
// misma configuración que lib/firebase_options.dart: rellénala al conectar el
// proyecto (ver README, paso 1). Mientras esté vacía, simplemente no hay push.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: 'PENDIENTE',
  appId: 'PENDIENTE',
  messagingSenderId: 'PENDIENTE',
  projectId: 'PENDIENTE',
};

if (firebaseConfig.projectId !== 'PENDIENTE') {
  firebase.initializeApp(firebaseConfig);
  firebase.messaging();
}
