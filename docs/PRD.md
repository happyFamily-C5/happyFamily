# Product Requirements Document — .kumpul

- **Status:** Approved baseline berbasis audit codebase dan keputusan pemilik produk
- **Versi:** 1.1
- **Tanggal audit:** 2 September 2026
- **Baseline source:** commit `5754a2e` pada branch `hendra/add-backend`, identik dengan `staging` saat audit
- **Platform:** iOS 26+, terdiri dari aplikasi utama dan App Clip
- **Nama internal codebase/build:** happyFamily

## 1. Ringkasan Eksekutif

**.kumpul** membantu pengelola limbah tekstil membuat dan memantau acara pengumpulan pakaian, sementara donor dapat membuka sebuah acara melalui App Clip, memeriksa kelayakan pakaian menggunakan kamera, memilih cara pengiriman, lalu memperoleh label paket berisi QR code tanpa harus memasang aplikasi penuh. Nama `happyFamily` tetap dipakai sebagai nama internal repository dan build sampai migrasi teknis nama produk dilakukan.

Codebase saat ini sudah membuktikan konsep dua sisi produk:

1. **Aplikasi utama untuk organizer/admin** memiliki dashboard, alur pembuatan acara tiga langkah, pemilihan lokasi melalui peta, kategori donasi, kapasitas, serta tampilan rekap.
2. **App Clip untuk donor** memiliki halaman detail acara, formulir donor, pemindaian pakaian secara on-device, pemilihan metode pengiriman, serta pembuatan dan pembagian label QR.

Namun, implementasi saat ini masih berupa functional prototype. Hampir seluruh data acara, donor, progres kapasitas, rekap, dan booking hidup sementara di memori atau berupa data contoh. Belum ada backend, autentikasi, persistensi, sinkronisasi antartarget, analytics, pengelolaan status donasi, atau pengikatan App Clip invocation ke acara tertentu. PRD ini mendefinisikan produk target yang menyatukan kedua pengalaman tersebut tanpa menyamakan prototype dengan fitur produksi.

Pada target MVP, aplikasi penuh memiliki dua mode: mode Pengelola untuk operasional dan mode Donor untuk memeriksa satu booking menggunakan booking ID serta nomor telepon.

## 2. Problem Statement

### 2.1 Masalah organizer

Pengelola limbah tekstil membutuhkan cara yang ringkas untuk:

- membuat acara dan menentukan kapan, di mana, serta jenis pakaian apa yang diterima;
- menyebarkan pintu masuk donor yang langsung menuju acara yang benar;
- mengurangi pakaian yang tidak layak atau masih memiliki aksesori yang perlu dilepas;
- mengetahui kapasitas yang telah terpakai, jumlah donor, dan donasi terbaru;
- mengidentifikasi paket yang datang dan menghubungkannya ke booking donor;
- merekap dampak acara tanpa menggabungkan data secara manual.

### 2.2 Masalah donor

Calon donor ingin menyumbangkan pakaian dengan cepat, tetapi sering tidak tahu:

- acara mana yang masih aktif dan di mana drop point berada;
- apakah pakaian memenuhi kriteria acara;
- apakah kancing, resleting, logam, ornamen, atau komponen tertentu harus dilepas;
- bagaimana mengirim paket dan informasi apa yang perlu ditempelkan;
- apakah pendaftaran donasi berhasil dan bagaimana paket akan dikenali oleh organizer.

Memaksa donor mengunduh aplikasi penuh akan menambah friksi untuk interaksi yang pendek dan kontekstual. Karena itu, App Clip adalah kanal utama donor.

## 3. Product Vision

Menjadikan donasi pakaian di Indonesia sebagai alur yang cepat, terarah, dan terukur: pengelola limbah tekstil dapat menerbitkan acara yang siap menerima donasi, donor dapat memvalidasi dan mendaftarkan pakaian dalam beberapa menit, dan setiap paket dapat ditelusuri sampai masuk ke rekap acara.

## 4. Tujuan Produk

### 4.1 Tujuan utama

1. Memungkinkan organizer membuat dan menerbitkan acara donasi tekstil yang memiliki jadwal, lokasi, kriteria, dan kapasitas jelas.
2. Memungkinkan donor masuk ke acara yang tepat melalui App Clip invocation/deep link tanpa login dan tanpa instalasi aplikasi penuh.
3. Membantu donor menyaring pakaian sebelum dikirim menggunakan pemeriksaan on-device.
4. Membuat booking donasi dan label QR yang dapat dihubungkan kembali ke acara dan donor.
5. Menyediakan dashboard dan rekap yang berasal dari data transaksi nyata, bukan data contoh.
6. Menjaga data pribadi donor seminimal mungkin dan menjalankan analisis foto di perangkat selama kebutuhan produk tidak mengharuskan upload.
7. Mendukung banyak akun Pengelola dalam satu platform sejak MVP. Setiap Pengelola memiliki satu workspace/tenant organisasi yang terisolasi dari Pengelola lain.

### 4.2 Non-goals awal

Kecuali diputuskan lain oleh pemilik produk, fase pertama tidak bertujuan menjadi marketplace pakaian, platform pembayaran, penyedia layanan kurir, aplikasi sosial, atau sistem inventori gudang lengkap.

### 4.3 Keputusan produk yang telah dikonfirmasi

- Nama produk yang tampil kepada pengguna adalah **.kumpul**.
- EcoTouch Indonesia hanya data contoh demo, bukan organisasi khusus atau satu-satunya klien.
- MVP mendukung banyak Pengelola. Istilah Organizer, Organisasi, dan Pengelola merujuk pada orang/role produk yang sama; setiap akun Pengelola memiliki satu workspace organisasi teknis untuk isolasi data.
- Pengelola juga bertindak sebagai petugas penerimaan; tidak ada role operator atau membership organizer tambahan pada MVP.
- Rilis pertama hanya untuk Indonesia dan seluruh copy produk menggunakan Bahasa Indonesia.
- Status acara memakai Bahasa Indonesia: **Draf, Akan Datang, Berlangsung, Selesai, Ditutup,** dan **Dibatalkan**. Terbit adalah aksi, bukan status.
- Acara berpindah menjadi **Selesai** secara otomatis setelah waktu berakhir.
- Banner wajib sebelum acara dapat diterbitkan; deskripsi bersifat opsional.
- Setiap acara memiliki tepat satu drop point dan satu jadwal operasional.
- Kapasitas kilogram adalah batas keras.
- Kapasitas baru terpakai ketika paket diterima dan ditimbang oleh Pengelola.
- Booking baru tidak dapat dibuat ketika kapasitas acara sudah penuh.
- Kategori MVP dibatasi pada Katun, Linen, Rayon, Wol, Tencel, Sutra, Tidak Elastis, Denim, Tidak Berenda, dan Poliester.
- Scanner hanya menilai aksesori dan jumlah pakaian, bukan material atau kecocokan kategori acara.
- Kancing, resleting, saku, logam, dan ornamen selalu harus dilepas.
- Hasil scanner adalah rekomendasi; Pengelola tetap melakukan verifikasi akhir saat menerima paket. Tidak ada ambang akurasi numerik untuk MVP dan keputusan tersebut tidak dibuka kembali; kualitas ditingkatkan berdasarkan hasil pilot.
- Salinan foto yang dibuat/dipilih oleh .kumpul hanya hidup selama satu sesi App Clip untuk verifikasi dan tidak diunggah atau disimpan; foto asli yang sudah dimiliki pengguna di galeri tidak dihapus oleh aplikasi.
- Hanya hasil/status pemeriksaan aktif terakhir yang dapat dipertahankan tanpa foto. Percobaan lama yang digantikan dan seluruh data item yang dihapus tidak disimpan.
- Donor wajib memberikan nama, nomor telepon Indonesia, estimasi berat pakaian yang didonasikan, dan status pakaian; donor anonim tidak diperbolehkan.
- Checkbox persetujuan syarat dan ketentuan wajib, tetapi naskah legalnya belum tersedia dan menjadi blocker rilis.
- Booking berlaku maksimal 12 jam dan berakhir lebih awal jika event mencapai end datetime.
- Metode pengiriman MVP dibatasi pada antar langsung, ojek online, dan ekspedisi; ketiganya selalu tersedia dan berupa instruksi manual tanpa integrasi kurir.
- Label berupa gambar yang dapat disimpan ke galeri dan memuat logo .kumpul, nama event, booking ID, QR, nama donor, serta nama, nomor telepon, dan alamat penerima dari snapshot booking. Barcode selain QR tidak diperlukan.
- Tombol QR di aplikasi utama hanya digunakan untuk memindai booking donor.
- Saat paket tiba, Pengelola mencatat berat, kondisi, dan alasan penolakan opsional bila ada.
- Satu booking harus diterima atau ditolak secara utuh; penerimaan sebagian tidak didukung.
- Donor unik pada rekap dihitung satu kali per event.
- Rekap dapat diekspor menjadi file CSV.
- Backend MVP menggunakan Supabase Hosted: PostgreSQL sebagai source of truth, Supabase Auth, Edge Functions, PostgreSQL Functions/RPC, Cron, dan Storage. Kontrak lengkapnya ditetapkan pada `docs/BACKEND_PRD.md`.
- Pengelola dapat login melalui Sign in with Apple atau email/password.
- Aplikasi membutuhkan kemampuan offline untuk melihat event yang telah tersimpan, membuat/mengedit Draf, dan memindai pakaian. Booking serta penerimaan/penolakan paket wajib online.
- Admin, Organizer, Organisasi, dan Pengelola dinormalisasi menjadi role Pengelola. Pengelola dapat menghapus data donor dan penghapusan tersebut tidak diwajibkan menyimpan alasan, waktu, atau identitas penghapus.
- Seluruh create/publish event, App Clip booking, scanner, QR reception, dan recap termasuk MVP pertama.
- Tidak ada target tanggal rilis atau milestone demo/TestFlight khusus yang telah ditetapkan.
- Pembagian deep modules disetujui.
- Event Domain, Donation Flow, Scanner Policy, Booking/Capacity, dan Invocation Resolver wajib memiliki test pada fase pertama.
- Booking aktif yang belum tiba otomatis dibatalkan ketika kapasitas event tercapai.
- Timezone acara otomatis ditentukan dari lokasi event.
- Donor dapat melihat status donasi setelah App Clip ditutup melalui aplikasi penuh.
- Kondisi penerimaan adalah Baik, Rusak, Basah, Kotor, atau Berjamur; Pengelola dapat memilih alasan penolakan atau menulis tambahan secara opsional.
- Pilot awal menargetkan 50 akun Pengelola/workspace organisasi dengan relasi satu-ke-satu pada MVP.
- Data donor dan booking disimpan selama satu bulan sejak event memasuki status terminal Selesai, Ditutup, atau Dibatalkan. Audit log disimpan selama satu bulan sejak audit event dibuat.
- North-star metric adalah total kilogram pakaian yang benar-benar diterima; belum ada target numerik awal.
- Donor membuktikan kepemilikan booking di aplikasi penuh menggunakan booking ID dan nomor telepon. Aplikasi penuh yang sama memiliki mode Donor dan Pengelola.
- Konflik Draf offline menggunakan aturan perubahan paling baru otomatis menang.
- Alasan penolakan tidak wajib. Pengelola dapat memilih preset Aksesori Belum Dilepas, Tidak Sesuai Kriteria, Rusak, Basah, Kotor, Berjamur, Melebihi Kapasitas, atau Lainnya; teks tambahan untuk Lainnya tidak wajib.
- Maksimal lima event Akan Datang/Berlangsung berlaku per Pengelola. Baseline load test adalah 1.000 booking per hari untuk seluruh platform.
- Jika donor menghapus item, seluruh riwayat/status scan item tersebut ikut dihapus.
- Pembuat aplikasi bertanggung jawab menulis dan menyetujui Syarat & Ketentuan serta Kebijakan Privasi.
- Status booking yang terlihat donor adalah Menunggu, Diterima, Ditolak, Kedaluwarsa, dan Dibatalkan; tidak ada status Dalam Pengiriman pada MVP.
- Ditutup adalah aksi manual untuk menghentikan event lebih awal. Selesai terjadi otomatis setelah end datetime dan event langsung tertutup secara operasional tanpa transisi tambahan ke Ditutup.
- Booking berakhir pada waktu yang lebih awal antara 12 jam setelah dibuat dan end datetime event.
- CSV boleh memuat nama dan nomor telepon donor bersama field operasional yang ditentukan.
- Pengelola mendaftar sendiri dan akunnya langsung aktif. Tidak ada undangan atau pengelolaan Pengelola lain pada MVP.
- Semua hari yang dipilih dalam satu jadwal event memakai jam buka dan tutup yang sama pada MVP.
- Seluruh field event dapat diedit selama Draf, Akan Datang, atau Berlangsung. Booking aktif mempertahankan snapshot data ketika dibuat. Event Selesai, Ditutup, atau Dibatalkan bersifat read-only dan tidak dapat dibuka kembali.
- Kapasitas tidak dapat diturunkan di bawah total berat aktual yang sudah diterima.
- Hanya event Akan Datang dan Berlangsung yang dihitung terhadap batas lima event aktif per Pengelola.
- Riwayat percobaan scan yang belum lolos tidak disimpan, termasuk ketika item akhirnya lolos; hanya hasil aktif/final item yang dipertahankan.
- Menutup event lebih awal otomatis membatalkan seluruh booking Menunggu. Alasan untuk menutup atau membatalkan event tidak wajib.

