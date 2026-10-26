(() => {
  const origin = "https://web.whatsapp.com";
  const callHint = /incoming (?:voice |video )?call|panggilan (?:suara |video )?masuk|calling you|sedang menelepon/i;
  let lastNotification = 0;
  const send = (kind, title, body) => chrome.runtime.sendMessage({ kind, title, body }).catch(() => {});
  window.addEventListener("message", (event) => {
    const data = event.data;
    if (event.source !== window || event.origin !== origin || data?.channel !== "dynamic-island-whatsapp") return;
    if (typeof data.title !== "string" || !data.title.trim() || data.title.length > 160 || typeof data.body !== "string" || data.body.length > 1000) return;
    lastNotification = Date.now();
    send(callHint.test(data.title + " " + data.body) ? "call" : "message", data.title, data.body);
  });
  let unread = null;
  let callVisible = false;
  const scan = () => {
    const count = Number(document.title.match(/^\((\d+)\)/)?.[1] || 0);
    if (unread !== null && count > unread) {
      const observedAt = Date.now();
      setTimeout(() => {
        if (lastNotification < observedAt - 2000) send("message", "WhatsApp Web", "Ada pesan belum dibaca baru. Buka WhatsApp Web untuk melihatnya.");
      }, 1500);
    }
    unread = count;
    // shortcut: only visible call dialogs with both answer and reject controls; update selectors when WhatsApp changes its UI.
    const incoming = [...document.querySelectorAll('[role="dialog"]')].some(dialog => {
      if (!dialog.getClientRects().length) return false;
      const labels = [...dialog.querySelectorAll('button, [role="button"]')]
        .filter(button => button.getClientRects().length)
        .map(button => (button.getAttribute("aria-label") || button.textContent || "").trim());
      return labels.some(label => /^(answer|accept|jawab|terima)( (voice|video|suara) (call|panggilan)| call| panggilan)?$/i.test(label)) &&
        labels.some(label => /^(decline|reject|tolak)( call| panggilan)?$/i.test(label));
    });
    if (incoming && !callVisible) send("call", "WhatsApp Web", "Dialog panggilan masuk terlihat. Buka WhatsApp Web untuk menjawab.");
    callVisible = incoming;
  };
  setInterval(scan, 2000);
})();
