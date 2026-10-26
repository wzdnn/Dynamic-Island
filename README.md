# Dynamic Island for Windows

Prototipe desktop dengan tampilan terinspirasi iPhone. Unduh dan jalankan satu EXE dari release.
Tidak membutuhkan paket tambahan, administrator, atau perubahan execution policy permanen.
Hanya satu instance berjalan per akun/sesi Windows. Membuka launcher lagi langsung keluar
tanpa membuat panel kedua. Pengaman dilepas saat aplikasi ditutup atau proses berakhir.

## Menjalankan

Untuk Windows x64, unduh **Dynamic-Island-v1.5.0-win-x64.exe** dari
[GitHub Releases](https://github.com/wzdnn/Dynamic-Island/releases/latest), lalu klik dua kali.
Tidak perlu ZIP, instalasi, atau file pendukung di sebelah EXE. Launcher memakai
Windows PowerShell 5.1 dan WPF bawaan Windows tanpa jendela terminal atau Windows Script Host.
EXE belum ditandatangani digital.

File internal dibawa di dalam EXE dan disiapkan otomatis di
`%LOCALAPPDATA%\DynamicIsland\runtime` selama aplikasi berjalan, lalu dibersihkan saat keluar normal.
Pengaturan disimpan di `%LOCALAPPDATA%\DynamicIsland\settings.local.json`, terpisah dari EXE,
sehingga memindahkan EXE atau mengganti versi tidak mereset pilihan.
Saat upgrade, tutup versi lama lalu jalankan EXE baru. Untuk membawa pengaturan v1.2.0/source,
jalankan EXE baru sekali dari folder lama yang berisi `settings.local.json`; pengaturan lama
disalin hanya jika belum ada pengaturan pengguna. Setelah itu EXE boleh dipindahkan sendiri.

Untuk menjalankan dari source:

1. Unduh ZIP repository ini atau clone dengan Git, lalu ekstrak ke folder tetap.
2. Klik dua kali `Start Island.vbs` untuk menjalankan tanpa jendela terminal. `Start Island.cmd`
   juga tersedia dan meneruskan ke launcher yang sama, tetapi jendela CMD dapat muncul sesaat.
   Launcher memakai Windows Script Host dan **Windows PowerShell 5.1**
   dan WPF bawaan Windows; menjalankan skrip melalui PowerShell 7 tidak didukung.
3. Klik pil untuk membuka panel. Klik kanan lalu pilih **Keluar Dynamic Island** untuk menutup.

Integrasi media membutuhkan aplikasi yang menyediakan sesi media Windows; telah diuji
dengan Spotify desktop. Notifikasi Windows dari semua aplikasi, termasuk browser, dibaca tanpa ekstensi. Deteksi panggilan WhatsApp Desktop tetap tersedia; ekstensi WhatsApp Web
untuk Chrome dan Brave tersedia sebagai fitur awal/eksperimental.
Tidak diperlukan instalasi .NET SDK atau paket tambahan.

## Startup opsional

Buat shortcut ke EXE yang diunduh (atau `Start Island.vbs` untuk source), lalu letakkan shortcut tersebut dalam folder Startup
pengguna (buka `shell:startup` lewat Run). Aplikasi kemudian berjalan setelah login Windows.
Jangan memindahkan folder proyek tanpa memperbarui shortcut. Hapus shortcut untuk
menonaktifkan startup; tindakan ini tidak menghapus aplikasi. Shortcut dan pengaturan
Windows lokal tidak disertakan dalam repository.

## WhatsApp Web opsional (Chrome dan Brave)

Ekstensi tidak diperlukan untuk notifikasi browser yang masuk ke pusat notifikasi Windows. Ekstensi tetap tersedia untuk indikasi panggilan dan aktivitas khusus WhatsApp Web. Notifikasi Windows dan ekstensi dengan judul/isi yang sama digabung dalam jendela 15 detik, termasuk setelah panel ditutup. Pemberitahuan umum angka belum dibaca dari ekstensi hanya digunakan saat pembaca Windows tidak terhubung.

Klik kanan pil → **Siapkan ekstensi WhatsApp Web (opsional)**, lalu pasang folder yang terbuka dengan
**Load unpacked** di `chrome://extensions` atau `brave://extensions` (Developer mode).
Muat ulang tab WhatsApp Web dan klik ikon ekstensi untuk tes koneksi, pesan, dan panggilan.
Folder ekstensi dibawa di dalam EXE dan disiapkan otomatis di
`%LOCALAPPDATA%\DynamicIsland\extension`. Penyiapan mendaftarkan Native Messaging untuk
akun pengguna; tidak memasang ekstensi diam-diam. Jika EXE dipindah, jalankan penyiapan lagi.

Notifikasi halaman diteruskan, dengan pemberitahuan umum dari kenaikan angka belum dibaca
sebagai cadangan. Panggilan adalah **indikasi** dari teks notifikasi atau dialog jawab/tolak,
bukan status telepon resmi. Tab harus terbuka dan login. Notifikasi service worker dan
perubahan UI WhatsApp dapat tidak terdeteksi. Tombol buka memakai browser default.
Pencocokan tidak memakai ID pesan bersama: format teks yang berbeda atau selisih lebih dari 15 detik masih dapat lolos sebagai notifikasi terpisah. Dialog panggilan Web dan indikasi panggilan dari WA/browser dalam rentang tersebut digabung; dua panggilan bersamaan dapat dianggap satu indikasi.
Lihat [petunjuk, privasi, dan batasan lengkap](extension/README.md).

## Fitur

- Pil hitam di tengah atas area kerja monitor utama, di atas jendela biasa.
- Klik kanan pil → **Always on top** untuk mencentang/menghapus centang agar panel selalu
  di atas atau dapat tertutup jendela lain. Perubahan langsung berlaku dan disimpan di
  `%LOCALAPPDATA%\DynamicIsland\settings.local.json` untuk EXE, atau `settings.local.json`
  dalam folder source jika menjalankan skrip langsung, termasuk setelah restart. Default aktif
  jika belum ada pengaturan; folder pengaturan harus dapat ditulis.
  Jika tertutup, minimalkan jendela yang menutupinya
  untuk mengakses pil lagi.
- Notifikasi pesan/panggilan sementara tampil di atas jendela biasa meskipun **Always on top**
  mati. Setelah notifikasi habis (15 detik), ditutup/dikecilkan, atau jendela panggilan Desktop
  berakhir, panel kembali mengikuti pilihan semula. Centang dan pengaturan tersimpan tidak berubah.
- Klik untuk membuka kontrol media; Escape untuk mengecilkan.
- Buka/tutup memakai transisi tinggi dan fade isi panel; klik cepat melanjutkan dari
  posisi animasi saat itu. Jika animasi Windows dimatikan, panel berubah langsung.
- Judul panjang di panel terbuka bergulir perlahan bolak-balik dengan jeda di kedua ujung.
  Judul pendek tetap diam; guliran berhenti saat panel ditutup atau notifikasi tampil.
  Pengaturan animasi Windows juga berlaku untuk guliran; tooltip tetap memuat judul lengkap.
- Jam diperbarui setiap detik; baterai dibaca setiap 30 detik.
- Kontrol media mengirim tombol multimedia Windows ke aplikasi yang menanganinya.
- Pil kecil menampilkan cover, judul lagu, serta tombol previous, play/pause, dan next.
  Klik area cover/judul untuk membuka panel lengkap; tombol musik tidak membuka panel.
  Jika tidak ada media, pil kembali menampilkan jam. Judul panjang dipotong dengan elipsis
  dan bisa dibaca lengkap dengan mengarahkan kursor ke judul.
- Saat pil dibuka, judul, artis, dan cover mengikuti sesi media yang dipilih Windows.
  Kontrol previous/play-pause/next tetap berada di baris atas, tanpa duplikasi di panel.
  Panel musik bergantian dengan panel notifikasi/panggilan; progres dan volume tersembunyi
  saat notifikasi tampil. Status akses notifikasi Windows tersedia pada menu klik kanan.
  Pembacaan berjalan di latar belakang setiap beberapa detik. Pemutar harus menyediakan
  metadata melalui Windows System Media Transport Controls; cover bisa berupa artwork
  lagu atau thumbnail video dari pemutar. Jika gambar tidak tersedia/rusak, ikon musik
  ditampilkan. Cover hanya disimpan di memori, tidak diunduh dari layanan lain atau ditulis
  ke disk. Gambar di atas 5 MB tidak dimuat. Media yang dijeda tetap dapat ditampilkan.
- Klik kanan pil → Keluar Dynamic Island untuk menutup.
- Panel terbuka menyediakan slider **Volume aplikasi** 0–100%. Klik/geser lalu lepaskan,
  atau gunakan keyboard, untuk mengubah volume sesi aplikasi musik di mixer Windows.
  Ini tidak mengubah master volume laptop atau slider internal Spotify. Nilai 0 membisukan
  sesi; nilai di atas 0 mengaktifkan suaranya kembali. YouTube di Brave didukung lewat volume
  aplikasi Brave; tab Brave lain yang bersuara ikut terpengaruh, bukan hanya tab YouTube.
  Volume disinkronkan setiap detik saat
  panel terbuka. Dukungan saat ini untuk sumber media beridentitas executable (teruji:
  `Spotify.exe`) serta identitas media `Brave` pada perangkat keluaran multimedia default. Jika sesi tidak ditemukan,
  kontrol dinonaktifkan. Perutean audio aplikasi ke perangkat lain belum didukung.
- Bagian progres yang terisi memakai warna rata-rata cover yang dibuat lebih lembut dan
  terang. Warna dihitung sekali saat cover berubah; tanpa cover valid, progres kembali
  netral. Slider volume dan latar pil tetap memakai warna semula.
- Panel terbuka menampilkan posisi/durasi dan slider lagu. Klik atau geser slider lalu
  lepaskan untuk seek; keyboard panah, Home/End, dan Page Up/Down juga didukung.
  Posisi bergerak mengikuti timeline Windows saat playing dan berhenti saat pause.
  Slider dinonaktifkan jika durasi atau dukungan seek tidak tersedia. Permintaan seek
  memeriksa sumber, judul, dan artis agar pergantian lagu saat menggeser tidak mengubah
  posisi lagu lain. Kegagalan seek ditampilkan di bawah slider. Kontrol dan pembacaan
  tetap berjalan di latar belakang. Seek Spotify telah diuji dengan perubahan posisi nyata.

## Batas versi awal

Notifikasi baru semua aplikasi dibaca lewat Windows UserNotificationListener secara asinkron.
Status koneksi muncul saat panel dibuka. Pada laptop ini API sudah mengembalikan izin Allowed
dan berhasil membaca notifikasi dari Windows PowerShell tanpa paket tambahan; ini tidak
menjamin konfigurasi yang sama pada komputer lain. Izin tetap diperiksa saat membaca.

Panel menampilkan notifikasi Windows dari semua aplikasi, termasuk browser. Browser dan situs harus mengizinkan notifikasi desktop; badge atau popup yang hanya ada di halaman tidak dapat dibaca melalui Windows. Nama sumber mengikuti identitas aplikasi yang diberikan Windows, sehingga situs dapat tampil sebagai nama browser. Tombol Tutup menutup panel notifikasi umum; tombol Buka WhatsApp tetap tersedia untuk WhatsApp Desktop. Notifikasi yang
lebih lama daripada waktu aplikasi dimulai tidak ditampilkan ulang. Isi pesan tidak disimpan
ke berkas atau dicetak ke log; teks di panel dihapus setelah 15 detik atau saat menekan Escape. Cache pencocokan duplikat hanya berada di memori, maksimal 64 entri, dan dihapus setelah 15 detik.
Pesan akan terlihat di layar, termasuk ketika layar dibagikan. Beberapa pesan dalam satu
interval digabung dengan menampilkan yang terbaru saja. Notifikasi asli tidak dihapus.

Teks seperti “Incoming voice call” atau “Panggilan video masuk” diberi label **Kemungkinan
panggilan masuk**. Ini hanya petunjuk dari teks, bukan status telepon langsung; pesan biasa
dengan kata-kata tersebut juga bisa mendapat label itu. Tombol Buka WhatsApp membuka aplikasi
untuk menjawab/menolak di WhatsApp sendiri. Tidak ada tombol jawab/tolak otomatis.

Panggilan juga dideteksi dari jendela WhatsApp berjudul `Voice call`, `Video call`,
`Panggilan suara`, atau `Panggilan video`, dengan pemeriksaan identitas paket proses.
Panggilan suara masuk telah diamati memakai jendela `Voice call` tanpa toast Windows.
Panel bertahan selama jendela itu terdeteksi, lalu mengecil ketika jendelanya hilang.
Escape dapat mengecilkan panel lebih awal; klik pil untuk membukanya lagi.
Tombol Buka panggilan mengaktifkan jendela tersebut, tanpa menjawab/menolak otomatis.
Status berdering, tersambung, masuk/keluar, dan nama penelepon tidak tersedia melalui judul
jendela; label panel hanya menyatakan ada jendela panggilan. Perubahan judul oleh WhatsApp
dapat memerlukan pembaruan pendeteksi. Pesan yang datang selama panel panggilan aktif tidak
menggantikan panel dan tetap tersedia di WhatsApp/pusat notifikasi.

Jika status akses gagal, periksa izin akses notifikasi Windows. Aplikasi mencoba lagi setiap
30 detik tanpa mengubah izin sistem. Pastikan notifikasi aplikasi, browser, dan situs yang diinginkan aktif. Deteksi jendela
panggilan berjalan terpisah dari izin toast dan tidak bergantung pada banner Windows.

Belum ada dukungan banyak monitor atau installer.
Panel dapat menutupi bagian atas aplikasi; keluar melalui menu jika mengganggu.

## Pemeriksaan

Build EXE tunggal dengan `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1`.
Build memakai compiler .NET Framework bawaan Windows x64, menguji ekstraksi resource dan migrasi
pengaturan, menjalankan SelfTest melalui EXE, dan menghasilkan EXE beserta checksum SHA-256
di `dist`. Build/test ekstensi memerlukan Node.js; pengguna aplikasi tidak memerlukannya.
Tidak membutuhkan .NET SDK. Hanya EXE yang perlu diunduh; folder ekstensi disiapkan dari EXE.
Untuk memeriksa EXE secara mandiri, jalankan dengan argumen `--self-test` dan periksa exit code (0 = lolos).

Pembaca media memakai ulang satu runspace dan session manager. Cover disimpan di memori
per lagu; perubahan lagu memicu pembacaan baru, dengan pemeriksaan ulang tiap 30 detik
untuk artwork yang berubah terlambat (5 detik jika cover belum tersedia). Cover dengan
isi sama tidak didekode ulang. Timeline/volume yang tersembunyi tidak diperbarui tiap tick.
Semua sesi pembaca ditutup ketika aplikasi keluar.

Validasi optimasi: tes integrasi cache/worker, peluncuran kedua yang langsung berhenti,
serta render panel musik (277 px) dan contoh notifikasi (201 px) lolos. Sampel CPU 10 detik
di laptop ini: 0,27 menjadi 0,20 detik CPU; working set sekitar 252 menjadi 210 MB.
Sampel singkat ini bukan benchmark jangka panjang; penggunaan tergantung pemutar dan aktivitas.

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Island.ps1 -SelfTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Island.ps1 -IntegrationTest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Test-Notifications.ps1
```

Pemeriksaan memuat XAML asli, menguji buka/tutup dan penghapusan isi panel, filter paket WhatsApp,
petunjuk panggilan Indonesia/Inggris, lalu membaca API asli tanpa mencetak isi pesan.