## 5. Aktor dan Peran

### 5.1 Donor

Pengguna App Clip yang melihat acara, mengisi informasi kontak minimum, memindai satu atau lebih pakaian, memilih metode pengiriman, membuat booking, dan memperoleh label QR. Setelah flow App Clip selesai, donor dapat memakai mode Donor pada aplikasi penuh untuk melihat status donasinya dengan memasukkan booking ID dan nomor telepon.

### 5.2 Pengelola

Pengelola limbah tekstil yang menggunakan aplikasi utama untuk membuat acara, menentukan kriteria, memantau progres, memindai dan menerima paket, mencatat hasil timbang, melihat rekap, serta menghapus data donor. Istilah Organizer, Organisasi, Admin, dan Pengelola pada keputusan sebelumnya dinormalisasi menjadi satu role pengguna: **Pengelola**. Setiap akun Pengelola memiliki satu workspace organisasi teknis dan tidak mengelola akun Pengelola lain pada MVP.

### 5.3 Product/Operations Owner

Pemilik konfigurasi organisasi, aturan penerimaan, data drop point, isi event, kalibrasi model, dan kebijakan data.

### 5.4 Pembuat aplikasi

Tim atau individu yang membangun .kumpul dan bertanggung jawab menulis serta menyetujui Syarat & Ketentuan dan Kebijakan Privasi sebelum rilis produksi.

## 6. Nilai Utama bagi Pengguna

- **Cepat:** donor tidak perlu menginstal aplikasi penuh.
- **Kontekstual:** setiap App Clip invocation membuka acara yang relevan.
- **Terarah:** donor mengetahui kriteria, lokasi, tenggat, dan metode pengiriman.
- **Preventif:** scanner memberi umpan balik sebelum pakaian dikirim.
- **Dapat ditelusuri:** booking dan label QR menghubungkan paket dengan acara.
- **Terukur:** organizer melihat progres dan dampak berdasarkan data aktual.

## 7. Kondisi Codebase Saat Ini

### 7.1 Sudah berfungsi sebagai prototype

- Aplikasi utama langsung membuka dashboard organizer.
- Dashboard memiliki empty state dan dapat membuka alur pembuatan acara.
- Organizer dapat memilih banner dari Photos, mengisi nama/deskripsi, memilih rentang tanggal, mencari atau mengetuk lokasi di MapKit, menentukan hari/jam operasional, memilih kategori pakaian, serta kapasitas 10–500 kg.
- Acara yang selesai dibuat tampil sebagai ongoing atau upcoming berdasarkan tanggal.
- App Clip menampilkan detail satu acara contoh, progres kapasitas, lokasi, peta, dan CTA donasi.
- Donor dapat mengisi nama dan nomor telepon.
- Donor dapat mengambil foto dengan kamera atau memilih foto dari galeri.
- Scanner on-device menggunakan Vision FeaturePrint dan model konfigurasi lokal untuk mendeteksi beberapa aksesori, memperkirakan tipe pakaian, dan menolak foto yang berisi lebih dari satu pakaian.
- Foto yang lolos dapat ditambahkan ke daftar pakaian sementara.
- Donor dapat memilih salah satu dari tiga metode pengiriman yang ditampilkan.
- Aplikasi dapat membuat booking ID lokal, mengubahnya menjadi QR code, merender label sebagai PNG, dan membagikannya melalui share sheet.
- Build system telah memisahkan aplikasi utama, target Personal Team, App Clip, preview host, unit test, dan UI test.

### 7.2 Masih berupa mock, placeholder, atau belum tersambung

- Tidak ada backend, API client, database, autentikasi, atau mekanisme persistensi.
- Acara yang dibuat hilang ketika proses aplikasi berakhir.
- Hanya sebagian field pembuatan acara yang masuk ke model acara; deskripsi, lokasi, jadwal operasional, kategori, dan beberapa data lain belum disimpan.
- App Clip selalu membuka acara EcoTouch contoh; invocation URL belum diparsing menjadi event ID.
- Kapasitas, countdown, lokasi, penerima, nomor telepon, dan alamat App Clip masih hardcoded.
- Tombol share acara, profil, mic search, QR, “lihat semua”, dan detail acara belum menjalankan fungsi produk.
- Search bar dashboard belum memfilter data.
- Rekap menggunakan angka nol atau data donor contoh yang tidak konsisten satu sama lain.
- Pilihan metode pengiriman disimpan hanya di state tampilan dan belum masuk ke booking.
- Tombol lanjut metode pengiriman belum diwajibkan menunggu pilihan.
- Copy prototype metode pengiriman masih menyebut batas tiga hari dan harus diubah menjadi masa berlaku maksimal 12 jam atau sampai event berakhir, mana yang lebih awal.
- Model menyimpan persetujuan syarat dan ketentuan, tetapi UI belum menampilkannya dan alur saat ini tidak membutuhkannya untuk lanjut.
- Kartu pakaian tidak dapat dihapus dan tombol detail/expand belum bekerja.
- Hanya pakaian yang lolos disimpan; keputusan untuk menyimpan histori penolakan belum ada.
- Scanner belum memverifikasi material/kategori yang dipilih organizer.
- Threshold scanner dinyatakan masih dikalibrasi dari foto editorial, belum dari foto ponsel lapangan.
- Booking tidak dikirim ke server, tidak memiliki status, dan QR tidak dapat divalidasi oleh aplikasi utama.
- Landing screen dan brand mark terpisah belum menjadi bagian dari alur utama.
- Test otomatis hanya mencakup satu perilaku hasil scan dan satu smoke test peluncuran.

## 8. Product Scope

### 8.1 MVP produksi — Pengelola

1. Autentikasi Pengelola melalui Sign in with Apple atau email/password.
2. Mendaftarkan akun/workspace sendiri yang langsung aktif dan melihat dashboard miliknya.
3. Membuat, menyimpan sebagai Draf, mengedit, menerbitkan, menutup, dan melihat detail acara.
4. Menentukan detail acara, jadwal, drop point, hari/jam operasional, kriteria, dan kapasitas.
5. Menghasilkan App Clip URL/QR untuk acara yang diterbitkan.
6. Melihat acara berstatus Draf, Akan Datang, Berlangsung, Selesai, Ditutup, dan Dibatalkan.
7. Mencari acara dan donasi.
8. Memindai QR label saat paket diterima.
9. Memverifikasi berat aktual serta status penerimaan.
10. Melihat rekap donasi berbasis data aktual dan mengekspornya sebagai CSV.
11. Melihat event yang telah tersimpan serta membuat/mengedit Draf ketika offline; penerbitan event dan penerimaan/penolakan paket tetap memerlukan koneksi.
12. Menghapus data donor sesuai retention dan kebijakan produk.
13. Mengedit seluruh field event selama belum terminal; booking aktif mempertahankan snapshot informasi saat dibuat.

### 8.2 MVP produksi — donor/App Clip

1. Membuka acara tertentu dari App Clip invocation.
2. Melihat detail, organizer, progres, tenggat, lokasi, dan aturan acara.
3. Membuka lokasi di Maps dan membagikan tautan acara.
4. Mengisi identitas minimum yang sah.
5. Mengisi estimasi berat pakaian yang didonasikan dan memindai setiap helai dengan kamera atau foto.
6. Menerima alasan yang dapat ditindaklanjuti ketika foto/pakaian tidak lolos.
7. Memindai ulang pakaian yang sama sampai lolos pemeriksaan awal, berpindah sementara ke pakaian lain, serta meninjau, menambah, melihat, atau menghapus item berstatus apa pun.
8. Melanjutkan hanya setelah minimal satu pakaian terdaftar dan seluruh pakaian yang masih ada berstatus lolos pemeriksaan awal.
9. Memilih salah satu dari tiga metode pengiriman yang selalu tersedia.
10. Mengonfirmasi booking ke backend ketika online.
11. Menerima nomor booking dan label QR yang dapat disimpan/dibagikan.
12. Mendapat instruksi langkah berikutnya dan tenggat booking maksimal 12 jam atau sampai event berakhir.
13. Menjalankan pemindaian pakaian secara on-device ketika offline setelah konteks event tersedia pada sesi/cache lokal.

### 8.3 MVP produksi — donor/aplikasi penuh

1. Donor dapat melihat status donasi setelah menutup App Clip melalui aplikasi penuh .kumpul.
2. Status berasal dari backend dan tidak boleh hanya mengandalkan state lokal App Clip.
3. Donor membuka mode Donor pada aplikasi penuh dan membuktikan kepemilikan booking menggunakan booking ID serta nomor telepon yang sama dengan booking.
4. Aplikasi penuh yang sama menyediakan mode Donor dan Pengelola.

### 8.4 Pasca-MVP kandidat

- Notifikasi status donasi.
- Histori donasi donor di luar masa retensi satu bulan.
- Integrasi pemesanan kurir.
- Multi-drop-point dalam satu acara.
- Role dan permission yang lebih granular.
- Ekspor laporan CSV/PDF.
- Konfigurasi aturan scanner per organisasi/acara.
- Rekomendasi perbaikan atau daur ulang untuk item yang ditolak.

Seluruh kapabilitas pada bagian 8.1, 8.2, dan 8.3—termasuk create/publish event, App Clip booking, scanner, status donor di aplikasi penuh, QR reception, dan recap—merupakan satu paket MVP pertama. Phase pada rollout plan menunjukkan urutan implementasi teknis, bukan pemotongan scope MVP.

## 9. User Journeys

### 9.1 Pengelola membuat dan menerbitkan acara

1. Pengelola masuk ke aplikasi utama.
2. Sistem memuat organisasi dan dashboard.
3. Organizer memilih “Buat Acara”.
4. Organizer mengisi informasi dasar dan banner.
5. Organizer menentukan tanggal, lokasi, hari, dan jam operasional.
6. Organizer menentukan kriteria penerimaan serta kapasitas.
7. Sistem memvalidasi kelengkapan dan menampilkan ringkasan.
8. Organizer menyimpan sebagai Draf atau menerbitkan acara.
9. Sistem menghasilkan event ID, App Clip invocation URL, dan QR promosi.
10. Acara muncul pada section yang sesuai dan dapat dibagikan.

### 9.2 Donor membuat booking

1. Donor mengetuk App Clip link/QR/NFC milik acara.
2. App Clip memvalidasi invocation dan mengambil detail acara.
3. Donor meninjau acara, kriteria, kapasitas tersisa, lokasi, dan tenggat.
4. Donor memilih “Send My Clothes”.
5. Donor mengisi nama, nomor telepon Indonesia, estimasi berat pakaian yang didonasikan, serta menyetujui syarat dan ketentuan.
6. Donor memotret satu helai pakaian atau memilih foto.
7. Scanner mengevaluasi jumlah pakaian serta keberadaan kancing, resleting, saku, logam, dan ornamen; scanner tidak menentukan material/kategori acara.
8. Jika item belum lolos pemeriksaan awal, donor dapat memindai ulang item yang sama berkali-kali, kembali ke daftar untuk memotret pakaian lain, atau menghapus item tersebut.
9. Donor dapat menghapus item berstatus lolos maupun belum lolos. Tombol lanjut hanya aktif jika minimal satu item tersisa dan seluruh item yang tersisa telah lolos pemeriksaan awal.
10. Donor memilih salah satu dari tiga metode pengiriman yang selalu tersedia.
11. Sistem menampilkan ringkasan final dan meminta konfirmasi.
12. Backend memastikan acara belum mencapai kapasitas maksimum lalu membuat booking sampai waktu yang lebih awal antara 12 jam dan end datetime event tanpa mengubah berat terpakai.
13. App Clip menampilkan nomor booking, QR, label gambar dengan field yang ditetapkan, waktu kedaluwarsa aktual, dan instruksi pengiriman manual.

### 9.3 Donor melihat status melalui aplikasi penuh

1. Donor membuka aplikasi penuh .kumpul setelah menyelesaikan booking melalui App Clip.
2. Donor memilih mode Donor dan memasukkan booking ID serta nomor telepon yang sama dengan booking.
3. Aplikasi mengambil booking donor dari backend.
4. Donor melihat status terbaru selama data booking masih berada dalam masa retensi.

### 9.4 Pengelola menerima paket

1. Pengelola membuka scanner QR di aplikasi utama.
2. Sistem memvalidasi QR dan menampilkan booking terkait.
3. Pengelola mencocokkan identitas minimum, acara, dan jumlah item.
4. Pengelola mencatat berat aktual dan memilih kondisi Baik/Rusak/Basah/Kotor/Berjamur. Jika menolak booking, Pengelola boleh memilih preset alasan dan boleh menambahkan teks; alasan tidak wajib.
5. Sistem mengubah status booking dan memperbarui progres acara.
6. Dashboard dan rekap menampilkan data terbaru.

## 10. Functional Requirements

Prioritas menggunakan **P0** untuk MVP wajib, **P1** untuk penting setelah fondasi, dan **P2** untuk peningkatan.

### 10.1 Authentication dan workspace Pengelola

