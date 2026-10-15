// Service worker de avisos push (Firebase Cloud Messaging).
//
// Recibe los avisos cuando la app está cerrada o en segundo plano. Misma
// configuración que lib/firebase_options.dart.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: 'AIzaSyAeGfQbsUsFAqJ8v7LkEcUqAkHcT4fg_WE',
  appId: '1:928554561378:web:b44544610fe04fcf37463b',
  messagingSenderId: '928554561378',
  projectId: 'spado-rackets',
};

if (firebaseConfig.projectId !== 'PENDIENTE') {
  firebase.initializeApp(firebaseConfig);
  firebase.messaging();
}
