const CACHE_VERSION = 'v5-2025-10-16-order-index-fix';

self.addEventListener('install', (event) => {
  console.log('Service Worker installing...', CACHE_VERSION);
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('Service Worker activating...', CACHE_VERSION);
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_VERSION) {
            console.log('Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => clients.claim())
  );
});

self.addEventListener('push', (event) => {
  console.log('Push notification received:', event);

  if (!event.data) {
    console.log('Push event but no data');
    return;
  }

  let notificationData;
  try {
    notificationData = event.data.json();
  } catch (error) {
    console.error('Error parsing push data:', error);
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
  console.log('Notification clicked:', event);
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
  console.log('Push subscription changed');
  event.waitUntil(
    self.registration.pushManager.subscribe(event.oldSubscription.options)
      .then((subscription) => {
        console.log('Resubscribed to push notifications');
        return fetch('/api/update-subscription', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            old: event.oldSubscription,
            new: subscription,
          }),
        });
      })
  );
});