- **FR-AUTH-01 (P0):** Pengelola harus masuk sebelum mengakses data administrasi.
- **FR-AUTH-02 (P0):** Semua query dan mutation Pengelola harus dibatasi pada workspace/tenant miliknya.
- **FR-AUTH-03 (P0):** Donor App Clip tidak diwajibkan membuat akun penuh.
- **FR-AUTH-04 (P0):** Session Pengelola harus bertahan secara aman dan dapat dicabut.
- **FR-AUTH-05 (P0):** Satu akun Pengelola memiliki tepat satu workspace organisasi teknis dan kewenangan pengelolaan acara, penerimaan paket, rekap, ekspor, serta penghapusan data donor.
- **FR-AUTH-06 (P0):** Data, mutation, dashboard, booking, dan rekap satu workspace tidak boleh dapat diakses Pengelola workspace lain.
- **FR-AUTH-07 (P0):** Pengelola dapat masuk menggunakan Sign in with Apple atau email/password, dan kedua metode harus merujuk pada akun/workspace yang sama tanpa membuat tenant/data duplikat.
- **FR-AUTH-08 (P0):** Donor yang memakai aplikasi penuh membuktikan kepemilikan booking menggunakan booking ID dan nomor telepon yang dinormalisasi; donor hanya dapat mengakses booking yang kedua nilainya cocok.
- **FR-AUTH-09 (P0):** Aplikasi penuh yang sama menyediakan mode Donor dan Pengelola. Mode Pengelola memakai Sign in with Apple atau email/password, sedangkan mode Donor memakai booking ID dan nomor telepon.
- **FR-AUTH-10 (P0):** Pengelola dapat mendaftar sendiri dan akun/workspace langsung aktif. Tidak ada undangan, membership tambahan, atau pengelolaan akun Pengelola lain pada MVP.
- **FR-AUTH-11 (P0):** Percobaan akses mode Donor harus diberi rate limit dan error yang tidak membocorkan apakah booking ID atau nomor telepon tertentu terdaftar.

### 10.2 Event management

- **FR-EVT-01 (P0):** Event memiliki ID stabil, organisasi, nama, deskripsi, banner, status, tanggal mulai/selesai, timezone, lokasi, koordinat, jadwal operasional, kriteria, kapasitas, dan timestamps.
- **FR-EVT-02 (P0):** Nama, banner, tanggal valid, lokasi, minimal satu hari operasional, jam valid, minimal satu kriteria, dan kapasitas positif wajib sebelum acara dapat diterbitkan. Deskripsi bersifat opsional.
- **FR-EVT-03 (P0):** Banner boleh belum lengkap saat berstatus Draf, tetapi wajib tersedia sebelum aksi menerbitkan. Deskripsi boleh tetap kosong baik pada Draf maupun setelah diterbitkan.
- **FR-EVT-04 (P0):** Pengelola dapat menyimpan acara sebagai Draf tanpa kehilangan field yang telah diisi.
- **FR-EVT-05 (P0):** Pengelola dapat mengedit seluruh field event selama status Draf, Akan Datang, atau Berlangsung. Event Selesai, Ditutup, dan Dibatalkan bersifat read-only serta tidak dapat dibuka kembali.
- **FR-EVT-06 (P0):** Vocabulary status acara adalah Draf, Akan Datang, Berlangsung, Selesai, Ditutup, dan Dibatalkan; seluruh label yang terlihat pengguna menggunakan Bahasa Indonesia. Terbit adalah aksi dan timestamp, bukan status.
- **FR-EVT-07 (P0):** Sistem mencegah end date sebelum start date dan end time sebelum start time.
- **FR-EVT-08 (P0):** Pencarian lokasi menggunakan MapKit dan menyimpan nama, alamat terformat, latitude, serta longitude.
- **FR-EVT-09 (P0):** Pengelola dapat memilih lokasi dari hasil pencarian atau titik peta.
- **FR-EVT-10 (P0):** Setiap acara yang telah diterbitkan memiliki invocation URL yang mengandung identifier opaque atau slug aman.
- **FR-EVT-11 (P0):** Pengelola dapat menutup atau membatalkan event tanpa wajib mengisi alasan. Kedua tindakan otomatis membatalkan seluruh booking Menunggu.
- **FR-EVT-12 (P1):** Pengelola dapat melihat dan membagikan QR promosi event.
- **FR-EVT-13 (P0):** Setiap acara memiliki tepat satu drop point dan satu jadwal operasional, yang dapat memuat beberapa hari aktif tetapi satu rentang jam operasional bersama.
- **FR-EVT-14 (P0):** Setelah acara diterbitkan, sistem menentukan Akan Datang atau Berlangsung dari waktu acara dan otomatis mengubahnya menjadi Selesai setelah end datetime pada timezone acara.
- **FR-EVT-15 (P0):** Timezone acara ditentukan otomatis dari koordinat drop point di Indonesia dan disimpan eksplisit agar jadwal tetap benar untuk WIB, WITA, atau WIT.
- **FR-EVT-16 (P0):** Satu Pengelola dapat memiliki maksimal lima event aktif pada saat bersamaan; hanya Akan Datang dan Berlangsung yang dihitung aktif.
- **FR-EVT-17 (P0):** Semua hari operasional yang dipilih pada satu event memakai satu jam buka dan satu jam tutup yang sama; jam berbeda per hari tidak didukung pada MVP.
- **FR-EVT-18 (P0):** Pengelola dapat mengedit seluruh field event setelah diterbitkan selama event belum terminal. Booking aktif mempertahankan snapshot nama event, lokasi, jadwal, kriteria, data penerima, dan instruksi pada saat booking dibuat; perubahan hanya berlaku untuk booking baru.
- **FR-EVT-19 (P0):** Pengelola dapat mengubah event menjadi Ditutup untuk menghentikannya lebih awal. Seluruh booking Menunggu otomatis Dibatalkan. Event berubah menjadi Selesai otomatis pada end datetime dan langsung tertutup secara operasional tanpa transisi lanjutan ke Ditutup.
- **FR-EVT-20 (P0):** Kapasitas event tidak dapat diturunkan di bawah total berat aktual yang sudah diterima.

### 10.3 Dashboard Pengelola

- **FR-DASH-01 (P0):** Empty state hanya muncul bila organisasi benar-benar belum memiliki event yang relevan.
- **FR-DASH-02 (P0):** Dashboard menampilkan acara Berlangsung dan Akan Datang dari backend.
- **FR-DASH-03 (P0):** Setiap card event membuka detail event.
- **FR-DASH-04 (P0):** Search memfilter event atau donasi sesuai scope yang disepakati.
- **FR-DASH-05 (P0):** Rekap ringkas menunjukkan total berat terverifikasi, total donor/booking yang valid, event selesai, dan rata-rata per donasi.
- **FR-DASH-06 (P0):** Kapasitas kilogram adalah batas keras; backend tidak boleh menerima transaksi penerimaan yang membuat total berat terverifikasi melampaui kapasitas dan tidak boleh memecah penerimaan booking menjadi sebagian.
- **FR-DASH-07 (P1):** “Lihat semua” membuka daftar lengkap dengan filter status dan rentang tanggal.
- **FR-DASH-08 (P1):** Dashboard melakukan refresh setelah event atau donasi berubah.
- **FR-DASH-09 (P2):** Voice search hanya disediakan jika ada use case dan permission yang disetujui.
- **FR-DASH-10 (P0):** Rekap menghitung donor unik satu kali per event, menggunakan identitas donor yang telah dinormalisasi sesuai kebijakan privasi.
- **FR-DASH-11 (P0):** Pengelola dapat mengekspor rekap terfilter menjadi file CSV yang dapat dibagikan melalui share sheet. CSV boleh memuat nama dan nomor telepon donor bersama booking ID, nama event, waktu booking, status, estimasi berat, berat aktual, kondisi, alasan penolakan, dan metode pengiriman.

### 10.4 App Clip event discovery

- **FR-CLIP-01 (P0):** App Clip memproses invocation URL saat cold start dan saat aplikasi sudah aktif.
- **FR-CLIP-02 (P0):** Event ID dari URL tidak boleh dipercaya sebelum divalidasi oleh backend.
- **FR-CLIP-03 (P0):** Kondisi memuat, tautan tidak valid, acara tidak tersedia, offline, Dibatalkan, Selesai, dan kapasitas penuh harus memiliki UI eksplisit dalam Bahasa Indonesia.
- **FR-CLIP-04 (P0):** Detail event yang ditampilkan harus berasal dari backend, termasuk banner, identitas Pengelola, kapasitas, countdown, lokasi, kriteria, dan metode pengiriman.
- **FR-CLIP-05 (P0):** CTA donasi dinonaktifkan atau diganti dengan alasan yang jelas bila event tidak menerima booking baru.
- **FR-CLIP-06 (P0):** Share menghasilkan tautan yang membuka event yang sama.
- **FR-CLIP-07 (P0):** Lokasi dapat dibuka di Apple Maps.
- **FR-CLIP-08 (P1):** App Clip dapat menampilkan fallback ringan ketika sebagian media gagal dimuat.

### 10.5 Data donor dan consent

- **FR-DONOR-01 (P0):** Donor wajib memberikan nama, nomor telepon Indonesia, estimasi berat pakaian yang didonasikan, dan status pemeriksaan pakaian; tidak ada mode donasi anonim.
- **FR-DONOR-02 (P0):** Nama harus di-trim dan divalidasi panjang minimumnya.
- **FR-DONOR-03 (P0):** Nomor telepon harus dinormalisasi dan divalidasi untuk Indonesia.
- **FR-DONOR-04 (P0):** Donor wajib mencentang persetujuan syarat dan ketentuan sebelum melanjutkan; checkbox harus memiliki tautan ke naskah legal yang berlaku.
- **FR-DONOR-05 (P0):** Error harus spesifik, dapat diperbaiki, dan tidak menghapus input.
- **FR-DONOR-06 (P1):** Data donor yang pernah diketik dapat dipulihkan selama sesi App Clip yang sama bila navigasi mundur.
- **FR-DONOR-07 (P0):** Pembuat aplikasi bertanggung jawab menulis dan menyetujui naskah syarat, ketentuan, dan kebijakan privasi sebelum production release.
- **FR-DONOR-08 (P0):** Berat yang disampaikan donor tidak mengonsumsi kapasitas; hanya berat aktual hasil timbang Pengelola yang menjadi source of truth kapasitas.
- **FR-DONOR-09 (P0):** Data pribadi donor dan booking disimpan sampai satu bulan setelah event menjadi Selesai, Ditutup, atau Dibatalkan, lalu dihapus atau dianonimkan; agregat non-PII dapat dipertahankan untuk pelaporan.
- **FR-DONOR-10 (P0):** Setiap Pengelola dapat menghapus data donor. Produk tidak mewajibkan Pengelola mengisi alasan dan tidak mewajibkan pencatatan waktu atau identitas penghapus khusus untuk aksi ini.

### 10.6 Pemindaian pakaian

- **FR-SCAN-01 (P0):** Donor dapat mengambil foto atau memilih foto dari galeri.
- **FR-SCAN-02 (P0):** Permintaan permission harus muncul hanya saat fitur terkait digunakan dan memiliki fallback.
- **FR-SCAN-03 (P0):** Kamera menyediakan framing guide, shutter, pilihan galeri, kamera depan/belakang, dan torch saat tersedia.
- **FR-SCAN-04 (P0):** Setiap foto hanya boleh mewakili satu helai pakaian.
- **FR-SCAN-05 (P0):** Scanner hanya mengevaluasi jumlah pakaian serta aksesori kancing, resleting, saku, logam, dan ornamen; scanner tidak menilai material atau kecocokan dengan kategori event.
- **FR-SCAN-06 (P0):** Outcome “needs processing” menampilkan daftar aksesori yang harus dilepas.
- **FR-SCAN-07 (P0):** Donor dapat memindai ulang pakaian yang sama berkali-kali sampai berstatus Lolos Pemeriksaan Awal tanpa membuat item duplikat; hasil terbaru menggantikan hasil sebelumnya dan hasil lama tidak disimpan.
- **FR-SCAN-08 (P0):** Analisis dilakukan sepenuhnya on-device. Foto tidak boleh diunggah ke backend, analytics, log, atau storage persisten.
- **FR-SCAN-09 (P0):** Salinan foto yang digunakan .kumpul hanya hidup sementara di memori selama satu flow App Clip dan harus hilang ketika sesi/flow ditutup; backend hanya menerima status pemeriksaan dan metadata nonfoto yang disetujui. Aplikasi tidak menghapus foto asli yang dipilih dari galeri milik pengguna.
- **FR-SCAN-10 (P0):** Model produksi harus mampu mendeteksi lima kelompok aksesori yang ditetapkan pada foto ponsel. Pemilik produk sengaja tidak menetapkan ambang akurasi, precision/recall, atau false rejection numerik untuk MVP; keputusan ini tidak menjadi pertanyaan terbuka dan kualitas ditingkatkan dari hasil pilot.
- **FR-SCAN-11 (P1):** Sistem dapat mengubah model/threshold secara versioned tanpa mematahkan booking lama.
- **FR-SCAN-12 (P0):** Hasil scanner selalu merupakan rekomendasi. UI harus menyebutkannya dan keputusan akhir berada pada Pengelola saat menerima paket.
- **FR-SCAN-13 (P0):** Kancing, resleting, saku, logam, dan ornamen yang terdeteksi selalu ditandai untuk dilepas, tanpa variasi aturan per event/material pada MVP.
- **FR-SCAN-14 (P0):** Hanya status aktif/final setiap pakaian yang disimpan pada booking tanpa fotonya. Hasil percobaan scan sebelumnya yang telah digantikan tidak disimpan.
- **FR-SCAN-15 (P0):** Item yang belum lolos tidak mengunci seluruh sesi: donor dapat kembali ke daftar, memindai pakaian lain, lalu kembali ke item sebelumnya.
- **FR-SCAN-16 (P0):** Pemindaian dan analisis pakaian tetap dapat berjalan tanpa internet selama event context sudah tersedia pada sesi atau cache lokal; hasil scan tidak sama dengan booking server-side.

