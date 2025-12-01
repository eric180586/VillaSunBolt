self.addEventListener("push", function (event) {
  const data = event.data ? event.data.json() : {};
  const options = {
    body: data.body || "Du hast eine neue Benachrichtigung!",
    icon: "/icon-192.png",
    badge: "/badge-72.png",
    data: {
      url: data.url || "/",
      ...data
    }
  };
  event.waitUntil(
    self.registration.showNotification(data.title || "Benachrichtigung", options)
  );
});

self.addEventListener("notificationclick", function (event) {
  event.notification.close();
  const url = event.notification.data && event.notification.data.url;
  if (url) {
    event.waitUntil(
      clients.matchAll({ type: "window" }).then(function (windowClients) {
        for (let client of windowClients) {
          if (client.url === url && "focus" in client) {
            return client.focus();
          }
        }
        if (clients.openWindow) {
          return clients.openWindow(url);
        }
      })
    );
  }
});
