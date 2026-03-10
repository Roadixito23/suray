importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAORFNeZEwdeTBCrsm8YOdNlZ54M49JE8k',
  appId: '1:48825885200:web:703066e836ed404298a095',
  messagingSenderId: '48825885200',
  projectId: 'suray-web',
  authDomain: 'suray-web.firebaseapp.com',
  storageBucket: 'suray-web.firebasestorage.app',
  measurementId: 'G-5CX5GKS0KG',
});

const messaging = firebase.messaging();

// Manejar mensajes en segundo plano
messaging.onBackgroundMessage((payload) => {
  console.log('[SW] Mensaje en segundo plano:', payload);

  const notificationTitle = payload.notification?.title || 'Buses Suray';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
