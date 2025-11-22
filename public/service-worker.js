const CACHE_VERSION = 'v8-2025-11-22-FORCE-UPDATE';

self.addEventListener('install', (event) => {
  // Force immediate activation
  self.skipWaiting();

  // Delete ALL caches immediately
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => caches.delete(cacheName))
      );
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    // Delete ALL caches on activation
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => caches.delete(cacheName))
      );
    }).then(() => {
      // Take control immediately
      return clients.claim();
    })
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
