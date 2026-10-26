const status = document.querySelector("#status");
async function send(payload) {
  try {
    const result = await chrome.runtime.sendMessage(payload);
    status.textContent = result?.ok ? (payload.kind === "ping" ? "Dynamic Island terhubung." : "Contoh terkirim ke Dynamic Island.") : result?.error || "Belum terhubung.";
  } catch { status.textContent = "Belum terhubung. Muat ulang ekstensi."; }
}
document.querySelector("#message").addEventListener("click", () => send({ kind: "message", title: "Tes WhatsApp Web", body: "Ini contoh notifikasi pesan dari ekstensi." }));
document.querySelector("#call").addEventListener("click", () => send({ kind: "call", title: "Tes panggilan WhatsApp Web", body: "Ini contoh indikasi panggilan, bukan panggilan nyata." }));
send({ kind: "ping" });