### 10.7 Review item

- **FR-ITEM-01 (P0):** Donor melihat semua item yang telah ditambahkan dan statusnya.
- **FR-ITEM-02 (P0):** Donor dapat membuka preview foto.
- **FR-ITEM-03 (P0):** Donor dapat menghapus item sebelum konfirmasi booking, baik item tersebut berstatus lolos maupun belum lolos pemeriksaan awal.
- **FR-ITEM-04 (P0):** Minimal satu item harus tersisa dan seluruh item yang tersisa wajib berstatus Lolos Pemeriksaan Awal sebelum donor dapat melanjutkan ke pemilihan metode pengiriman.
- **FR-ITEM-05 (P0):** Status aktif terakhir item yang belum lolos dapat dicatat sebagai aggregate analytics tanpa foto/PII selama item tidak dihapus. Riwayat hasil yang digantikan tidak dipertahankan. Hanya status final item yang tersisa saat booking dibuat yang terhubung ke booking.
- **FR-ITEM-06 (P1):** Sistem menampilkan jumlah item serta dampaknya pada estimasi kapasitas jika estimasi berat tersedia.
- **FR-ITEM-07 (P0):** Ketika donor menghapus item, seluruh status dan riwayat scan nonfoto untuk item tersebut ikut dihapus dan tidak dikirim untuk analytics/audit.

### 10.8 Metode pengiriman

- **FR-SHIP-01 (P0):** Setiap event selalu menyediakan ketiga metode pengiriman MVP: antar langsung, ojek online, dan ekspedisi. Pengelola tidak dapat menonaktifkan salah satunya pada MVP.
- **FR-SHIP-02 (P0):** Ketiga metode hanya menyediakan instruksi manual dan tidak mengintegrasikan pemesanan, tarif, atau tracking API kurir.
- **FR-SHIP-03 (P0):** Donor wajib memilih satu metode sebelum lanjut.
- **FR-SHIP-04 (P0):** Pilihan tersimpan pada draf booking dan ringkasan final.
- **FR-SHIP-05 (P0):** Instruksi, nama penerima, nomor telepon penerima, alamat, dan deadline berasal dari event lalu disalin menjadi snapshot booking, bukan konstanta aplikasi atau default workspace.
- **FR-SHIP-06 (P1):** Perubahan metode setelah booking mengikuti aturan status dan tenggat.

### 10.9 Booking, kapasitas, dan label

- **FR-BOOK-01 (P0):** Backend membuat booking dengan ID internal dan public token yang tidak mudah ditebak.
- **FR-BOOK-02 (P0):** Booking menghubungkan event, donor, items, metode pengiriman, status, waktu kedaluwarsa, dan model scan version.
- **FR-BOOK-03 (P0):** Pembuatan booking harus idempotent agar retry jaringan tidak membuat duplikat.
- **FR-BOOK-04 (P0):** Booking tidak mengonsumsi kapasitas. Kapasitas hanya bertambah ketika paket diterima dan berat aktual dicatat oleh Pengelola.
- **FR-BOOK-05 (P0):** Booking yang berhasil menampilkan nomor ID yang dapat dibaca manusia dan QR token untuk mesin.
- **FR-BOOK-06 (P0):** QR tidak boleh berisi data pribadi donor dalam plaintext.
- **FR-BOOK-07 (P0):** Label wajib berupa gambar yang dapat disimpan ke galeri dan memuat logo .kumpul, nama event, booking ID, QR, nama donor, serta nama, nomor telepon, dan alamat penerima dari snapshot booking. Label tidak memuat barcode lain, tanggal kedaluwarsa, atau metode pengiriman.
- **FR-BOOK-08 (P0):** Donor dapat membagikan atau menyimpan label melalui mekanisme sistem yang tersedia untuk App Clip.
- **FR-BOOK-09 (P0):** Jika rendering atau penulisan label gagal, booking tetap dapat ditemukan kembali selama sesi dan tersedia tindakan retry.
- **FR-BOOK-10 (P0):** Success screen menampilkan waktu kedaluwarsa aktual—maksimal 12 jam atau end datetime event—dan instruksi manual sesuai metode pengiriman.
- **FR-BOOK-11 (P0):** Backend menolak booking baru ketika berat terverifikasi acara telah mencapai kapasitas maksimum.
- **FR-BOOK-12 (P0):** Sistem otomatis mengubah booking yang belum diterima menjadi Kedaluwarsa pada waktu yang lebih awal antara 12 jam setelah booking dibuat dan end datetime event, tanpa mengubah kapasitas karena booking belum dihitung sebagai berat diterima.
- **FR-BOOK-13 (P0):** Nama, nomor telepon, alamat penerima, nama event, lokasi, jadwal, kriteria, dan instruksi disalin dari event menjadi snapshot immutable saat booking dibuat. Edit event berikutnya tidak mengubah booking atau label yang sudah aktif.
- **FR-BOOK-14 (P0):** Ketika penerimaan paket membuat kapasitas event tepat mencapai batas maksimum, backend otomatis membatalkan seluruh booking aktif lain yang belum diterima dan menolak booking baru berikutnya.
- **FR-BOOK-15 (P0):** Satu booking merupakan unit penerimaan atomik: seluruh booking diterima atau ditolak; penerimaan sebagian tidak didukung.
- **FR-BOOK-16 (P0):** Pembuatan booking wajib online dan tidak dapat diantrekan sebagai transaksi offline karena eligibility event serta kapasitas harus dikonfirmasi server pada saat booking dibuat.

### 10.10 Penerimaan dan rekap

- **FR-OPS-01 (P0):** Tombol QR pada aplikasi utama hanya membuka scanner booking donor; fungsi membagikan event tersedia melalui aksi terpisah pada detail event.
- **FR-OPS-02 (P0):** QR yang valid menampilkan booking dan acara; token tidak valid, kedaluwarsa, dibatalkan, atau sudah diterima ditangani secara eksplisit dalam Bahasa Indonesia.
- **FR-OPS-03 (P0):** Saat paket tiba, Pengelola mencatat berat aktual dan memilih kondisi Baik, Rusak, Basah, Kotor, atau Berjamur. Jika booking ditolak, alasan bersifat opsional dan dapat dipilih dari Aksesori Belum Dilepas, Tidak Sesuai Kriteria, Rusak, Basah, Kotor, Berjamur, Melebihi Kapasitas, atau Lainnya. Teks tambahan untuk Lainnya juga opsional.
- **FR-OPS-04 (P0):** Status booking yang terlihat donor adalah Menunggu, Diterima, Ditolak, Kedaluwarsa, dan Dibatalkan. Status Dalam Pengiriman tidak digunakan pada MVP.
- **FR-OPS-05 (P0):** Progress kapasitas dan rekap memakai berat terverifikasi, bukan hanya estimasi donor.
- **FR-OPS-06 (P0):** Perubahan status sensitif tercatat dengan actor dan timestamp.
- **FR-OPS-07 (P1):** Rekap dapat difilter per event dan rentang waktu.
- **FR-OPS-08 (P1):** Donasi terbaru menampilkan data yang diizinkan kebijakan privasi.
- **FR-OPS-09 (P0):** Setelah kapasitas mencapai batas maksimum, seluruh booking yang belum diterima otomatis Dibatalkan dan event tidak menerima booking baru.
- **FR-OPS-10 (P0):** Pengelola tidak dapat menerima sebagian isi booking; bila paket tidak dapat diterima secara utuh, booking ditolak dan alasan tetap opsional.
- **FR-OPS-11 (P0):** Donor unik pada rekap dihitung satu kali per event, bukan per booking, dengan pencocokan berdasarkan nomor telepon Indonesia yang telah dinormalisasi kecuali identity policy final menentukan identifier yang lebih kuat.
- **FR-OPS-12 (P0):** Ekspor CSV mengikuti filter event/periode yang sedang aktif dan memuat nama/nomor telepon donor, booking ID, nama event, waktu booking, status, estimasi berat, berat aktual, kondisi, alasan penolakan, serta metode pengiriman. Tidak ada PII lain di luar schema tersebut.
- **FR-OPS-13 (P0):** Pemindaian QR dan keputusan menerima/menolak paket wajib online, tidak boleh diantrekan offline, dan hanya dianggap berhasil setelah backend mengonfirmasi transaksi kapasitas.

### 10.11 Status donor di aplikasi penuh

- **FR-STATUS-01 (P0):** Setelah App Clip ditutup, donor dapat membuka aplikasi penuh .kumpul untuk melihat status booking miliknya.
- **FR-STATUS-02 (P0):** Status yang ditampilkan berasal dari backend dan menggunakan vocabulary Menunggu, Diterima, Ditolak, Kedaluwarsa, dan Dibatalkan. Status Dalam Pengiriman tidak digunakan pada MVP.
- **FR-STATUS-03 (P0):** Aplikasi penuh tidak boleh menampilkan booking milik nomor telepon atau donor lain.
- **FR-STATUS-04 (P0):** Riwayat yang memuat data pribadi hanya tersedia selama masa retensi satu bulan.

### 10.12 Offline mode

- **FR-OFFLINE-01 (P0):** Pengelola yang telah memiliki sesi sah dapat melihat event yang sebelumnya tersimpan ketika offline, dengan indikator bahwa data mungkin tidak terbaru.
- **FR-OFFLINE-02 (P0):** Pengelola dapat membuat dan mengedit Draf event ketika offline; perubahan disimpan lokal dan disinkronkan setelah koneksi kembali.
- **FR-OFFLINE-03 (P0):** Publish event memerlukan koneksi dan konfirmasi backend.
- **FR-OFFLINE-04 (P0):** Donor dapat melakukan pemindaian pakaian secara on-device ketika offline jika event context sudah tersedia pada sesi/cache lokal.
- **FR-OFFLINE-05 (P0):** Booking donor serta pemindaian QR dan penerimaan/penolakan paket oleh Pengelola wajib online dan tidak masuk antrean transaksi offline.
- **FR-OFFLINE-06 (P0):** Konflik Draf menggunakan kebijakan last-write-wins: perubahan dengan waktu modifikasi paling baru otomatis menjadi versi server. Timestamp harus berasal dari mekanisme yang tahan terhadap perbedaan jam perangkat.

## 11. User Stories

