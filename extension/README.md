# Dynamic Island · WhatsApp Web (awal/eksperimental)

## Memasang di Chrome dan Brave

1. Jalankan Dynamic Island v1.4.0. Klik kanan pil → **Siapkan ekstensi WhatsApp Web**.
   Folder ini akan dibuka, dan penghubung Native Messaging didaftarkan untuk akun Windows Anda.
2. Buka `chrome://extensions` di Chrome atau `brave://extensions` di Brave.
3. Aktifkan **Developer mode**, klik **Load unpacked**, pilih folder ini:
   `%LOCALAPPDATA%\DynamicIsland\extension`.
4. Muat ulang tab `https://web.whatsapp.com/`. Klik ikon ekstensi dan pastikan status
   **Dynamic Island terhubung**, lalu coba tombol tes pesan dan panggilan.
5. Ulangi langkah 2–4 di browser lainnya. Tidak perlu mengunduh paket tambahan.

Jalankan penyiapan lagi jika EXE dipindahkan. Jangan menghapus folder ekstensi selama masih
dipasang. Untuk menghapus ekstensi, pilih **Remove** di halaman Extensions masing-masing browser.
Registrasi penghubung hanya untuk ekstensi ID `neailjbinkkijmckjofkijnifeopfaaa`.

## Yang didukung

- Notifikasi yang dibuat halaman WhatsApp Web melalui Notification API, termasuk judul/isi
  yang tersedia. Izin notifikasi WhatsApp Web tetap dikelola oleh browser dan pengguna.
- Jika notifikasi tidak terlihat oleh ekstensi, kenaikan angka belum dibaca pada judul tab
  memunculkan pemberitahuan umum, tanpa nama atau isi pesan. Angka awal saat membuka tab
  tidak memunculkan notifikasi lama.
- Indikasi panggilan dari teks notifikasi Indonesia/Inggris, atau dialog yang memiliki
  tombol jawab/terima dan tolak. Bukan status resmi, tidak bisa menjawab/menolak otomatis.
- Tombol **Buka WhatsApp Web** di Dynamic Island membuka browser default; belum memfokuskan
  tab Chrome/Brave asal secara khusus.

## Batasan

Tab WhatsApp Web harus tetap terbuka dan login. Notifikasi yang berasal sepenuhnya dari
service worker, tab yang tidur/ditutup, pesan tambahan pada chat yang sudah belum dibaca,
dan perubahan antarmuka WhatsApp bisa tidak terdeteksi. Jumlah di judul tab tidak selalu
bertambah untuk setiap pesan. Panggilan hanya terdeteksi jika fitur tersebut tersedia
di akun Web dan memunculkan notifikasi/dialog yang cocok. Teks pesan biasa yang menyerupai
panggilan bisa menghasilkan indikasi keliru. Bahasa lain belum didukung.

Tes otomatis memakai data sintetis. Pesan/panggilan WhatsApp Web nyata pada Chrome dan
Brave belum diverifikasi; gunakan tombol tes untuk mengecek penghubung lokal terlebih dahulu.

## Privasi

Ekstensi hanya berjalan di `web.whatsapp.com`; tidak meminta akses semua situs atau riwayat
browser. Data diteruskan ke EXE melalui Native Messaging lalu named pipe yang dibatasi
ke akun/sesi Windows yang sama. Tidak membuka port HTTP, tidak memakai server tambahan,
dan tidak menulis isi pesan ke berkas/log. Data hanya berada di memori; panel dihapus setelah
15 detik. Notifikasi bisa terlihat ketika berbagi layar. Jika Dynamic Island mati, event
tidak disimpan untuk diputar ulang. Nonaktifkan ekstensi untuk menghentikan penerusan.
