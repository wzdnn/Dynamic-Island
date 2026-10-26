const HOST = "com.dynamicisland.whatsapp";
const recent = new Map();
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  const popup = sender.id === chrome.runtime.id && sender.url === chrome.runtime.getURL("popup.html");
  let web = false;
  try { web = sender.id === chrome.runtime.id && sender.frameId === 0 && new URL(sender.url).origin === "https://web.whatsapp.com"; } catch {}
  if (!popup && !web) { respond({ ok: false }); return; }
  const ping = popup && message?.kind === "ping";
  if (!ping && (!message || !["message", "call"].includes(message.kind) || typeof message.title !== "string" || !message.title.trim() || message.title.length > 160 || typeof message.body !== "string" || message.body.length > 1000)) {
    respond({ ok: false }); return;
  }
  const key = popup ? "popup" : sender.tab.id + ":" + message.kind;
  const now = Date.now();
  if (now - (recent.get(key) || 0) < 1000) { respond({ ok: false, error: "Tunggu sebentar sebelum mencoba lagi." }); return; }
  recent.set(key, now);
  for (const [id, time] of recent) if (now - time > 60000) recent.delete(id);
  const payload = ping ? { kind: "ping" } : { kind: message.kind, title: message.title, body: message.body };
  chrome.runtime.sendNativeMessage(HOST, payload).then(respond, () => respond({ ok: false, error: "Jalankan penyiapan ekstensi dari Dynamic Island terbaru, lalu buka aplikasinya." }));
  return true;
});
