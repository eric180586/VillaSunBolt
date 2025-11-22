const CACHE_VERSION = 'v7-2025-11-22-fortune-wheel-fix';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_VERSION) {
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => clients.claim())
  );
});

self.addEventListener('push', (event) => {
  if (!event.data) {
    return;
  }

  let notificationData;
  try {
    notificationData = event.data.json();
  } catch (error) {
    notificationData = {
      title: 'Villa Sun Notification',
      body: event.data.text(),
    };
  }

  const { title, body, icon, badge, data } = notificationData;

  const options = {
    body: body,
    icon: icon || '/VillaSun_Logo_192x192.png',
    badge: badge || '/VillaSun_Logo_72x72.png',
    vibrate: [200, 100, 200],
    tag: data?.tag || 'villa-sun-notification',
    requireInteraction: data?.requireInteraction || false,
    data: data || {},
  };

  event.waitUntil(
    self.registration.showNotification(title || 'Villa Sun', options)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const urlToOpen = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        for (let i = 0; i < windowClients.length; i++) {
          const client = windowClients[i];
          if (client.url === urlToOpen && 'focus' in client) {
            return client.focus();
          }
        }
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});

self.addEventListener('pushsubscriptionchange', (event) => {
  event.waitUntil(
    self.registration.pushManager.subscribe(event.oldSubscription.options)
      .then((subscription) => {
        console.log('Push subscription changed:', subscription);
      })
      .catch((error) => {
        console.error('Failed to resubscribe:', error);
      })
  );
});