1. Sebagai organizer, saya ingin login dengan aman agar data acara organisasi tidak dapat diakses pihak lain.
2. Sebagai organizer, saya ingin melihat empty state yang jelas agar tahu langkah pertama yang harus dilakukan.
3. Sebagai organizer, saya ingin membuat acara baru agar dapat mulai mengumpulkan pakaian.
4. Sebagai organizer, saya ingin menyimpan acara sebagai Draf agar pekerjaan yang belum lengkap tidak hilang.
5. Sebagai organizer, saya ingin menambahkan banner agar acara mudah dikenali donor.
6. Sebagai organizer, saya ingin menentukan nama dan deskripsi agar tujuan acara jelas.
7. Sebagai organizer, saya ingin menentukan tanggal mulai dan selesai agar donor mengetahui periode acara.
8. Sebagai organizer, saya ingin memilih titik di peta agar donor mendapat lokasi yang tepat.
9. Sebagai organizer, saya ingin mencari alamat agar tidak perlu menentukan koordinat manual.
10. Sebagai organizer, saya ingin menentukan hari dan jam operasional agar donor tidak datang di luar waktu penerimaan.
11. Sebagai organizer, saya ingin memilih kriteria pakaian agar hanya jenis yang dapat diproses yang dikirim.
12. Sebagai organizer, saya ingin menentukan kapasitas agar pengumpulan tidak melampaui kemampuan fasilitas.
13. Sebagai organizer, saya ingin meninjau data sebelum publish agar kesalahan tidak tersebar kepada donor.
14. Sebagai organizer, saya ingin membagikan link dan QR acara agar donor langsung membuka App Clip untuk acara yang benar.
15. Sebagai organizer, saya ingin melihat acara Berlangsung agar dapat memantau operasi hari ini.
16. Sebagai organizer, saya ingin melihat acara Akan Datang agar dapat menyiapkan kebutuhan berikutnya.
17. Sebagai organizer, saya ingin melihat acara Draf, Selesai, Ditutup, dan Dibatalkan agar seluruh siklus acara dapat dikelola.
18. Sebagai organizer, saya ingin mencari event agar daftar besar tetap mudah digunakan.
19. Sebagai organizer, saya ingin membuka detail event agar dapat melihat progres dan konfigurasi lengkap.
20. Sebagai organizer, saya ingin melihat kapasitas terpakai agar dapat mengambil tindakan sebelum penuh.
21. Sebagai organizer, saya ingin memindai QR paket agar booking dapat ditemukan tanpa mengetik kode.
22. Sebagai organizer, saya ingin mengetahui bila QR tidak valid atau sudah dipakai agar paket tidak tercatat ganda.
23. Sebagai organizer, saya ingin mencatat berat aktual agar rekap menggambarkan dampak nyata.
24. Sebagai organizer, saya ingin mencatat item yang ditolak agar data penerimaan dapat diaudit.
25. Sebagai organizer, saya ingin melihat total berat, total donor, event selesai, dan rata-rata agar dapat menilai hasil program.
26. Sebagai organizer, saya ingin melihat donasi terbaru agar dapat memantau aktivitas operasional.
27. Sebagai organizer, saya ingin memfilter rekap per event/periode agar laporan dapat digunakan untuk evaluasi.
28. Sebagai donor, saya ingin membuka pengalaman donasi tanpa instalasi agar dapat mulai dengan cepat.
29. Sebagai donor, saya ingin langsung melihat acara yang saya scan agar tidak memilih event yang salah.
30. Sebagai donor, saya ingin melihat organizer, lokasi, periode, dan progres agar yakin acara masih relevan.
31. Sebagai donor, saya ingin membuka lokasi di Maps agar dapat merencanakan pengiriman langsung.
32. Sebagai donor, saya ingin membagikan event agar orang lain dapat ikut berdonasi.
33. Sebagai donor, saya ingin mengetahui acara sudah penuh atau selesai sebelum mengisi form agar waktu saya tidak terbuang.
34. Sebagai donor, saya ingin memahami kriteria pakaian agar tidak mengirim item yang tidak dapat diproses.
35. Sebagai donor, saya ingin mengisi data kontak minimum agar organizer dapat menghubungi saya bila diperlukan.
36. Sebagai donor, saya ingin melihat error validasi yang jelas agar dapat memperbaiki input.
37. Sebagai donor, saya ingin menutup keyboard nomor telepon dengan mudah agar dapat melanjutkan alur.
38. Sebagai donor, saya ingin memotret pakaian langsung agar tidak perlu menyiapkan foto sebelumnya.
39. Sebagai donor, saya ingin memilih foto dari galeri agar tetap dapat lanjut bila kamera tidak tersedia.
40. Sebagai donor, saya ingin melihat panduan framing agar hasil scan lebih akurat.
41. Sebagai donor, saya ingin menggunakan flash/torch agar foto tetap jelas di tempat gelap.
42. Sebagai donor, saya ingin mengganti kamera agar dapat menyesuaikan cara pengambilan foto.
43. Sebagai donor, saya ingin tahu bila terdapat lebih dari satu pakaian agar dapat mengulang dengan benar.
44. Sebagai donor, saya ingin tahu aksesori apa yang perlu dilepas agar pakaian dapat diterima.
45. Sebagai donor, saya ingin melihat apakah pakaian lolos agar yakin item masuk booking.
46. Sebagai donor, saya ingin menambah beberapa pakaian agar satu paket dapat berisi lebih dari satu item.
47. Sebagai donor, saya ingin membuka foto item agar dapat memastikan foto yang benar digunakan.
48. Sebagai donor, saya ingin menghapus item agar kesalahan tidak masuk booking.
49. Sebagai donor, saya ingin memilih antar langsung, ojek online, atau ekspedisi agar pengiriman sesuai kondisi saya.
50. Sebagai donor, saya ingin melihat instruksi spesifik tiap metode agar tahu tindakan berikutnya.
51. Sebagai donor, saya ingin meninjau ringkasan final agar dapat memperbaiki kesalahan sebelum konfirmasi.
52. Sebagai donor, saya ingin mendapat booking ID setelah konfirmasi agar memiliki bukti pendaftaran.
53. Sebagai donor, saya ingin mendapat QR yang dapat dipindai organizer agar paket dikenali dengan cepat.
54. Sebagai donor, saya ingin mengunduh atau membagikan label agar dapat mencetak dan menempelkannya pada paket.
55. Sebagai donor, saya ingin mengetahui deadline pengiriman agar booking tidak kedaluwarsa.
56. Sebagai donor, saya ingin retry setelah gangguan jaringan tanpa booking ganda agar alur tetap aman.
57. Sebagai donor yang menolak izin kamera, saya ingin memakai galeri agar tetap dapat berdonasi.
58. Sebagai donor dengan kebutuhan aksesibilitas, saya ingin kontrol memiliki label, ukuran sentuh, dan urutan fokus yang benar agar alur dapat digunakan.
59. Sebagai product owner, saya ingin mengetahui funnel dari invocation sampai paket diterima agar dapat menemukan titik drop-off pengguna.
60. Sebagai product owner, saya ingin mengetahui versi model dan false rejection agar scanner dapat ditingkatkan dengan aman.
61. Sebagai donor, saya ingin mencantumkan berat pakaian yang saya donasikan agar booking memiliki informasi awal sebelum penimbangan organizer.
62. Sebagai donor, saya ingin membaca dan menyetujui syarat dan ketentuan agar pemrosesan data serta aturan donasi transparan.
63. Sebagai donor, saya ingin foto pakaian hanya digunakan sementara di perangkat agar privasi saya terjaga.
64. Sebagai organizer, saya ingin melihat status pemeriksaan pakaian tanpa menyimpan fotonya agar dapat menyiapkan verifikasi penerimaan secara privacy-preserving.
65. Sebagai donor, saya ingin melihat waktu kedaluwarsa aktual, maksimal 12 jam atau saat event berakhir, agar mengetahui batas waktu pengiriman.
66. Sebagai donor, saya ingin nomor ID terlihat pada label agar booking dapat dikenali secara manual bila QR tidak dapat dipindai.
67. Sebagai donor, saya ingin memindai ulang pakaian yang sama beberapa kali agar dapat memperbaiki kondisi sampai lolos pemeriksaan awal.
68. Sebagai donor, saya ingin kembali dan memindai pakaian lain tanpa menghapus item yang belum lolos agar dapat menyelesaikan paket secara fleksibel.
69. Sebagai donor, saya ingin tombol lanjut hanya tersedia ketika semua item tersisa sudah lolos agar tidak mengirim booking yang belum siap.
70. Sebagai donor, saya ingin melihat status booking melalui aplikasi penuh setelah App Clip ditutup agar tetap dapat mengikuti donasi saya.
71. Sebagai organizer, saya ingin melihat event tersimpan dan mengedit Draf saat offline agar pekerjaan dapat berlanjut ketika koneksi buruk.
72. Sebagai organizer, saya ingin penerimaan paket diwajibkan online agar kapasitas dan status tidak berkonflik.
73. Sebagai organizer, saya ingin menghapus data donor agar permintaan penghapusan dapat dilayani.
74. Sebagai product owner, saya ingin total kilogram pakaian yang benar-benar diterima menjadi metrik utama agar dampak operasional dapat diukur.

## 12. Data Model Konseptual

### 12.1 Workspace Pengelola (tenant teknis)

- ID
- nama dan brand
- alamat/kontak default
- timezone
- konfigurasi kebijakan organisasi
- tepat satu akun Pengelola pada MVP
- status langsung aktif setelah self-registration

### 12.2 User Pengelola dan akses Donor

- User ID
- Sign in with Apple identity dan/atau email/password identity
- tepat satu workspace ID untuk akun Pengelola
- role Pengelola mencakup pengelolaan event, penerimaan paket, rekap/CSV, dan penghapusan data donor
- mode Donor tanpa workspace, diverifikasi dengan booking ID dan normalized phone
- status

### 12.3 Event

- ID dan public slug/token
- organization ID
- nama, deskripsi, banner
- lifecycle status berbahasa Indonesia
- start/end datetime dan timezone yang diturunkan otomatis dari koordinat
- satu location name, address, latitude, dan longitude
- satu operational schedule
- hari operasional terpilih dengan satu jam buka/tutup bersama
- accepted criteria
- tiga shipping methods tetap: antar langsung, ojek online, dan ekspedisi
- hard capacity kg
- received weight kg sebagai pemakaian kapasitas
- published/closed/cancelled timestamps
- maksimal lima event berstatus Akan Datang atau Berlangsung per workspace

### 12.4 Donation Booking

- ID internal dan public booking code
- event ID
- immutable booking-time snapshot: nama event, lokasi, jadwal, kriteria, data penerima, dan instruksi
- donor name dan normalized phone
- donor-declared estimated clothing weight
- selected shipping method
- status dan expiry
- expiry adalah nilai lebih awal antara 12 jam sejak booking dibuat dan end datetime event
- item count dan status pemeriksaan setiap pakaian
- actual received weight sebagai hasil timbangan Pengelola
- reception condition: Baik, Rusak, Basah, Kotor, atau Berjamur
- optional rejection reason preset dan optional additional text bila ditolak
- cancellation reason, termasuk event capacity reached
- created/confirmed/received timestamps
- consent version wajib
- personal-data retention deadline satu bulan setelah event menjadi Selesai, Ditutup, atau Dibatalkan

### 12.5 Clothing Item dan Scan Result

- Item ID
- booking ID
- recommendation/eligibility status
- accessory findings dan confidence
- multiple-garment probability
- scanner/model version
- keputusan donor/Pengelola
- hasil scan aktif/final saja; tidak ada riwayat percobaan yang digantikan
- deleted timestamp/state lokal; item beserta seluruh riwayat scan dihapus ketika donor menghapusnya
- tanpa photo reference; foto bersifat ephemeral dan tidak persisten

### 12.6 Audit Event

- actor ID/type
- entity ID/type
- action
- before/after summary yang aman
- timestamp
- retention deadline satu bulan sejak audit event dibuat
- penghapusan data donor tidak diwajibkan menghasilkan audit event khusus

### 12.7 Recap Export

- organization dan event scope
- filter periode
- generated by Pengelola ID
- generated timestamp
- CSV schema version
- baris booking berisi nama dan nomor telepon donor, booking ID, nama event, waktu booking, status, estimasi berat, berat aktual, kondisi, alasan penolakan, dan metode pengiriman

## 13. State Machines

### 13.1 Event lifecycle yang dikonfirmasi

Vocabulary status: **Draf, Akan Datang, Berlangsung, Selesai, Ditutup,** dan **Dibatalkan**. Terbit adalah aksi, bukan status.

Alur normal:

`Draf --terbitkan--> Akan Datang → Berlangsung → Selesai`

- Setelah aksi terbitkan, sistem langsung menentukan Akan Datang atau Berlangsung berdasarkan waktu acara.
- Sistem otomatis mengubah acara menjadi Selesai setelah end datetime pada timezone acara.
- Pengelola dapat mengubah event menjadi Ditutup untuk menghentikannya sebelum end datetime; seluruh booking Menunggu otomatis Dibatalkan.
- Selesai adalah status terminal otomatis sekaligus tertutup secara operasional; event Selesai tidak perlu diubah lagi menjadi Ditutup.
- Draf, Akan Datang, atau Berlangsung dapat berpindah menjadi Dibatalkan tanpa alasan wajib; seluruh booking Menunggu otomatis Dibatalkan.
- Selesai, Ditutup, dan Dibatalkan bersifat read-only serta tidak dapat dibuka kembali.
- Perubahan tanggal tidak boleh diam-diam membuka kembali acara Selesai tanpa audit.

### 13.2 Booking lifecycle yang diusulkan

`draft-local → confirming → menunggu → diterima`

Cabang tambahan:

- `confirming → failed` dengan retry idempotent;
- `menunggu → kedaluwarsa` pada waktu lebih awal antara 12 jam setelah dibuat dan end datetime event;
- `menunggu → dibatalkan`;
- `menunggu → dibatalkan(capacityReached)` ketika event mencapai hard capacity;
- `menunggu → ditolak` bila seluruh booking ditolak saat penerimaan.

Penerimaan sebagian tidak diperbolehkan. Transition ke `diterima` atau `ditolak` berlaku pada seluruh booking secara atomik.

### 13.3 Clothing item lifecycle

`ditambahkan → memindai → lolos-pemeriksaan-awal`

Cabang dan pengulangan:

- `memindai → belum-lolos → memindai-ulang` dapat berulang pada item yang sama;
- dari `belum-lolos`, donor dapat kembali ke daftar dan memindai item lain;
- item pada status apa pun dapat berubah menjadi `dihapus` sebelum booking dikonfirmasi;
- flow tidak dapat maju ke metode pengiriman sampai minimal satu item tersisa dan seluruh item tersisa berstatus `lolos-pemeriksaan-awal`.

Status lolos pemeriksaan awal adalah rekomendasi scanner, bukan keputusan final penerimaan Pengelola.

## 14. Implementation Decisions

### 14.1 Keputusan yang sudah terlihat dan dipertahankan

- Produk memakai dua composition root: aplikasi penuh yang diperluas menjadi mode Pengelola dan Donor, serta App Clip untuk flow donor satu kali.
- UI native menggunakan SwiftUI; Observation dipakai pada flow/router baru, sedangkan sebagian scanner masih menggunakan ObservableObject/Combine.
- Analisis pakaian dijalankan on-device dengan Vision dan konfigurasi model yang dibundel.
- App Clip memerlukan target aplikasi preview terpisah untuk Xcode canvas.
- Spesifikasi proyek yang durable berada di XcodeGen, bukan project file yang dihasilkan.
- Build menggunakan Swift 6 strict concurrency dan deployment target iOS 26.
- Environment Local/Debug/Staging/Release dipisahkan, termasuk signing App Clip.
- App Clip dan aplikasi utama memakai associated domain yang sama untuk invocation.
- Label dirender sebagai image dan diekspor melalui share sheet, sesuai batasan App Clip.

### 14.2 Deep modules yang disarankan

