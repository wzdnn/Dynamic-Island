(() => {
  const relay = (title, options) => window.postMessage({
    channel: "dynamic-island-whatsapp", title: String(title || "WhatsApp Web").slice(0, 160),
    body: String(options?.body || "").slice(0, 1000)
  }, "https://web.whatsapp.com");
  if (typeof window.Notification === "function") {
    window.Notification = new Proxy(window.Notification, {
      construct(target, args, newTarget) {
        const notification = Reflect.construct(target, args, newTarget);
        relay(args[0], args[1]);
        return notification;
      }
    });
  }
  // shortcut: service-worker-originated notifications are not visible here; use the unread-count fallback while the tab is open.
  const registration = window.ServiceWorkerRegistration?.prototype;
  if (registration?.showNotification) {
    const original = registration.showNotification;
    registration.showNotification = function (title, options) {
      const result = original.call(this, title, options);
      result.then(() => relay(title, options), () => {});
      return result;
    };
  }
})();
