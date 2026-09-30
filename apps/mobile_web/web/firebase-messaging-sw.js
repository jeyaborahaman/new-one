// Receives push notifications while the web app is closed or in the background.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDugZRuGHcxqgq83LKMR9MdjbFj2ai2sNg',
  authDomain: 'call-1c522.firebaseapp.com',
  projectId: 'call-1c522',
  storageBucket: 'call-1c522.firebasestorage.app',
  messagingSenderId: '415271614284',
  appId: '1:415271614284:web:552e912fb079a3526f01e9',
});

// The push payload already carries a notification, so the browser shows it; we only handle clicks.
firebase.messaging();
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = (event.notification.data && event.notification.data.FCM_MSG && event.notification.data.FCM_MSG.data) || event.notification.data || {};
  const target = data.conversation_id ? `/#/chat/${data.conversation_id}` : '/';
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const c of list) { if ('focus' in c) { c.navigate(target); return c.focus(); } }
    return clients.openWindow(target);
  }));
});