1. **Event Domain** — mengenkapsulasi lifecycle, validasi publish, jadwal, kapasitas, dan eligibility event.
2. **Event Repository/API** — satu interface untuk mengambil, membuat, mengedit, menerbitkan, dan menutup event.
3. **App Clip Invocation Resolver** — mengubah URL menjadi event context yang tervalidasi dan menangani invalid/unavailable state.
4. **Donation Flow State Machine** — memiliki draft donor, items, shipping method, validasi tiap langkah, retry, dan final confirmation.
5. **Scanner Service** — interface kecil yang mengembalikan scan outcome versioned; implementasi Vision tetap tersembunyi dan dapat dites terpisah.
6. **Booking Service** — membuat booking secara idempotent dan mengelola status serta expiry.
7. **Capacity Policy** — menegakkan hard limit berdasarkan received weight serta menentukan perlakuan booking tertunda ketika kapasitas tercapai, tanpa reservasi kapasitas saat booking dibuat.
8. **Label/QR Service** — membuat public token aman, payload QR, dan representasi label tanpa mencampur data sensitif.
9. **Reception Service** — memvalidasi QR dan mencatat hasil penerimaan/audit.
10. **Recap Query** — menyajikan agregasi dashboard tanpa menghitung statistik langsung di view.
11. **Auth/Session** — mengisolasi credential, session lifecycle, relasi satu akun Pengelola ke satu workspace, dan authorization.
12. **Analytics Gateway** — event analytics bertipe yang tidak mengandung data pribadi.
13. **Offline Event Store/Draft Sync** — menyimpan cache event dan Draf Pengelola, mengantre perubahan Draf yang aman, serta memakai last-write-wins dengan server-authoritative timestamp saat koneksi kembali. Booking dan penerimaan tidak memakai antrean offline.
14. **Donor Status Service** — memvalidasi pasangan booking ID dan nomor telepon secara aman, lalu menyajikan status booking di mode Donor aplikasi penuh selama masa retensi.

### 14.3 Keputusan arsitektur produk yang telah dikonfirmasi

- Backend wajib menerapkan multi-tenancy sejak MVP: banyak workspace Pengelola dengan isolasi data tegas dan relasi satu akun Pengelola ke satu workspace pada MVP.
- Pengelola adalah satu-satunya role administrasi dan juga melakukan penerimaan paket; tidak ada operator, Admin, atau membership Pengelola tambahan.
- Seluruh status serta copy yang terlihat pengguna menggunakan Bahasa Indonesia.
- Event Domain memiliki satu drop point, satu jadwal operasional, dan transisi otomatis ke Selesai.
- Capacity Policy menggunakan berat paket yang telah diterima dan ditimbang sebagai satu-satunya pemakaian kapasitas.
- Kapasitas bersifat hard limit dan create booking ditolak setelah kapasitas tercapai.
- EcoTouch Indonesia harus diganti oleh fixture/demo data dan tidak boleh menjadi default production tenant.
- Daftar kategori MVP bersifat tetap dan hanya berfungsi sebagai kriteria yang dipilih Pengelola; scanner tidak mendeteksi material tersebut.
- Scanner hanya mendeteksi jumlah pakaian dan aksesori yang wajib dilepas, lalu menghasilkan rekomendasi untuk verifikasi akhir Pengelola. Tidak ada threshold kualitas numerik MVP; perbaikan mengikuti data pilot.
- Foto tidak pernah meninggalkan perangkat dan tidak boleh dipersistenkan; backend hanya menyimpan status/hasil pemeriksaan nonfoto.
- Donor tidak dapat anonim serta wajib mengisi nama, nomor telepon Indonesia, estimasi berat donasi, dan persetujuan syarat dan ketentuan.
- Booking otomatis kedaluwarsa pada waktu yang lebih awal antara 12 jam setelah dibuat dan end datetime event.
- Metode pengiriman MVP terbatas pada antar langsung, ojek online, dan ekspedisi sebagai instruksi manual; ketiganya selalu tersedia pada setiap event.
- Label berupa gambar yang dapat disimpan ke galeri dan hanya memuat logo .kumpul, nama event, booking ID, QR, nama donor, serta nama/telepon/alamat penerima dari event. Barcode tambahan tidak digunakan.
- Tombol QR aplikasi utama didedikasikan untuk pemindaian booking donor.
- Penerimaan booking bersifat atomik dan menyimpan berat, kondisi, serta alasan penolakan; penerimaan sebagian tidak ada pada MVP.
- Ketika hard capacity tercapai, booking aktif yang belum diterima otomatis dibatalkan.
- Donor unik dihitung sekali per event dan rekap dapat diekspor menjadi CSV.
- Pengelola login melalui Sign in with Apple atau email/password.
- Backend yang dipilih adalah Supabase Hosted dan schema/API baru akan dibangun mengikuti `docs/BACKEND_PRD.md`. Domain serta client contract tetap memakai repository boundary agar UI tidak bergantung langsung pada detail vendor.
- Offline mode mencakup event cache, create/edit Draf Pengelola, dan scan pakaian on-device. Publish, booking, serta penerimaan/penolakan paket wajib online.
- Setiap Pengelola dapat menghapus data donor tanpa kewajiban audit khusus untuk aksi penghapusan.
- Timezone acara diturunkan otomatis dari koordinat drop point.
- Semua lima capability utama masuk MVP pertama dan lima modul yang direkomendasikan wajib memiliki test fase pertama.
- Donor melihat status booking melalui mode Donor pada aplikasi penuh menggunakan booking ID dan nomor telepon; aplikasi yang sama juga menyediakan mode Pengelola.
- Data donor/booking disimpan satu bulan sejak event selesai atau ditutup. Audit log disimpan satu bulan sejak dibuat. Total berat aktual diterima menjadi north-star metric tanpa target numerik awal.
- Pengelola melakukan self-registration dan workspace langsung aktif. Tidak ada undangan atau penambahan Pengelola kedua pada satu workspace di MVP.
- Setiap Pengelola dapat memiliki maksimal lima event aktif, yaitu Akan Datang dan Berlangsung. Baseline load test platform adalah 1.000 booking per hari.
- Draf offline memakai last-write-wins, alasan penolakan bersifat opsional, dan item yang dihapus donor ikut menghapus seluruh riwayat scan item.
- Booking menyimpan snapshot data event saat dibuat. Kapasitas tidak dapat diturunkan di bawah berat aktual diterima. Event terminal read-only dan tidak dapat dibuka kembali.

### 14.4 Kontrak backend minimum

Backend perlu mendukung operasi konseptual berikut:

- resolve public event dari invocation token;
- self-register akun Pengelola beserta workspace yang langsung aktif;
- list/detail/create/update/publish/close event untuk Pengelola;
- upload dan delivery banner event;
- create booking idempotent;
- get booking by secure QR token;
- transition booking status;
- submit reception verification;
- fetch dashboard summary dan donation recap;
- export donation recap sebagai CSV;
- authenticate Pengelola dan enforce workspace authorization serta tenant isolation;
- memvalidasi booking ID + nomor telepon untuk mode Donor dengan rate limit dan mengambil status booking yang cocok;
- menghapus atau menganonimkan data donor melalui operasi Pengelola;
- menjalankan retention data donor/booking satu bulan setelah event Selesai/Ditutup/Dibatalkan, retention audit satu bulan sejak audit dibuat, dan mempertahankan agregat non-PII;
- menyinkronkan Draf offline dengan last-write-wins berdasarkan server-authoritative timestamp.

Semua mutation harus divalidasi server-side. Client tidak boleh menjadi sumber kebenaran untuk kapasitas, status, role, atau eligibility event.

Belum ada schema/API/backend yang telah diimplementasikan di luar repository ini. Supabase Hosted telah dipilih sebagai backend MVP; kontrak pada bagian ini dan `docs/BACKEND_PRD.md` menjadi baseline implementasinya.

## 15. Non-Functional Requirements

### 15.1 Performance

- App Clip harus menampilkan loading shell segera dan detail event secepat kondisi jaringan memungkinkan.
- Analisis foto harus berjalan di luar main thread dan UI tetap responsif.
- Ukuran App Clip harus dipantau pada archive/thinned build, bukan hanya ukuran source.
- Banner harus menggunakan ukuran dan caching yang sesuai koneksi seluler.
- Pilot awal menargetkan 50 akun Pengelola/workspace dan maksimal lima event Akan Datang/Berlangsung per Pengelola. Baseline load test adalah 1.000 booking per hari di seluruh platform.

### 15.2 Reliability

- Semua create/update harus aman terhadap retry.
- Draf donor lokal bertahan selama flow App Clip yang sedang aktif dan tidak rusak saat navigasi mundur.
- Error jaringan memiliki retry dan tidak menghapus input.
- Booking success hanya ditampilkan setelah server mengonfirmasi transaksi.
- Sesi lokal dan seluruh foto harus dibersihkan ketika flow/App Clip ditutup.
- Aplikasi utama dan App Clip menyediakan perilaku offline yang eksplisit. Event tersimpan dapat dibaca, Draf dapat dibuat/diedit, dan scanner pakaian dapat berjalan secara on-device saat offline.
- Publish event, create booking, pemindaian QR penerimaan, serta menerima/menolak paket membutuhkan server dan tidak boleh ditampilkan berhasil ketika offline.
- Draf offline harus disinkronkan setelah reconnect menggunakan last-write-wins berdasarkan timestamp yang ditetapkan server atau mekanisme waktu tepercaya. Batas cache lokal masih perlu ditentukan saat desain teknis.

### 15.3 Security dan privacy

- QR memakai token opaque, berumur terbatas atau dapat dicabut, dan tidak membawa nama/telepon plaintext.
- Endpoint Pengelola memerlukan autentikasi dan authorization per workspace.
- Sign in with Apple dan email/password harus terhubung ke user/membership yang sama dengan account-linking rule yang aman.
- Log dan analytics tidak boleh berisi nomor telepon, foto, address detail donor, atau token QR.
- Foto dianalisis on-device, tidak diunggah, tidak masuk storage persisten, dan dihapus bersama sesi App Clip.
- Backend hanya menyimpan status pemeriksaan pakaian dan temuan nonfoto yang diperlukan untuk operasional/analytics.
- Data pribadi donor dan booking dihapus atau dianonimkan satu bulan setelah event menjadi Selesai, Ditutup, atau Dibatalkan.
- Audit log operasional disimpan satu bulan sejak setiap audit event dibuat.
- Setiap Pengelola dapat menghapus data donor. Produk tidak mewajibkan audit event khusus yang mencatat alasan, waktu, atau identitas Pengelola untuk aksi penghapusan tersebut.
- Akses donor melalui aplikasi penuh harus memverifikasi kepemilikan booking tanpa mengekspos booking berdasarkan nama atau nomor telepon yang dapat ditebak.
- Pasangan booking ID dan nomor telepon harus dilindungi dengan booking ID berentropi cukup, rate limiting, monitoring penyalahgunaan, dan respons error generik.
- CSV mengandung PII donor dan hanya boleh diekspor oleh Pengelola untuk workspace miliknya melalui share sheet; file setelah diekspor berada di bawah tanggung jawab penerima/pengguna perangkat.
- Secret distribution tetap melalui environment/secret store; credential tidak masuk repository atau bundle aplikasi.

### 15.4 Accessibility

- Semua icon-only button memiliki accessibility label dan state.
- Dynamic Type tidak memotong informasi kritis.
- Kontras warna memenuhi WCAG yang relevan.
- Kontrol memiliki target sentuh minimum yang layak.
- Kamera memiliki instruksi nonvisual dan hasil scanner dapat dibaca VoiceOver.

### 15.5 Localization

- Rilis pertama hanya mendukung Indonesia dan seluruh user-facing copy menggunakan Bahasa Indonesia.
- Copy prototype yang masih campuran Indonesia dan Inggris harus dipindahkan ke localization catalog lalu diterjemahkan sebelum produksi.
- Format tanggal, berat, dan nomor telepon memakai locale Indonesia. Timezone acara harus tetap eksplisit karena Indonesia memiliki WIB, WITA, dan WIT.

### 15.6 Observability

- Error API, invocation failure, booking failure, label failure, scanner technical failure, dan status transition failure tercatat tanpa PII.
- Sistem dapat membedakan error pengguna, jaringan, model, dan server.

## 16. Analytics dan Success Metrics

### 16.1 Funnel donor

- App Clip invocation opened
- event detail loaded
- donation flow started
- personal info completed
- first scan started
- item accepted / needs processing / multiple garments / technical failure
- item rescanned
- item deleted, tanpa mempertahankan histori scan item yang dihapus
- item review completed
- donor-declared weight submitted
- shipping method selected
- booking confirmation attempted
- booking created
- label shared
- package received

### 16.2 Metrik utama

- **North-star metric:** total kilogram pakaian yang benar-benar diterima berdasarkan berat aktual hasil timbangan organizer.
- Invocation-to-booking conversion rate.
- Booking-to-received conversion rate.
- Median time dari invocation sampai booking confirmed.
- Scan retry rate dan technical failure rate.
- Persentase item needs-processing dan multiple-garments.
- False accept/false reject berdasarkan verifikasi Pengelola saat penerimaan.
- Booking expiry/cancellation rate.
- Kapasitas terverifikasi per event.
- Jumlah donor unik sesuai definisi privacy-safe.
- Crash-free sessions untuk aplikasi utama dan App Clip.

Belum ada target numerik awal untuk north-star metric. Metrik lain digunakan sebagai guardrail dan diagnosis funnel, bukan pengganti north-star metric.

## 17. Testing Decisions dan Acceptance Criteria

### 17.1 Prinsip test

- Test memverifikasi perilaku dan kontrak eksternal, bukan susunan view atau detail private implementation.
- Domain rule dan state machine dites tanpa network/UI.
- API diuji dengan contract fixtures dan idempotency cases.
- UI test hanya untuk critical journeys dan integrasi sistem yang tidak dapat dibuktikan pada unit level.
- Scanner diuji dengan dataset foto ponsel terlabel untuk memahami perilaku dan meningkatkan model setelah pilot; tidak ada ambang numerik yang menjadi release gate MVP.
- Test privasi memastikan tidak ada foto yang dikirim ke network, analytics, log, atau storage persisten dan foto dibersihkan saat sesi berakhir.

### 17.2 Modul yang wajib memiliki unit test

Sesuai keputusan pemilik produk, lima deep modules berikut wajib memiliki test pada fase pertama:

1. **Event Domain:** validasi, lifecycle, operational schedule, dan timezone dari lokasi.
2. **Donation Flow:** state machine, validasi langkah, phone normalization, consent, dan donor-declared weight.
3. **Scanner Policy:** result grouping, recommendation policy, status persistence, serta ephemeral photo lifecycle.
4. **Booking/Capacity:** lifecycle, expiry maksimal 12 jam/end datetime event, idempotency, hard limit, penerimaan atomik, dan pembatalan otomatis booking tertunda.
5. **Invocation Resolver:** parsing URL dan resolusi event yang tervalidasi.

QR/label, auth, offline sync, serta dashboard/rekap/CSV tetap harus memiliki coverage melalui unit, integration, atau UI test sesuai boundary masing-masing sebelum MVP dirilis.

### 17.3 Integration/contract test

- Resolve event dari invocation token.
- Create/update/publish event dengan authorization.
- Self-registration membuat akun Pengelola dan workspace yang langsung aktif dengan tenant isolation yang benar.
- Aktivasi event keenam ditolak setelah batas lima event Akan Datang/Berlangsung per Pengelola tercapai.
- Draf yang diubah offline pada dua perangkat disinkronkan dengan last-write-wins berdasarkan waktu tepercaya.
- Create booking dan retry dengan idempotency key yang sama.
- Booking otomatis kedaluwarsa pada waktu lebih awal antara 12 jam setelah dibuat dan end datetime event serta tidak memengaruhi kapasitas sebelum diterima.
- Race condition kapasitas ketika dua donor booking bersamaan.
- Ketika kapasitas tercapai, seluruh booking aktif yang belum diterima otomatis dibatalkan dalam transaksi yang konsisten.
- Penerimaan booking tidak dapat dilakukan sebagian dan paket yang melebihi sisa kapasitas ditolak secara utuh.
- QR validation dan transition ke received.
- Akses mode Donor hanya berhasil jika booking ID dan nomor telepon cocok serta rate limit diterapkan.
- Booking yang dibuat kurang dari 12 jam sebelum event berakhir kedaluwarsa tepat pada end datetime event.
- Event menjadi Selesai dan berhenti menerima donasi otomatis pada end datetime; Ditutup menghentikan event lebih awal.
- Menutup event lebih awal otomatis membatalkan seluruh booking Menunggu dan tidak memerlukan alasan.
- Edit event nonterminal tidak mengubah snapshot data event pada booking aktif.
- Kapasitas tidak dapat diturunkan di bawah total berat aktual yang sudah diterima.
- Event Selesai, Ditutup, atau Dibatalkan menolak mutation dan tidak dapat dibuka kembali.
- Penolakan dapat disimpan tanpa alasan, sedangkan preset dan teks Lainnya disimpan bila dipilih/diisi.
- Ekspor rekap CSV menghormati filter, tenant boundary, dan schema yang ditetapkan.
- Sign in with Apple dan email/password mengarah ke akun/workspace Pengelola yang sama.
- Sinkronisasi Draf offline tidak menyatakan perubahan telah tersimpan di server sebelum konfirmasi dan menerapkan last-write-wins berdasarkan waktu tepercaya saat reconnect.
- Booking dan penerimaan ditolak di client ketika offline serta tidak masuk sync queue.
- Donor aplikasi penuh hanya dapat mengambil status booking miliknya.
- Mode Donor memvalidasi pasangan booking ID dan nomor telepon, menerapkan rate limit, dan tidak membocorkan bagian kredensial yang salah.
- Retention job menghapus/menganonimkan data donor dan booking satu bulan setelah event Selesai/Ditutup/Dibatalkan serta audit satu bulan setelah dibuat, tanpa menghapus agregat kilogram non-PII.
- Self-registration membuat akun/workspace Pengelola yang langsung aktif tanpa mencampur tenant.
- Batas lima event Akan Datang/Berlangsung per Pengelola ditegakkan secara atomik.
- Ekspor CSV memuat schema dan PII yang telah disetujui hanya untuk workspace Pengelola.
- Banner upload failure/retry.

### 17.4 UI test kritis

- Pengelola login → create → publish event.
- App Clip invocation valid → event detail yang benar.
- Donor form validation.
- Persetujuan syarat dan ketentuan wajib serta link legal dapat dibuka.
- Camera denied → gallery fallback.
- Satu item lolos pemeriksaan awal → shipping → booking → label.
- Scan multiple garments → retake.
- Item gagal scan → kembali ke daftar → scan item lain → kembali dan scan ulang item pertama sampai lolos.
- Menghapus item yang sudah lolos maupun belum lolos; tombol lanjut hanya aktif jika semua item tersisa lolos dan minimal satu item tersisa.
- Menghapus item memastikan seluruh riwayat scan lokal item tersebut ikut hilang.
- QR reception → weight verification → dashboard update.
- QR reception yang memenuhi kapasitas → booking tertunda lain dibatalkan.
- Rekap terfilter → ekspor CSV melalui share sheet.
- Event tersimpan dapat dilihat offline; create/edit Draf bertahan dan disinkronkan setelah reconnect.
- Scanner pakaian berjalan offline, sedangkan booking dan penerimaan menampilkan kebutuhan koneksi tanpa membuat transaksi lokal.
- Donor membuka aplikasi penuh dan melihat status booking miliknya.
- Mode Donor dan Pengelola tersedia pada aplikasi penuh yang sama dengan entry/auth flow yang berbeda.
- CSV berisi seluruh kolom yang disetujui termasuk nama dan nomor telepon donor.
- Penolakan dapat disimpan tanpa alasan; preset dan teks Lainnya berperilaku sesuai keputusan.
- Invalid/expired invocation dan invalid/used QR.
- VoiceOver labels dan Dynamic Type pada layar kritis.

### 17.5 Release gates

- XcodeGen generation berhasil.
- Build aplikasi utama, App Clip, dan preview host berhasil dengan strict concurrency.
- Unit, integration, dan UI test kritis lulus.
- SwiftFormat, SwiftLint, dan diff check lulus.
- App Clip invocation diuji pada environment nyata, bukan hanya environment variable preview.
- Archive/thinned size App Clip diverifikasi.
- Privacy manifest, permission copy, associated domain, signing, dan entitlements diverifikasi per environment.
- Staging end-to-end memakai backend staging dan TestFlight sebelum release.

## 18. Register Keputusan Produk Final

Seluruh pertanyaan produk yang diajukan selama penyusunan PRD telah ditutup. Threshold scanner sengaja dibiarkan tanpa angka dan tidak menjadi pertanyaan terbuka; backend telah diputuskan menggunakan Supabase Hosted.

### 18.1 Keputusan terkonfirmasi — identitas dan scope bisnis

1. **Nama produk:** .kumpul.
2. **EcoTouch Indonesia:** hanya contoh demo.
3. **Tenant model:** banyak akun Pengelola/workspace sejak MVP, dengan relasi satu akun ke satu workspace organisasi teknis.
4. **Role:** Organizer, Organisasi, Admin, dan Pengelola dinormalisasi sebagai satu orang/role produk bernama Pengelola. Pengelola juga menjadi petugas penerimaan; tidak ada operator atau membership tambahan.
5. **Pasar dan bahasa rilis pertama:** Indonesia dan Bahasa Indonesia.

### 18.2 Keputusan terkonfirmasi — event dan kapasitas

6. **Status acara:** Draf, Akan Datang, Berlangsung, Selesai, Ditutup, dan Dibatalkan. Terbit adalah aksi, bukan status.
7. **Penyelesaian acara:** otomatis setelah end datetime.
8. **Syarat publish:** banner wajib; deskripsi opsional.
9. **Lokasi/jadwal:** satu drop point dan satu jadwal operasional per acara.
10. **Kapasitas:** batas keras dalam kilogram.
11. **Waktu pemakaian kapasitas:** ketika paket diterima dan ditimbang.
12. **Booking ketika penuh:** tidak diperbolehkan.

### 18.3 Keputusan kriteria dan scanner

13. **Kategori MVP:** Katun, Linen, Rayon, Wol, Tencel, Sutra, Tidak Elastis, Denim, Tidak Berenda, dan Poliester; tidak ada kategori tambahan pada MVP.
14. **Scope scanner:** hanya aksesori dan jumlah pakaian; tidak menilai material/kriteria event.
15. **Aturan aksesori:** kancing, resleting, saku, logam, dan ornamen selalu harus dilepas.
16. **Otoritas scanner:** rekomendasi sebelum verifikasi akhir Pengelola saat paket diterima.
17. **Foto:** salinan yang digunakan .kumpul tidak diunggah atau disimpan; hanya dipakai selama satu flow App Clip lalu hilang. Foto asli yang dipilih dari galeri pengguna tidak dihapus. Backend menyimpan status memenuhi kriteria atau tidak, tanpa foto.
18. **Tujuan model:** mampu mendeteksi aksesori pada pakaian. Jika item belum lolos, donor dapat memindai ulang item yang sama berkali-kali, kembali untuk memindai pakaian lain, atau menghapus item berstatus apa pun. Flow hanya dapat dilanjutkan jika minimal satu item tersisa dan semuanya lolos pemeriksaan awal. Tidak ada threshold kualitas numerik MVP dan pertanyaan tersebut tidak dibuka kembali; kualitas ditingkatkan dari hasil pilot.

### 18.4 Keputusan donor, consent, dan booking

19. **Data wajib:** nama, nomor telepon, estimasi berat pakaian yang didonasikan, dan status pakaian. Estimasi donor terpisah dari berat aktual hasil timbangan Pengelola; hanya berat aktual yang memakai kapasitas.
20. **Nomor telepon:** hanya Indonesia.
21. **Syarat dan ketentuan:** checkbox wajib; naskah belum dibuat dan menjadi blocker rilis.
22. **Donor anonim:** tidak diperbolehkan.
23. **Status setelah App Clip ditutup:** donor memakai mode Donor pada aplikasi penuh .kumpul dan membuktikan kepemilikan booking dengan booking ID serta nomor telepon.
24. **Masa berlaku booking:** maksimal 12 jam dan berakhir lebih awal pada end datetime event.
25. **Item belum lolos:** hanya status aktif terakhir dapat disimpan sebagai aggregate analytics tanpa foto/PII. Percobaan sebelumnya yang digantikan dan item yang dihapus tidak disimpan.

### 18.5 Keputusan pengiriman dan label

26. **Metode MVP:** antar langsung, ojek online, dan ekspedisi; ketiganya selalu tersedia pada setiap event.
27. **Integrasi kurir:** tidak ada; ojek online dan ekspedisi hanya berupa instruksi manual.
28. **Isi label:** logo .kumpul, nama event, booking ID, QR, nama donor, nama penerima, nomor telepon penerima, dan alamat penerima. Tanggal kedaluwarsa serta metode pengiriman tidak dicetak pada label.
29. **Format label:** berupa gambar dengan resolusi yang layak disimpan ke galeri; tidak ada ukuran cetak fisik khusus dan tidak ada barcode selain QR.
30. **Data penerima:** nama, nomor telepon, dan alamat penerima berasal dari event.

### 18.6 Keputusan penerimaan dan rekap

31. **Fungsi tombol QR aplikasi utama:** hanya untuk memindai booking donor; bukan untuk membagikan event.
32. **Data penerimaan:** Pengelola mencatat berat aktual dan memilih kondisi Baik, Rusak, Basah, Kotor, atau Berjamur. Alasan penolakan tidak wajib; preset yang tersedia adalah Aksesori Belum Dilepas, Tidak Sesuai Kriteria, Rusak, Basah, Kotor, Berjamur, Melebihi Kapasitas, dan Lainnya. Teks tambahan untuk Lainnya tidak wajib.
33. **Penerimaan sebagian:** tidak diperbolehkan. Satu booking diterima atau ditolak secara utuh.
34. **Definisi donor unik:** nomor telepon donor yang sama dihitung satu kali pada setiap event, terlepas dari jumlah booking pada event tersebut.
35. **Ekspor rekap:** wajib menghasilkan file CSV. Dashboard eksternal dan laporan dampak lanjutan tidak termasuk baseline MVP kecuali diputuskan kemudian.

### 18.7 Keputusan backend, auth, dan operasional

36. **Teknologi backend:** Supabase Hosted dengan PostgreSQL sebagai source of truth, Supabase Auth, Edge Functions, PostgreSQL Functions/RPC, Cron, dan Storage. Detail implementasi berada di `docs/BACKEND_PRD.md`; aplikasi tetap menggunakan domain/repository boundary agar UI tidak terikat langsung pada vendor.
37. **Login Pengelola:** Sign in with Apple dan email/password.
38. **Backend eksternal:** jawaban sebelumnya dikoreksi; schema/API/backend belum dibuat.
39. **Offline mode:** Pengelola dapat melihat event tersimpan dan membuat/mengedit Draf; donor dapat memindai pakaian. Publish, booking, pemindaian QR penerimaan, serta menerima/menolak paket wajib online dan tidak masuk antrean offline. Konflik Draf diselesaikan dengan perubahan paling baru otomatis menang.
40. **Skala dan retensi:** pilot menargetkan 50 akun Pengelola/workspace. Maksimal lima event Akan Datang/Berlangsung berlaku per Pengelola dan baseline load test adalah 1.000 booking per hari di seluruh platform. Data donor/booking disimpan satu bulan setelah event Selesai/Ditutup/Dibatalkan, sedangkan audit log disimpan satu bulan sejak dibuat.
41. **Penghapusan data donor:** setiap Pengelola dapat menghapus data donor. Produk tidak mewajibkan alasan, waktu, atau identitas penghapus disimpan untuk aksi tersebut.

### 18.8 Keputusan prioritas dan definisi sukses

42. **Scope MVP pertama:** create/publish event, App Clip booking, scanner, QR reception, dan recap semuanya wajib tersedia.
43. **Target waktu:** belum ada tanggal rilis maupun milestone demo/TestFlight yang ditetapkan. Release tetap harus melalui staging dan TestFlight sesuai release gates.
44. **Metrik utama:** total kilogram pakaian yang benar-benar diterima berdasarkan hasil timbangan Pengelola. Belum ada target numerik awal.
45. **Pembagian deep modules:** pembagian pada bagian 14.2 disetujui.
46. **Test wajib fase pertama:** Event Domain, Donation Flow, Scanner Policy, Booking/Capacity, dan Invocation Resolver, sesuai bagian 17.2.

### 18.9 Keputusan kapasitas dan cakupan Indonesia

47. **Booking tertunda ketika kapasitas penuh:** seluruh booking aktif yang belum diterima otomatis dibatalkan ketika kapasitas event mencapai batas keras.
48. **Timezone event:** ditentukan otomatis dari lokasi event di Indonesia, termasuk pemetaan ke WIB, WITA, atau WIT.

### 18.10 Keputusan lanjutan 49–59

49. **Scanner flow:** donor boleh memindai ulang satu pakaian berkali-kali sampai lolos, kembali untuk memindai pakaian lain, dan menghapus pakaian berstatus lolos maupun belum lolos. Flow tidak dapat maju sebelum minimal satu item tersisa dan seluruh item tersisa lolos pemeriksaan awal. Tidak ada ambang kualitas numerik MVP.
50. **Berat:** donor mengisi estimasi; Pengelola mencatat berat aktual hasil timbangan.
51. **Status donor:** tersedia melalui aplikasi penuh.
52. **Metode pengiriman:** ketiganya selalu tersedia di semua event.
53. **Label:** memuat logo .kumpul, booking ID, QR, nama donor, nama event, serta nama/telepon/alamat penerima. Label berupa gambar yang dapat disimpan di galeri dan hanya memakai QR tanpa barcode lain.
54. **Backend eksternal:** belum dibuat.
55. **Offline:** event cache, create/edit Draf, dan scanner tersedia offline; booking serta penerimaan/penolakan paket harus online.
56. **Admin:** sama dengan Pengelola. Penghapusan donor tidak wajib menyimpan alasan, waktu, atau identitas penghapus.
57. **Kondisi:** Baik, Rusak, Basah, Kotor, dan Berjamur; alasan tambahan dapat ditulis manual.
58. **Skala/retensi:** 50 akun Pengelola/workspace untuk pilot dengan relasi satu-ke-satu, lima event Akan Datang/Berlangsung per Pengelola, baseline 1.000 booking per hari di seluruh platform, data donor/booking satu bulan setelah event Selesai/Ditutup/Dibatalkan, dan audit log satu bulan sejak dibuat.
59. **North-star metric:** total kilogram pakaian yang benar-benar diterima; belum ada target awal.

### 18.11 Keputusan lanjutan 60–74

60. **Kualitas scanner:** tidak ada baseline numerik. Kualitas dinaikkan berdasarkan hasil pilot dan topik threshold tidak ditanyakan kembali.
61. **Akses donor:** booking ID dan nomor telepon. Aplikasi penuh yang sama memiliki mode Donor dan Pengelola.
62. **Konflik Draf:** perubahan paling baru otomatis menang.
63. **Alasan penolakan:** tidak wajib. Preset tersedia dan teks manual untuk Lainnya juga tidak wajib.
64. **Retensi:** donor/booking satu bulan sejak event menjadi Selesai, Ditutup, atau Dibatalkan; audit log satu bulan sejak audit dibuat.
65. **Skala:** lima event Akan Datang/Berlangsung per Pengelola dan baseline 1.000 booking per hari di seluruh platform.
66. **Item dihapus:** seluruh riwayat scan nonfoto ikut dihapus.
67. **Dokumen legal:** pembuat aplikasi bertanggung jawab menulis dan menyetujuinya.
68. **Status booking:** Menunggu, Diterima, Ditolak, Kedaluwarsa, dan Dibatalkan; tidak ada Dalam Pengiriman.
69. **Selesai dan Ditutup:** Ditutup dilakukan manual untuk menghentikan event lebih awal. Selesai terjadi otomatis pada end datetime dan langsung menutup event secara operasional tanpa perlu status Ditutup berikutnya.
70. **Expiry booking:** waktu lebih awal antara 12 jam setelah booking dibuat dan event selesai.
71. **CSV:** boleh memuat nama dan nomor telepon donor bersama seluruh field operasional yang diusulkan.
72. **Onboarding Pengelola:** Pengelola mendaftar sendiri; akun/workspace langsung aktif dan tidak ada undangan atau pengelolaan Pengelola lain.
73. **Jadwal:** semua hari terpilih memakai jam buka/tutup yang sama; jam berbeda per hari tidak tersedia pada MVP.
74. **Edit event:** seluruh field boleh diedit setelah diterbitkan selama event belum terminal.

### 18.12 Keputusan final 75–85

75. **Threshold scanner:** sengaja tidak ditentukan dan tidak ditanyakan kembali selama project ini. Model ditingkatkan berdasarkan hasil pilot.
76. **Penyatuan aktor:** Organizer, Organisasi, dan Pengelola adalah orang/role yang sama. Secara teknis satu akun Pengelola memiliki satu workspace tenant; tidak ada organizer kedua pada workspace yang sama di MVP.
77. **Snapshot booking:** booking aktif mempertahankan snapshot nama event, lokasi, jadwal, kriteria, data penerima, dan instruksi ketika dibuat. Perubahan event hanya berlaku untuk booking baru.
78. **Penurunan kapasitas:** dilarang menurunkan kapasitas di bawah total berat aktual yang sudah diterima.
79. **Batas event aktif:** hanya Akan Datang dan Berlangsung yang dihitung terhadap maksimal lima event per Pengelola.
80. **Riwayat scan:** hasil sebelumnya yang belum lolos tidak disimpan meskipun item akhirnya lolos. Hanya hasil aktif/final dipertahankan; item yang dihapus menghapus seluruh datanya.
81. **Ditutup lebih awal:** seluruh booking Menunggu otomatis Dibatalkan.
82. **Aktivasi akun:** self-registration langsung aktif tanpa persetujuan tim .kumpul.
83. **Alasan event terminal:** alasan tidak wajib ketika event Ditutup lebih awal atau Dibatalkan.
84. **Edit terminal:** seluruh field dapat diedit hanya pada Draf, Akan Datang, atau Berlangsung. Selesai, Ditutup, dan Dibatalkan read-only serta tidak dapat dibuka kembali.
85. **Terbit:** dihapus dari vocabulary status. Aksi menerbitkan langsung menghasilkan Akan Datang atau Berlangsung berdasarkan waktu event.

## 19. Risks dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Scanner belum dikalibrasi pada foto lapangan | Donor salah ditolak/diterima | Golden dataset, human verification, model versioning, monitoring false decision |
| Tidak ada source of truth server | Data antar organizer dan donor tidak tersambung | Backend domain/API menjadi fondasi sebelum memperluas UI |
| Race condition kapasitas | Event menerima booking melebihi kebijakan | Transaction/locking server-side dan capacity policy eksplisit |
| Invocation membuka event salah | Donor mengirim ke tujuan salah | Opaque token, server validation, environment-aware associated domain |
| QR berisi PII atau mudah ditebak | Kebocoran data/penyalahgunaan | Opaque revocable token, least-data payload, authorization |
| App Clip terlalu besar/lambat | Pengalaman gagal dimuat | Pantau thinned size, kompres aset/model, lazy load network media |
| Copy campuran bahasa | Kebingungan dan kualitas produk rendah | Strategi locale dan string catalog sebelum produksi |
| Prototype UI dianggap data nyata | Keputusan operasional salah | Tandai mock, implement empty/loading/error, staging E2E dengan backend |
| Signing/associated domains berbeda per environment | Invocation atau distribusi gagal | Release gate per environment dan automated configuration checks |
| Test coverage sangat rendah | Regression pada flow kritis | Prioritaskan deep-module unit tests dan 3 journey E2E utama |
| Identitas donor aplikasi penuh tidak kuat | Booking donor dapat dilihat pihak lain | Gunakan verifikasi kepemilikan yang disepakati, rate limit, dan jangan mencari booking hanya berdasarkan PII yang mudah ditebak |
| Draf offline berkonflik dengan versi server | Perubahan organizer hilang atau menimpa data | Versioning, conflict UI/policy eksplisit, dan test reconnect |
| Retensi menghapus data mentah yang dibutuhkan metrik | North-star metric kehilangan histori | Simpan agregat kilogram non-PII sebelum data donor/booking dihapus atau dianonimkan |

## 20. Rollout Plan yang Disarankan

### Phase 0 — Product decisions dan domain contract

- Gunakan register keputusan final bagian 18 sebagai baseline.
- Bekukan brand, actor, lifecycle, capacity policy, privacy, dan scanner authority untuk implementasi MVP.
- Setujui schema serta API contract.

### Phase 1 — Backend foundation dan event Pengelola

- Auth/session dan workspace authorization.
- Identitas donor aplikasi penuh dan pengaitan booking.
- Event domain/repository.
- Draf offline, sinkronisasi, publish, list, detail, edit, dan invocation URL.
- Banner storage dan environment configuration.

### Phase 2 — App Clip event context dan booking

- Invocation resolver dan state handling.
- Detail event dinamis.
- Donation flow state machine.
- Item review, shipping selection, idempotent booking, dan label QR.
- Status booking donor pada aplikasi penuh.

### Phase 3 — Reception dan recap

- QR scanner Pengelola.
- Reception verification dan status transition.
- Capacity update, dashboard, latest donations, dan recap.

### Phase 4 — Model readiness dan production hardening

- Dataset foto ponsel, kalibrasi deteksi lima kelompok aksesori, dan false decision review.
- Accessibility, localization, analytics, observability, security, dan privacy review.
- TestFlight staging E2E, App Clip invocation production-like test, archive size, dan release gates.

## 21. Out of Scope untuk Baseline Ini

Sampai pemilik produk menyatakan sebaliknya:

- Pembayaran atau insentif finansial donor.
- Marketplace jual-beli pakaian.
- Integrasi pemesanan/penagihan kurir otomatis.
- Android dan web admin.
- Inventori gudang setelah paket diterima.
- Pelacakan kurir real-time.
- Social feed, gamification, dan referral.
- Model ML cloud, upload foto, atau penyimpanan foto pakaian donor.
- Perubahan portal Apple, identifier, provisioning, atau release; PRD ini hanya mendokumentasikan kebutuhan produk.

## 22. Definition of Done Produk MVP

MVP dianggap selesai ketika:

1. Pengelola terautentikasi dapat membuat dan menerbitkan event yang persisten.
2. QR/link event membuka App Clip pada event yang benar.
3. Donor dapat menyelesaikan alur dari detail event sampai booking server-side dan label QR.
4. Donor dapat melihat status booking miliknya melalui aplikasi penuh dengan verifikasi kepemilikan yang aman.
5. Scanner mendeteksi kelompok aksesori yang ditetapkan, dapat digunakan offline, mendukung retry/navigasi/hapus item, dan tidak mengizinkan flow lanjut sebelum semua item tersisa lolos pemeriksaan awal; tidak ada release gate akurasi numerik.
6. Pengelola dapat melihat event tersimpan dan mengelola Draf secara offline tanpa membuat transaksi booking/penerimaan offline.
7. Pengelola dapat memvalidasi QR, mencatat penerimaan, dan memperbarui berat aktual secara online.
8. Dashboard serta rekap menampilkan data backend yang konsisten dan north-star kilogram aktual dapat dihitung setelah retensi data mentah.
9. Retensi satu bulan dan retensi audit yang disepakati berjalan serta teruji.
10. Flow kritis memiliki test sesuai bagian 17 dan lulus pada staging.
11. Security, privacy, accessibility, localization, App Clip size, signing, dan associated-domain release gates lulus.
12. Tidak ada copy/data contoh yang tampil pada konfigurasi produksi.
13. Seluruh acceptance criteria, metrik, dan keputusan produk final pada bagian 18 diterapkan tanpa pertanyaan terbuka.
