# Product Requirements Document — Backend MVP .kumpul

- **Status:** Approved baseline; backend MVP terimplementasi di staging, production readiness masih pending
- **Versi:** 1.1
- **Tanggal:** 8 September 2026
- **Produk:** .kumpul
- **Platform klien:** iOS 26+ (aplikasi utama dan App Clip)
- **Backend terpilih:** Supabase Hosted
- **Source of truth:** PostgreSQL pada Supabase
- **Dokumen induk:** `docs/PRD.md`

> **Status implementasi saat ini (8 September 2026):** source branch memiliki 10 migration,
> 11 Edge Function, RPC domain, RLS, Storage banner, dan scheduled jobs. Hosted staging
> `kumpul-staging` (`tdpvtdblphojutjifdlc`) aktif dan sudah diverifikasi terhadap source.
> Bukti production project, TestFlight/App Clip E2E, backup/restore drill, dan alert provider
> belum menjadi bukti release yang lengkap.

## 1. Ringkasan Eksekutif

Backend MVP .kumpul menggunakan **Supabase Hosted** dengan PostgreSQL sebagai satu-satunya source of truth data server. Supabase Auth menangani autentikasi Pengelola melalui Sign in with Apple dan email/password. Edge Functions menjadi batas aman untuk operasi publik App Clip dan operasi sensitif. PostgreSQL Functions/RPC menjalankan aturan bisnis atomik, khususnya penerimaan paket dan kapasitas keras. Supabase Cron menjalankan perubahan status berbasis waktu dan retensi. Supabase Storage hanya menyimpan banner event.

Foto pakaian, hasil percobaan scan yang digantikan, dan pemrosesan scanner tidak masuk backend. Pemindaian tetap berjalan on-device dengan Vision/Core ML. SwiftData menangani cache event serta Draf offline, tetapi booking dan penerimaan/penolakan paket selalu membutuhkan koneksi dan konfirmasi server.

Arsitektur ini dipilih untuk memenuhi kebutuhan App Clip tanpa akun, multi-tenant, transaksi kapasitas, lifecycle otomatis, penyimpanan banner, CSV, dan target pilot tanpa membangun custom backend dari nol. CloudKit tidak digunakan sebagai backend kedua agar tidak tercipta dua source of truth atau sinkronisasi lintas-backend.

## 2. Problem Statement

Pada awal perencanaan, prototype .kumpul belum memiliki backend, autentikasi, database persisten,
tenant isolation, API publik App Clip, transaksi kapasitas, scheduled jobs, maupun retensi otomatis.
Bagian berikut adalah konteks masalah historis yang kini ditangani oleh implementasi backend:

- event dan booking belum dapat menjadi data operasional lintas-perangkat;
- App Clip belum dapat membuka event dinamis dan membuat booking server-side;
- kapasitas dapat mengalami race condition jika penerimaan dilakukan bersamaan;
- Pengelola belum dapat memvalidasi QR dan mencatat hasil timbangan secara tepercaya;
- donor belum dapat memeriksa status booking melalui aplikasi penuh;
- dashboard, rekap, dan CSV belum berasal dari transaksi nyata;
- data donor belum memiliki kontrol akses dan lifecycle penghapusan yang dapat ditegakkan;
- perubahan status event dan booking berbasis waktu belum dapat berjalan otomatis.

Backend harus menyelesaikan masalah tersebut tanpa mengunggah foto pakaian, tanpa membuat transaksi operasional offline, dan tanpa mengunci domain iOS pada detail internal vendor.

## 3. Solution

Membangun backend managed pada Supabase yang terdiri dari:

1. **PostgreSQL** untuk data relasional, constraint, indeks, transaksi, aggregate, dan Row-Level Security.
2. **Supabase Auth** untuk Sign in with Apple dan email/password Pengelola.
3. **Edge Functions** untuk public App Clip APIs, donor booking lookup, request validation, rate limiting, dan orchestration operasi sensitif.
4. **PostgreSQL Functions/RPC** untuk mutation domain yang harus atomik dan tidak boleh dipisahkan menjadi read-check-write dari klien.
5. **Supabase Cron** untuk booking expiry, penyelesaian event, dan retensi.
6. **Supabase Storage** untuk banner event saja.
7. **SwiftData di perangkat** untuk event cache dan Draf offline.
8. **Vision/Core ML di perangkat** untuk scanner; backend hanya menerima metadata final yang diperlukan booking.

## 4. Goals dan Non-Goals

### 4.1 Goals MVP

1. Menjadi source of truth tunggal untuk akun Pengelola, workspace, event, booking, penerimaan, kapasitas, rekap, dan audit.
2. Mengisolasi data setiap Pengelola/workspace secara default.
3. Mendukung self-registration Pengelola tanpa approval manual.
4. Mendukung Sign in with Apple dan email/password.
5. Menyediakan event context publik yang aman untuk App Clip.
6. Membuat booking secara online, tervalidasi, dan idempotent.
7. Menjamin kapasitas keras tidak terlampaui walaupun ada request bersamaan.
8. Memastikan satu booking diterima atau ditolak secara utuh.
9. Menyediakan status booking kepada donor dengan booking ID dan nomor telepon.
10. Menjalankan lifecycle event, booking expiry, dan retensi secara otomatis.
11. Menghasilkan rekap dan CSV yang konsisten dengan data transaksi.
12. Mempertahankan agregat non-PII untuk north-star metric setelah data donor dihapus.
13. Mendukung target pilot 50 workspace, maksimum lima event aktif per workspace, dan baseline 1.000 booking per hari di seluruh platform.

### 4.2 Non-Goals MVP

- Menjalankan scanner atau model ML di cloud.
- Mengunggah atau menyimpan foto pakaian.
- Mengintegrasikan API ojek online, ekspedisi, tarif, atau tracking.
- Mendukung pembayaran.
- Mendukung akun Pengelola kedua dalam satu workspace.
- Menyediakan admin portal global atau web dashboard.
- Menyediakan booking atau penerimaan paket offline.
- Menyimpan histori setiap percobaan scanner.
- Menggunakan CloudKit sebagai replica atau backend kedua.
- Menjalankan data warehouse, BI eksternal, atau event streaming skala besar.
- Menjadi sistem inventori gudang setelah paket diterima.

## 5. Prinsip Arsitektur

### 5.1 Satu source of truth

Semua data yang memengaruhi status event, eligibility booking, kapasitas, penerimaan, rekap, dan status donor berasal dari PostgreSQL. Cache lokal tidak boleh dianggap berhasil tersinkron sebelum server mengonfirmasi mutation.

### 5.2 Server authoritative

Klien boleh melakukan validasi untuk UX, tetapi backend mengulang seluruh validasi yang berpengaruh pada keamanan atau aturan bisnis. Waktu server, bukan jam perangkat, menentukan status, expiry, urutan commit, dan audit timestamp.

### 5.3 Least privilege

- Klien iOS dan App Clip hanya membawa Supabase publishable/anon key yang memang ditujukan untuk klien.
- Secret key atau service-role key tidak pernah disematkan dalam binary, konfigurasi aplikasi, log, maupun repository.
- Operasi Pengelola memakai JWT pengguna dan RLS.
- Operasi App Clip publik melewati Edge Function dengan permukaan akses minimum.
- Operasi yang memakai service role hanya berjalan di lingkungan server dan tetap melakukan authorization eksplisit.

### 5.4 Transaction first

Mutation yang menyentuh lebih dari satu invariant domain dijalankan di satu PostgreSQL transaction. Klien tidak boleh melakukan rangkaian terpisah “baca → validasi → tulis” untuk kapasitas, status terminal, atau idempotency.

### 5.5 Privacy by design

Backend hanya mengumpulkan data yang dibutuhkan. Foto dan riwayat scan yang digantikan tidak dikirim. PII donor dibatasi aksesnya, dikeluarkan hanya untuk Pengelola pemilik event atau donor yang lolos proof-of-possession, dan dihapus/dianonimkan sesuai retensi.

### 5.6 Vendor boundary

Kode aplikasi mengakses backend melalui protocol/repository domain. Supabase SDK tidak boleh menyebar ke view atau state machine bisnis. Hal ini menjaga testability dan memungkinkan perubahan backend di masa depan tanpa menulis ulang UI.

## 6. Aktor Sistem dan Trust Boundary

### 6.1 Pengelola terautentikasi

Pengguna aplikasi penuh yang memiliki satu workspace. Pengelola dapat membuat event, mengelola Draf, menerbitkan atau menghentikan event, melihat booking event miliknya, menerima/menolak paket, mengunduh CSV, dan menghapus data donor dalam tenant miliknya.

### 6.2 Donor App Clip

Pengguna tanpa akun yang membuka event melalui invocation token. Donor hanya dapat membaca representasi publik event dan membuat booking melalui Edge Function. Donor tidak memiliki akses langsung untuk membaca tabel booking atau data donor.

### 6.3 Donor aplikasi penuh

Pengguna mode Donor yang memasukkan booking ID serta nomor telepon Indonesia. Setelah pasangan tersebut diverifikasi dan lolos rate limit, backend menerbitkan akses singkat yang hanya berlaku untuk satu booking.

### 6.4 Scheduled worker

Cron menjalankan private SQL functions untuk lifecycle, expiry, dan retention. Cleanup banner
memanggil Edge Function terproteksi melalui HTTP dengan shared secret dan tetap mencatat setiap
run; endpoint tersebut tidak menerima akses anonim biasa.

### 6.5 Platform operator

Tim pembuat aplikasi yang mengelola project Supabase, migration, environment secret, backup, dan incident response. Ini adalah peran operasional infrastruktur, bukan role pengguna produk baru.

## 7. Arsitektur Logis

```text
Aplikasi utama .kumpul
  ├─ Supabase Auth: Sign in with Apple / email-password
  ├─ Data API + RLS: query data milik workspace
  ├─ Edge Functions/RPC: mutation domain sensitif
  └─ SwiftData: cache event dan Draf offline

App Clip .kumpul
  ├─ Edge Function: resolve invocation event
  ├─ Vision/Core ML: scan pakaian on-device
  └─ Edge Function: create booking online

Supabase
  ├─ PostgreSQL + RLS + constraints
  ├─ PostgreSQL Functions/RPC
  ├─ Edge Functions
  ├─ Auth
  ├─ Storage: banner event
  └─ Cron: lifecycle dan retention
```

## 8. User Stories Backend

1. Sebagai Pengelola, saya ingin mendaftar sendiri agar dapat memakai .kumpul tanpa menunggu approval manual.
2. Sebagai Pengelola, saya ingin login dengan Apple agar tidak perlu membuat password baru.
3. Sebagai Pengelola, saya ingin login dengan email/password agar tersedia pilihan autentikasi alternatif.
4. Sebagai Pengelola, saya ingin akun dari provider yang sah terhubung ke workspace yang benar agar data tidak terduplikasi.
5. Sebagai Pengelola, saya ingin data saya terisolasi agar Pengelola lain tidak dapat membaca event atau donor saya.
6. Sebagai Pengelola, saya ingin membuat Draf event agar pekerjaan dapat dilanjutkan kemudian.
7. Sebagai Pengelola, saya ingin sinkronisasi Draf bersifat idempotent agar retry tidak membuat event ganda.
8. Sebagai Pengelola, saya ingin perubahan Draf terakhir yang diterima server menang agar konflik selesai otomatis.
9. Sebagai Pengelola, saya ingin menerbitkan event hanya setelah semua data wajib valid agar donor tidak menerima informasi tidak lengkap.
10. Sebagai Pengelola, saya ingin maksimal lima event aktif ditegakkan server agar kebijakan tidak dapat dilewati oleh klien lama.
11. Sebagai Pengelola, saya ingin status event berubah otomatis sesuai waktu agar operasional tidak bergantung pada tindakan manual.
12. Sebagai Pengelola, saya ingin timezone ditentukan dari lokasi Indonesia agar waktu event benar di WIB, WITA, atau WIT.
13. Sebagai Pengelola, saya ingin mengedit event nonterminal agar informasi terbaru berlaku untuk booking baru.
14. Sebagai Pengelola, saya ingin booking lama mempertahankan snapshot agar tujuan pengiriman dan labelnya tidak berubah.
15. Sebagai Pengelola, saya ingin menutup event lebih awal agar booking baru langsung berhenti.
16. Sebagai Pengelola, saya ingin booking Menunggu dibatalkan ketika event ditutup agar donor tidak mengirim ke event yang sudah berhenti.
17. Sebagai Pengelola, saya ingin event terminal read-only agar histori tidak berubah.
18. Sebagai Pengelola, saya ingin kapasitas tidak dapat diturunkan di bawah berat aktual agar data tetap konsisten.
19. Sebagai donor, saya ingin invocation membuka event yang benar agar tidak salah tujuan.
20. Sebagai donor, saya ingin mengetahui event tidak tersedia, selesai, dibatalkan, atau penuh sebelum mengisi data.
21. Sebagai donor, saya ingin membuat booking tanpa akun agar alur App Clip tetap cepat.
22. Sebagai donor, saya ingin retry request tidak membuat booking ganda agar satu paket memiliki satu identitas.
23. Sebagai donor, saya ingin booking memiliki expiry yang benar agar instruksi tidak menyesatkan.
24. Sebagai donor, saya ingin label memakai snapshot event agar tujuan pengiriman tidak berubah setelah booking.
25. Sebagai donor, saya ingin QR tidak memuat PII agar label tidak membocorkan data ketika dipindai pihak lain.
26. Sebagai donor, saya ingin melihat status booking melalui aplikasi penuh agar mengetahui hasil donasi setelah App Clip ditutup.
27. Sebagai donor, saya ingin backend tidak menyimpan foto pakaian agar privasi saya terjaga.
28. Sebagai donor, saya ingin input salah tidak membuat data setengah jadi agar dapat mencoba kembali dengan aman.
29. Sebagai Pengelola penerimaan, saya ingin QR menemukan booking yang tepat agar paket dapat diproses cepat.
30. Sebagai Pengelola penerimaan, saya ingin QR yang invalid, expired, cancelled, atau sudah diproses ditolak agar tidak ada pencatatan ganda.
31. Sebagai Pengelola penerimaan, saya ingin mencatat berat aktual dan kondisi agar hasil event akurat.
32. Sebagai Pengelola penerimaan, saya ingin penerimaan dilakukan atomik agar kapasitas tidak terlampaui oleh request bersamaan.
33. Sebagai Pengelola penerimaan, saya ingin seluruh booking diterima atau ditolak agar tidak ada status parsial.
34. Sebagai Pengelola penerimaan, saya ingin menolak paket tanpa alasan bila perlu agar keputusan operasional tidak terhambat.
35. Sebagai Pengelola, saya ingin semua booking Menunggu dibatalkan ketika kapasitas penuh agar tidak ada ekspektasi penerimaan yang salah.
36. Sebagai Pengelola, saya ingin rekap memakai berat aktual agar dampak tidak dihitung dari estimasi donor.
37. Sebagai Pengelola, saya ingin donor unik dihitung sekali per event agar metrik tidak terduplikasi.
38. Sebagai Pengelola, saya ingin CSV mengikuti filter dan tenant saya agar laporan aman dan relevan.
39. Sebagai Pengelola, saya ingin menghapus PII donor agar dapat menjalankan kebijakan privasi.
40. Sebagai pemilik produk, saya ingin agregat kilogram bertahan setelah retensi agar north-star metric tetap tersedia.
41. Sebagai operator platform, saya ingin job otomatis dapat dipantau agar kegagalan lifecycle atau retensi cepat diketahui.
42. Sebagai developer, saya ingin schema dan API dimigrasikan secara versioned agar staging dan production konsisten.
43. Sebagai developer, saya ingin error code stabil agar copy Bahasa Indonesia dapat dikelola di klien.
44. Sebagai developer, saya ingin backend lokal untuk test agar aturan kapasitas dan RLS dapat diverifikasi sebelum deployment.

## 9. Functional Requirements

### 9.1 Auth dan workspace

- **BE-AUTH-01 (P0):** Supabase Auth mendukung native Sign in with Apple dan email/password.
- **BE-AUTH-02 (P0):** Self-registration yang berhasil membuat satu profile dan satu workspace aktif untuk Pengelola tanpa approval manusia.
- **BE-AUTH-03 (P0):** Relasi owner account ke workspace bersifat satu-ke-satu pada MVP.
- **BE-AUTH-04 (P0):** Email/password mengikuti verifikasi email dan kebijakan password yang dikonfigurasi untuk production; verifikasi teknis bukan approval organisasi.
- **BE-AUTH-05 (P1, pending):** Jika account linking diaktifkan setelah MVP, penggabungan provider tidak boleh hanya mempercayai email yang belum terverifikasi dan harus mengikuti mekanisme aman Supabase Auth. Interface/source saat ini belum menyediakan operasi linking.
- **BE-AUTH-06 (P0):** Semua session Pengelola diverifikasi menggunakan JWT Supabase yang valid.
- **BE-AUTH-07 (P0):** Menonaktifkan atau menghapus akun harus mencabut akses ke workspace tanpa membuat data tenant dapat diambil akun lain.

### 9.2 Tenant isolation

- **BE-TENANT-01 (P0):** Semua row domain milik Pengelola mempunyai `workspace_id` eksplisit atau hubungan yang tidak ambigu ke workspace.
- **BE-TENANT-02 (P0):** RLS aktif pada seluruh tabel yang berada pada schema yang dapat diakses Data API.
- **BE-TENANT-03 (P0):** Policy SELECT, INSERT, UPDATE, dan DELETE dipisah dan hanya mengizinkan owner workspace.
- **BE-TENANT-04 (P0):** Tidak ada policy publik yang mengizinkan donor membaca tabel booking atau donor.
- **BE-TENANT-05 (P0):** View, database function, dan storage policy tidak boleh melewati tenant boundary secara implisit.
- **BE-TENANT-06 (P0):** Seluruh query rekap dan CSV memfilter workspace dari identitas server, bukan dari `workspace_id` yang dipercaya dari request body.

### 9.3 Event

- **BE-EVENT-01 (P0):** Backend menyimpan status internal stabil `draft`, `upcoming`, `ongoing`, `completed`, `closed`, dan `cancelled`; UI memetakannya ke Bahasa Indonesia.
- **BE-EVENT-02 (P0):** Draf boleh tidak lengkap, tetapi publish memerlukan nama, deskripsi, banner, start/end datetime, drop point, timezone, jadwal operasional, minimal satu kriteria, kapasitas, serta data penerima.
- **BE-EVENT-03 (P0):** Publish memilih `upcoming` bila waktu mulai masih di masa depan dan `ongoing` bila event sudah berada dalam rentang aktif.
- **BE-EVENT-04 (P0):** Publish ditolak bila end datetime telah lewat, start tidak sebelum end, lokasi bukan Indonesia, atau event aktif workspace telah berjumlah lima.
- **BE-EVENT-05 (P0):** Event berubah menjadi `ongoing` pada start datetime dan `completed` pada end datetime berdasarkan waktu server.
- **BE-EVENT-06 (P0):** Event `completed`, `closed`, dan `cancelled` read-only dan tidak dapat dibuka kembali.
- **BE-EVENT-07 (P0):** Menutup atau membatalkan event membatalkan seluruh booking `waiting` dalam transaction yang sama.
- **BE-EVENT-08 (P0):** Alasan close/cancel tidak wajib.
- **BE-EVENT-09 (P0):** Edit semua field diizinkan pada `draft`, `upcoming`, dan `ongoing`, tetapi kapasitas baru tidak boleh di bawah `received_weight_grams`.
- **BE-EVENT-10 (P0):** Edit event tidak mengubah snapshot booking yang sudah ada.
- **BE-EVENT-11 (P0):** Timezone disimpan sebagai IANA timezone dan dibatasi pada timezone Indonesia yang didukung MVP.
- **BE-EVENT-12 (P0):** Start/end disimpan dalam UTC; jadwal operasional disimpan sebagai hari lokal dan satu pasangan jam buka/tutup lokal.
- **BE-EVENT-13 (P0):** Event hanya memiliki satu drop point dan satu jadwal operasional.
- **BE-EVENT-14 (P0):** Hanya `upcoming` dan `ongoing` dihitung terhadap batas lima event aktif per workspace.
- **BE-EVENT-15 (P0):** Status berbasis waktu direkonsiliasi saat read/mutation selain diproses Cron, sehingga keterlambatan job tidak membuka event yang seharusnya terminal.
- **BE-EVENT-16 (P0):** Publish/aktivasi event diserialisasi per workspace menggunakan row/advisory lock agar dua request bersamaan tidak dapat melewati batas lima event aktif.

### 9.4 Public event context dan invocation

- **BE-INVOKE-01 (P0):** Setiap event yang diterbitkan mempunyai opaque invocation token yang tidak mengandung ID berurutan atau PII.
- **BE-INVOKE-02 (P0):** Resolve endpoint memvalidasi token, environment, status, waktu, dan kapasitas sebelum mengembalikan event context.
- **BE-INVOKE-03 (P0):** Response publik hanya memuat field event yang memang tampil kepada donor.
- **BE-INVOKE-04 (P0):** Draf dan event terminal tidak dapat di-resolve sebagai event yang menerima booking.
- **BE-INVOKE-05 (P0):** Event penuh tetap dapat dikembalikan sebagai context read-only dengan reason code yang menonaktifkan CTA.
- **BE-INVOKE-06 (P0):** Token dapat dicabut tanpa mengganti primary key event.
- **BE-INVOKE-07 (P0):** Share URL selalu environment-aware dan membuka event yang sama.

### 9.5 Booking

- **BE-BOOK-01 (P0):** Booking hanya dibuat melalui Edge Function publik yang melakukan validasi, rate limiting, idempotency, dan database transaction.
- **BE-BOOK-02 (P0):** Donor tidak perlu akun untuk membuat booking.
- **BE-BOOK-03 (P0):** Request wajib membawa invocation token, nama donor, nomor telepon Indonesia, estimasi berat, jumlah item, final scan metadata yang diizinkan, metode pengiriman, consent version, dan idempotency key.
- **BE-BOOK-04 (P0):** Backend menormalisasi nomor telepon ke bentuk E.164 Indonesia sebelum matching atau penyimpanan terproteksi.
- **BE-BOOK-05 (P0):** Booking ditolak bila event bukan `upcoming`/`ongoing`, event telah berakhir, event penuh, consent tidak ada, item kosong, ada final item yang belum lolos, metode pengiriman tidak valid, atau field wajib tidak sah.
- **BE-BOOK-06 (P0):** Estimasi berat donor tidak mengonsumsi kapasitas dan tidak digunakan untuk menahan kapasitas.
- **BE-BOOK-07 (P0):** `expires_at` adalah waktu yang lebih awal antara `created_at + 12 jam` dan `event.end_at`.
- **BE-BOOK-08 (P0):** Booking baru berstatus `waiting`.
- **BE-BOOK-09 (P0):** Backend membuat UUID internal, booking ID yang dapat dibaca manusia, serta QR token acak yang berbeda dari keduanya.
- **BE-BOOK-10 (P0):** QR payload hanya memuat opaque token/URL dan tidak memuat nama, telepon, alamat, atau status donor.
- **BE-BOOK-11 (P0):** Snapshot event immutable disimpan bersama schema version saat booking dibuat.
- **BE-BOOK-12 (P0):** Idempotency key yang sama dengan request hash yang sama mengembalikan hasil pertama; key sama dengan payload berbeda ditolak.
- **BE-BOOK-13 (P0):** Kegagalan sebelum commit tidak meninggalkan booking, item, token, atau idempotency result setengah jadi.
- **BE-BOOK-14 (P0):** Backend tidak menerima foto, EXIF, embedding, atau binary scanner dari request booking.
- **BE-BOOK-15 (P0):** Backend hanya menyimpan hasil final item yang menjadi bagian booking. Hasil scan sebelumnya dan item yang dihapus donor tidak dikirim atau disimpan.
- **BE-BOOK-16 (P0):** Booking menyimpan version identifier Syarat & Ketentuan serta Kebijakan Privasi yang aktif ketika donor memberikan consent.

### 9.6 Donor status lookup

- **BE-DONOR-01 (P0):** Donor lookup memakai pasangan booking ID dan nomor telepon Indonesia yang dinormalisasi.
- **BE-DONOR-02 (P0):** Endpoint menerapkan rate limit per perangkat/network fingerprint yang privacy-safe serta per booking ID.
- **BE-DONOR-03 (P0):** Response gagal bersifat generik dan tidak mengungkap apakah booking ID atau nomor telepon yang benar.
- **BE-DONOR-04 (P0):** Setelah pasangan cocok, backend menerbitkan token akses singkat yang hanya memiliki scope untuk satu booking.
- **BE-DONOR-05 (P0):** Detail donor yang dikembalikan dibatasi pada data booking miliknya dan tidak membuka data Pengelola lain di luar snapshot yang memang diperlukan.
- **BE-DONOR-06 (P0):** Booking yang telah melewati retention tidak dapat ditemukan kembali.
- **BE-DONOR-07 (P0):** Status publik hanya `waiting`, `accepted`, `rejected`, `expired`, atau `cancelled`.

### 9.7 QR dan penerimaan paket

- **BE-RECEIVE-01 (P0):** Validasi dan pemrosesan QR hanya tersedia untuk Pengelola terautentikasi dan wajib online.
- **BE-RECEIVE-02 (P0):** QR divalidasi menggunakan token hash. Replay material yang diperlukan untuk idempotent booking response atau label recovery disimpan terenkripsi, tidak dapat dibaca melalui Data API, dan hanya didekripsi pada server untuk actor/scope yang sah.
- **BE-RECEIVE-03 (P0):** Pengelola hanya dapat memproses booking milik event dalam workspace-nya.
- **BE-RECEIVE-04 (P0):** Hanya booking `waiting` yang dapat diterima atau ditolak.
- **BE-RECEIVE-05 (P0):** Request mencatat berat aktual dalam gram dan kondisi `good`, `damaged`, `wet`, `dirty`, atau `moldy`.
- **BE-RECEIVE-06 (P0):** Alasan penolakan dan teks tambahan opsional. Preset internal adalah `accessories_attached`, `criteria_mismatch`, `damaged`, `wet`, `dirty`, `moldy`, `capacity_exceeded`, dan `other`.
- **BE-RECEIVE-07 (P0):** Satu booking hanya menghasilkan satu keputusan final dan satu record reception; penerimaan sebagian tidak tersedia.
- **BE-RECEIVE-08 (P0):** Penerimaan mengunci row event dan booking, memeriksa status/waktu/kapasitas, membuat reception, mengubah status booking, dan memperbarui aggregate dalam satu transaction.
- **BE-RECEIVE-09 (P0):** Transaksi accepted ditolak seluruhnya bila berat aktual membuat total melampaui kapasitas.
- **BE-RECEIVE-10 (P0):** Ketika berat aktual membuat kapasitas tepat penuh, semua booking `waiting` lain dibatalkan dalam transaction yang konsisten dan booking baru berikutnya ditolak.
- **BE-RECEIVE-11 (P0):** Rejected reception tidak menambah `received_weight_grams`.
- **BE-RECEIVE-12 (P0):** Retry penerimaan dengan idempotency key yang sama tidak menggandakan reception atau berat.
- **BE-RECEIVE-13 (P0):** Keputusan final, actor, dan waktu server dicatat dalam audit event kecuali data tersebut kemudian masuk kebijakan retensi.

### 9.8 Rekap dan CSV

- **BE-REPORT-01 (P0):** Total kilogram memakai jumlah berat aktual booking `accepted`, bukan estimasi donor.
- **BE-REPORT-02 (P0):** Donor unik dihitung satu kali per event berdasarkan deterministic phone lookup hash, bukan nama.
- **BE-REPORT-03 (P0):** Rekap dapat difilter berdasarkan event dan rentang waktu dalam tenant Pengelola.
- **BE-REPORT-04 (P0):** CSV memuat booking ID, nama event, waktu booking, status, estimasi berat donor, berat aktual, kondisi, alasan penolakan, metode pengiriman, nama donor, dan nomor telepon donor.
- **BE-REPORT-05 (P0):** Export memerlukan session Pengelola dan tidak menerima `workspace_id` sebagai authorization source.
- **BE-REPORT-06 (P0):** CSV menggunakan UTF-8, header stabil, escaping RFC 4180, dan mitigasi CSV formula injection untuk value donor yang diawali karakter formula.
- **BE-REPORT-07 (P0):** Export yang besar di-stream atau dibuat sementara dan memiliki URL berumur pendek; file tidak menjadi object publik permanen.
- **BE-REPORT-08 (P0):** Aggregate non-PII mempertahankan total berat diterima setelah PII dan booking mentah melewati retensi.

### 9.9 Banner storage

- **BE-STORAGE-01 (P0):** Storage hanya menerima banner event; foto pakaian dilarang.
- **BE-STORAGE-02 (P0):** Upload memerlukan session Pengelola dan path object dipisah per workspace.
- **BE-STORAGE-03 (P0):** Policy write/update/delete memastikan hanya owner workspace yang dapat mengubah banner.
- **BE-STORAGE-04 (P0):** Banner boleh dibaca publik karena tampil pada App Clip, tetapi object tidak boleh berisi PII.
- **BE-STORAGE-05 (P0):** Backend memvalidasi MIME type, ukuran maksimum, dan dimensi yang ditetapkan implementasi sebelum publish.
- **BE-STORAGE-06 (P1):** Object banner yang tidak lagi direferensikan dibersihkan oleh lifecycle job setelah grace period.

### 9.10 Scheduled jobs

- **BE-JOB-01 (P0):** Job lifecycle berjalan sedikitnya setiap menit untuk memajukan `upcoming` menjadi `ongoing` dan event berakhir menjadi `completed`.
- **BE-JOB-02 (P0):** Job expiry mengubah booking `waiting` menjadi `expired` ketika `expires_at <= now()`.
- **BE-JOB-03 (P0):** Completion event memastikan booking `waiting` yang tersisa menjadi `expired`, bukan accepted/rejected.
- **BE-JOB-04 (P0):** Close/cancel dan full-capacity cancellation dilakukan sinkron dalam mutation terkait; Cron hanya menjadi reconciliation safety net.
- **BE-JOB-05 (P0):** Retention job harian menghapus atau menganonimkan data donor/booking satu bulan setelah event terminal.
- **BE-JOB-06 (P0):** Audit event dihapus satu bulan setelah audit dibuat.
- **BE-JOB-07 (P0):** Aggregate non-PII diperbarui sebelum raw data yang diperlukan dihapus.
- **BE-JOB-08 (P0):** Job bersifat idempotent, aman dijalankan ulang, dan menyimpan hasil run tanpa PII untuk observability.
- **BE-JOB-09 (P0):** Kegagalan atau backlog job menghasilkan alert operasional.

### 9.11 Offline sync

- **BE-SYNC-01 (P0):** Backend menyediakan query incremental event berdasarkan server `updated_at`/version untuk memperbarui cache SwiftData.
- **BE-SYNC-02 (P0):** Draf offline disinkronkan melalui idempotent upsert yang tervalidasi setelah koneksi kembali.
- **BE-SYNC-03 (P0):** Last-write-wins didefinisikan sebagai commit Draf terbaru yang diterima server; `updated_at` diberikan server agar tidak bergantung pada jam perangkat.
- **BE-SYNC-04 (P0):** Klien harus menyimpan mutation ID unik agar retry sync tidak menggandakan event.
- **BE-SYNC-05 (P0):** Publish, booking, QR validation, accepted, dan rejected tidak memiliki offline queue.
- **BE-SYNC-06 (P0):** Data cache yang sudah melewati authorization atau retention dihapus pada sync/logout berikutnya.

### 9.12 Error contract

- **BE-ERROR-01 (P0):** Semua endpoint mengembalikan correlation/request ID.
- **BE-ERROR-02 (P0):** Error mempunyai stable machine code, HTTP status yang sesuai, dan field-level detail hanya bila aman.
- **BE-ERROR-03 (P0):** Backend tidak mengembalikan stack trace, SQL text, secret, atau detail tenant lain.
- **BE-ERROR-04 (P0):** Copy Bahasa Indonesia dibuat di klien berdasarkan machine code; backend tidak menjadikan kalimat error sebagai contract.
- **BE-ERROR-05 (P0):** Error retryable dan non-retryable dapat dibedakan klien.

## 10. Data Model

Nama tabel/field berikut adalah kontrak konseptual. Migration dapat menyesuaikan penamaan selama semantik, constraint, dan access boundary tetap sama.

### 10.1 `profiles`

| Field | Aturan |
|---|---|
| `id` | UUID yang mengacu ke user Supabase Auth |
| `display_name` | Nama Pengelola |
| `created_at`, `updated_at` | Timestamp server |

Tidak menyimpan password atau token provider.

### 10.2 `workspaces`

| Field | Aturan |
|---|---|
| `id` | UUID primary key |
| `owner_user_id` | Unique; satu Pengelola per workspace pada MVP |
| `name` | Nama tampilan Pengelola/organisasi |
| `status` | `active` atau status operasional platform |
| `created_at`, `updated_at` | Timestamp server |

### 10.3 `events`

| Kelompok field | Isi utama |
|---|---|
| Identity | `id`, `workspace_id`, `name`, `description` |
| Lifecycle | `status`, `published_at`, `terminal_at`, `created_at`, `updated_at`, `version` |
| Time | `start_at`, `end_at`, `timezone_name` |
| Schedule | hari operasional, jam buka lokal, jam tutup lokal |
| Location | alamat, latitude, longitude |
| Capacity | `capacity_grams`, `received_weight_grams` |
| Media | `banner_object_path` |
| Receiver | nama penerima, telepon penerima, alamat penerima |

Constraint minimum:

- kapasitas dan berat diterima menggunakan integer gram dan tidak negatif;
- `received_weight_grams <= capacity_grams`;
- `start_at < end_at`;
- jam buka sebelum jam tutup sesuai definisi satu hari operasional MVP;
- event terminal immutable melalui trigger/function authorization;
- publish fields lengkap;
- aktivasi event keenam ditolak atomik.

### 10.4 `event_criteria`

Satu row per kriteria event dengan unique `(event_id, criterion_code)`. Kode MVP:

- `cotton`
- `linen`
- `rayon`
- `wool`
- `tencel`
- `silk`
- `non_stretch`
- `denim`
- `no_lace`
- `polyester`

### 10.5 `event_invocations`

| Field | Aturan |
|---|---|
| `event_id` | Event yang diterbitkan |
| `token_hash` | Hash opaque token untuk public lookup |
| `token_ciphertext` | Token terenkripsi untuk membentuk ulang share URL bagi owner; tidak dapat dibaca melalui Data API |
| `environment` | Staging atau production |
| `revoked_at` | Nullable |
| `created_at` | Timestamp server |

### 10.6 `bookings`

| Kelompok field | Isi utama |
|---|---|
| Identity | UUID internal, public booking ID, `event_id`, `workspace_id` |
| Donor protected data | encrypted name, encrypted normalized phone, deterministic phone lookup hash |
| Donation | estimated weight grams, item count, shipping method, scan model version |
| Lifecycle | status, terminal reason code, created at, expires at, terminal at |
| Consent | terms version, privacy version, accepted at |
| Snapshot | immutable versioned JSON/record untuk event, receiver, location, schedule, criteria, instruction |
| QR | token hash untuk validasi dan encrypted replay material untuk idempotent response/label recovery |

Public booking ID harus mudah dibaca tetapi tidak menjadi satu-satunya kredensial keamanan. Phone lookup hash menggunakan keyed HMAC yang hanya dihitung server. PII dan token material yang perlu dipulihkan disimpan terenkripsi menggunakan key yang dikelola di secret server. Token plaintext tidak boleh dapat dibaca melalui Data API atau log.

### 10.7 `booking_items`

Menyimpan item yang benar-benar ikut dalam booking:

- booking ID;
- ordinal/item ID;
- final status yang wajib lolos pemeriksaan awal;
- scanner model/version;
- metadata nonfoto minimum yang disetujui.

Tabel tidak memiliki URL foto, binary, embedding, EXIF, atau histori retry scan.

### 10.8 `receptions`

| Field | Aturan |
|---|---|
| `booking_id` | Unique; mencegah keputusan kedua |
| `workspace_id`, `event_id` | Untuk authorization dan query |
| `decision` | `accepted` atau `rejected` |
| `actual_weight_grams` | Integer positif hasil timbang |
| `condition` | Lima vocabulary kondisi MVP |
| `rejection_reason` | Nullable preset |
| `rejection_note` | Nullable text |
| `processed_by` | User ID Pengelola |
| `processed_at` | Timestamp server |

### 10.9 `idempotency_keys`

Menyimpan scope actor/endpoint, actor scope, key, request hash, status, response reference, serta
expiry. Unique constraint pada `(scope, actor_scope, key)` memastikan retry actor yang sama tidak
menghasilkan mutation ganda tanpa memblokir actor scope lain.

### 10.10 `legal_document_versions`

Menyimpan document type, version identifier, public URL, published timestamp, dan status aktif untuk Syarat & Ketentuan serta Kebijakan Privasi. Hanya satu version aktif per document type/environment. Booking menyimpan version identifier yang disetujui, bukan salinan penuh dokumen.

### 10.11 `audit_events`

Menyimpan actor type/ID, workspace, entity type/ID, action code, timestamp server, request ID, serta metadata non-PII minimum. Audit donor deletion tidak diwajibkan memuat alasan, waktu khusus, atau identitas penghapus sebagaimana keputusan produk; log infrastruktur umum tetap boleh mencatat request secara terbatas sesuai kebijakan keamanan.

### 10.12 `impact_aggregates`

Menyimpan metric non-PII per workspace/event/periode, minimal:

- total accepted weight grams;
- accepted booking count;
- rejected booking count;
- unique donor count per event;
- completed event count.

Aggregate ini boleh bertahan setelah raw donor/booking dihapus dan menjadi sumber north-star metric historis.

### 10.13 `job_runs`

Menyimpan nama job, waktu mulai/selesai, status, jumlah row diproses, error code ringkas, dan correlation ID tanpa PII.

### 10.14 Indeks minimum

- unique index untuk owner workspace, public booking ID, QR token hash, invocation token hash, dan reception per booking;
- composite index event pada `(workspace_id, status, start_at, end_at)`;
- composite index booking pada `(event_id, status, expires_at)`;
- composite index booking pada `(workspace_id, created_at)` untuk rekap/pagination;
- index donor matching pada `(event_id, phone_lookup_hash)`;
- index retention pada event terminal timestamp dan audit `created_at`;
- unique composite index idempotency pada `(scope, actor_scope, key)`.

Index final divalidasi dengan query plan dari pola akses nyata dan tidak ditambah hanya berdasarkan dugaan.

## 11. State Machines

### 11.1 Event

```text
draft
  └─ publish ──> upcoming ── waktu mulai ──> ongoing ── waktu selesai ──> completed
                    │                         │
                    ├─ close ───────────────> closed
                    ├─ cancel ──────────────> cancelled
                    ├─────────────────────────┘
                    └─ bila waktu mulai sudah lewat saat publish: ongoing
```

Aturan:

- `completed`, `closed`, dan `cancelled` terminal serta read-only;
- publish adalah action, bukan status;
- close/cancel membatalkan booking Menunggu;
- completion membuat booking Menunggu kedaluwarsa;
- tidak ada reopen.

### 11.2 Booking

```text
waiting
  ├─ accepted
  ├─ rejected
  ├─ expired
  └─ cancelled
```

Semua status selain `waiting` terminal. Tidak ada `in_transit`, partial acceptance, atau transisi balik.

## 12. API dan Operation Contracts

Endpoint dapat diwujudkan sebagai Edge Function, authenticated Data API query, atau RPC. Nama URL final boleh berubah; semantics berikut wajib stabil.

### 12.1 Public/App Clip

#### Resolve event

- **Method:** `GET`
- **Input:** opaque invocation token dan environment context.
- **Output:** public event DTO, availability, reason code, server time, cache metadata.
- **Tidak boleh memuat:** donor data, internal workspace data, raw capacity transaction, atau secret receiver fields di luar yang memang ditampilkan donor.

#### Create booking

- **Method:** `POST`
- **Header wajib:** idempotency key.
- **Input:** invocation token, donor data, estimated weight, final items, shipping method, consent versions.
- **Output sukses:** booking ID, QR token/payload, expiry, immutable label snapshot.
- **Efek:** satu booking `waiting`; tidak mengubah kapasitas.

#### Verify donor booking

- **Method:** `POST`
- **Input:** booking ID dan nomor telepon Indonesia.
- **Output sukses:** short-lived single-booking access token.
- **Output gagal:** generic invalid-credentials result.

#### Get donor booking status

- **Method:** `GET`
- **Auth:** short-lived single-booking token.
- **Output:** status, event summary, expiry/processed time, kondisi dan alasan yang diizinkan.

### 12.2 Authenticated Pengelola

#### Event query

- List/detail dengan filter status dan pagination.
- Query memakai JWT + RLS.
- Mendukung incremental sync menggunakan cursor/version server.

#### Create/update Draf

- Idempotent mutation ID.
- Server timestamp dan version dikembalikan.
- Upsert offline mengikuti latest server commit wins.

#### Publish event

- Menjalankan validasi lengkap dan batas lima event aktif dalam transaction.
- Membuat/mengaktifkan invocation token.
- Mengembalikan status `upcoming` atau `ongoing`.

#### Edit event

- Menolak event terminal.
- Menolak kapasitas di bawah berat diterima.
- Tidak mengubah snapshot booking lama.

#### Close/cancel event

- Menjadikan event terminal.
- Membatalkan booking Menunggu secara atomik.

#### Resolve QR

- Input opaque QR token.
- Hanya menampilkan booking tenant sendiri.
- Tidak melakukan mutation.

#### Accept/reject booking

- Header idempotency key wajib.
- Menjalankan PostgreSQL transaction penerimaan.
- Mengembalikan status final, berat event terbaru, dan apakah kapasitas penuh.

#### Recap

- Query berdasarkan workspace, event, dan rentang tanggal.
- Mengembalikan berat aktual, donor unik, jumlah status, dan event count.

#### CSV export

- Authenticated dan tenant-scoped.
- Mengikuti filter yang sama dengan recap.
- Tidak disimpan permanen pada public storage.

#### Delete donor data

- Hanya untuk booking/event tenant sendiri.
- Menghapus atau menganonimkan PII dan token lookup.
- Mempertahankan aggregate non-PII yang dibutuhkan laporan.

## 13. Critical Transaction Specifications

### 13.1 Create booking

1. Validasi format request dan batas ukuran payload.
2. Terapkan rate limit.
3. Klaim idempotency key dan bandingkan request hash.
4. Resolve invocation token.
5. Kunci/read event secara konsisten.
6. Rekonsiliasi status berdasarkan waktu server.
7. Pastikan event menerima booking dan belum penuh.
8. Normalisasi/proteksi PII donor.
9. Hitung `expires_at`.
10. Salin immutable event snapshot.
11. Buat booking, final item records, QR token hash, dan encrypted replay material.
12. Simpan idempotency result yang dapat mengembalikan response identik pada retry sah.
13. Commit lalu kembalikan plaintext QR token untuk rendering label.

### 13.2 Accept booking

1. Validasi JWT, tenant, idempotency key, berat, dan kondisi.
2. Kunci booking dan event dalam urutan konsisten.
3. Rekonsiliasi event serta booking berdasarkan waktu server.
4. Pastikan booking `waiting`, event operasional, dan booking milik workspace.
5. Pastikan `received_weight_grams + actual_weight_grams <= capacity_grams`.
6. Buat reception accepted yang unique terhadap booking.
7. Ubah booking menjadi `accepted`.
8. Tambah berat event dan aggregate impact.
9. Jika kapasitas tepat penuh, ubah seluruh booking `waiting` lain menjadi `cancelled`.
10. Tulis audit event dan idempotency result.
11. Commit.

Database lock/constraint menjadi perlindungan utama. Edge Function hanya mengorkestrasi dan tidak menggantikan transaction database.

### 13.3 Reject booking

1. Validasi JWT, tenant, idempotency, berat, kondisi, dan optional reason.
2. Kunci booking dan pastikan masih `waiting`.
3. Buat reception rejected yang unique terhadap booking.
4. Ubah booking menjadi `rejected` tanpa mengubah kapasitas.
5. Tulis audit dan idempotency result.
6. Commit.

### 13.4 Close/cancel event

1. Validasi owner dan event nonterminal.
2. Kunci event.
3. Ubah event ke status terminal yang diminta.
4. Batalkan seluruh booking `waiting`.
5. Bekukan aggregate/event fields yang diperlukan.
6. Tulis audit.
7. Commit.

## 14. Authorization dan RLS Matrix

| Resource | Donor publik | Donor verified booking | Pengelola tenant | Scheduled/service worker |
|---|---:|---:|---:|---:|
| Public event DTO | Resolve function | Read | Read own | Read |
| Raw event row | Tidak | Tidak | CRUD own sesuai lifecycle | Terbatas |
| Booking create | Edge Function saja | Tidak | Tidak diperlukan | Tidak |
| Booking detail | Tidak | Satu booking | Own workspace | Terbatas |
| Donor PII | Tidak | Data sendiri minimum | Own workspace | Hanya retention/report task |
| Reception | Tidak | Status sendiri minimum | Create/read own | Terbatas |
| Audit | Tidak | Tidak | Read own bila fitur tersedia | Write/cleanup |
| Banner write | Tidak | Tidak | Own workspace | Cleanup |
| Aggregate | Tidak | Tidak | Own workspace | Update/cleanup |

Setiap policy diuji dengan positive dan negative cross-tenant cases. Service role tidak dianggap otomatis aman; function yang memakainya wajib memvalidasi actor dan scope sendiri.

## 15. Privacy, Security, dan Retention

### 15.1 Data classification

| Kelas | Contoh | Perlakuan |
|---|---|---|
| PII | Nama donor, nomor telepon | Access terbatas, encrypted/protected, redacted dari log, retention satu bulan setelah event terminal |
| Sensitive operational | Booking, QR token, receiver contact | Tenant-scoped, token di-hash, tidak masuk analytics mentah |
| Public | Nama/deskripsi event, banner, lokasi, kriteria | Hanya event diterbitkan; tetap divalidasi |
| Ephemeral local only | Foto pakaian | Tidak pernah dikirim ke backend |
| Aggregate non-PII | Total gram diterima | Boleh dipertahankan setelah raw retention |

### 15.2 Retention rules

- Data donor dan booking mentah dihapus atau dianonimkan satu bulan setelah event menjadi `completed`, `closed`, atau `cancelled`.
- Audit events dihapus satu bulan setelah dibuat.
- Manual deletion oleh Pengelola boleh terjadi sebelum jadwal retention.
- Penghapusan PII juga menonaktifkan donor lookup dan token terkait.
- Aggregate non-PII dibuat sebelum penghapusan.
- Backup mengikuti lifecycle provider; akses backup dibatasi operator dan kebijakan produksi harus mendokumentasikan kemungkinan PII tetap berada sementara dalam backup terenkripsi sampai backup rotation.

### 15.3 Logging rules

Log tidak boleh memuat:

- nama atau nomor telepon donor;
- QR token plaintext;
- authorization header/JWT;
- event receiver phone bila tidak diperlukan;
- request body utuh;
- foto, path foto, embedding, atau EXIF.

Log boleh memuat request ID, hashed entity reference, error code, duration, environment, function version, dan outcome agregat.

### 15.4 Abuse protection

- Rate limit resolve, create booking, dan donor lookup.
- Batas ukuran request dan panjang semua text.
- Generic authentication errors.
- Idempotency untuk mutation yang dapat di-retry.
- QR dan invocation token dihasilkan dengan cryptographically secure random source.
- Secret rotation procedure sebelum production.
- Dependency dan migration review dalam CI.

## 16. Non-Functional Requirements

### 16.1 Scale baseline

- 50 workspace Pengelola pada pilot.
- Maksimum lima event aktif per workspace.
- Baseline 1.000 booking per hari di seluruh platform.
- Schema, index, dan load test tidak boleh bergantung pada scan penuh tabel untuk request kritis.
- Uji concurrency wajib mencakup beberapa penerimaan terhadap sisa kapasitas yang sama.

### 16.2 Performance targets

Target engineering awal pada koneksi backend normal, tidak termasuk waktu upload banner atau kualitas jaringan perangkat:

- p95 resolve event ≤ 800 ms;
- p95 create booking ≤ 1.500 ms;
- p95 resolve QR ≤ 800 ms;
- p95 accept/reject ≤ 1.500 ms;
- p95 dashboard query ≤ 1.500 ms;
- export CSV pilot selesai ≤ 30 detik.

Angka ini adalah guardrail engineering MVP, bukan target bisnis.

### 16.3 Availability dan recovery

- Production tidak bergantung pada project free-tier yang dapat mengalami pembatasan atau pause.
- Backup database production aktif sesuai kemampuan plan yang dipilih.
- Baseline recovery pilot: RPO maksimum 24 jam dan RTO maksimum 8 jam.
- Restore procedure diuji sebelum production dan setelah perubahan besar pada schema/backup policy.
- Edge Function failure tidak boleh meninggalkan partial commit.

### 16.4 Consistency

- Capacity, booking state, dan reception menggunakan strong transactional consistency.
- Dashboard dapat memakai cached/read replica semantics hanya jika UI menandai refresh dan tidak dipakai mengambil keputusan penerimaan.
- Status donor berasal dari database, bukan state lokal App Clip.

### 16.5 Accessibility dan localization boundary

Backend mengembalikan stable code serta structured values. Copy Bahasa Indonesia, format kilogram, tanggal, dan waktu ditangani klien menggunakan locale Indonesia dan timezone event.

## 17. Observability dan Operasional

### 17.1 Metrics minimum

- request count, latency p50/p95/p99, dan error rate per endpoint;
- create booking success/rejection berdasarkan safe reason code;
- donor lookup success/rate-limit count tanpa PII;
- accept/reject count;
- capacity conflict/rejection count;
- event lifecycle dan booking expiry backlog;
- retention rows processed/failed;
- RLS/authorization denial count;
- storage upload failure;
- database connection dan function error;
- north-star total accepted weight dari aggregate non-PII.

### 17.2 Alerts minimum

- scheduled job gagal atau tidak berjalan sesuai interval;
- backlog expired booking/event lifecycle melewati ambang operasional;
- error rate endpoint kritis meningkat;
- p95 latency melampaui target secara berkelanjutan;
- database/storage mendekati quota;
- invariant `received_weight_grams > capacity_grams` terdeteksi;
- retention gagal beberapa run berturut-turut.

### 17.3 Runbook minimum

- rollback migration/Edge Function;
- rotate leaked secret;
- replay job idempotent;
- restore database;
- revoke invocation atau QR token;
- investigate capacity mismatch;
- respond to PII exposure;
- disable public booking sementara tanpa mematikan read-only event context.

## 18. Environment dan Delivery

### 18.1 Environment

1. **Local/CI:** Supabase CLI/local stack untuk CI dan integration test yang membutuhkan database lokal.
   Development Mac yang diarahkan ke hosted staging tidak perlu menjalankan Supabase Docker lokal.
2. **Staging:** hosted Supabase project terpisah, data non-production, dipakai untuk verifikasi
   konfigurasi dan target TestFlight/App Clip staging. Current target: `kumpul-staging`, ref
   `tdpvtdblphojutjifdlc`.
3. **Production:** hosted Supabase project terpisah dengan secret, Auth config, storage, domain,
   backup, monitoring, dan evidence release sendiri. Production belum dianggap provisioned hanya
   karena staging sehat.

Database, storage bucket, redirect URL, Apple Auth credential, signing-related URL, dan Edge secret tidak dibagi antara staging dan production.

### 18.2 Region

Production memakai region Supabase yang paling dekat dan tersedia untuk mayoritas pengguna Indonesia. Pemilihan region dicatat sebelum provisioning production karena perpindahan region setelah data operasional masuk membutuhkan migration plan.

### 18.3 Migrations

- Semua schema, enum, function, trigger, RLS policy, index, seed vocabulary, dan Cron setup dikelola sebagai migration versioned.
- Perubahan dilakukan local → staging → production.
- Production migration harus backward-compatible dengan versi aplikasi yang masih aktif bila memungkinkan.
- Destructive migration memerlukan backup dan rollback/forward-fix plan.
- Manual schema change dari dashboard production dilarang kecuali incident response dan harus segera direkonsiliasi menjadi migration.

### 18.4 Secrets

- Secret hanya disimpan pada environment secret manager/provider settings.
- Repository hanya memuat nama konfigurasi/example tanpa value production.
- Aplikasi menerima URL dan publishable/anon key per build configuration.
- Service role, PII encryption/HMAC key, dan third-party credentials hanya tersedia server-side.

## 19. Deep Modules

### 19.1 `AuthSession`

Interface sederhana untuk sign-in, sign-out, session refresh, dan account linking tanpa membocorkan Supabase Auth ke UI.

### 19.2 `WorkspaceAuthorization`

Menentukan tenant dari actor terautentikasi. Menjadi satu-satunya sumber workspace untuk mutation/report dan tidak mempercayai body request.

### 19.3 `EventDomain`

Mengenkapsulasi validasi Draf/publish, status transition, active-event limit, editability, timezone, schedule, dan kapasitas minimum.

### 19.4 `InvocationResolver`

Mengubah opaque token menjadi public event context dan availability reason tanpa membuka raw table.

### 19.5 `BookingService`

Mengenkapsulasi normalization, consent, item validation, expiry, immutable snapshot, identifier/token, dan idempotent create.

### 19.6 `CapacityLedger`

Interface atomik untuk menerima booking, menolak overflow, memperbarui aggregate, dan membatalkan booking lain ketika penuh. Implementasinya berada pada PostgreSQL transaction/function.

### 19.7 `ReceptionService`

Mengenkapsulasi QR resolution, whole-booking decision, kondisi, optional rejection reason, audit, dan idempotency.

### 19.8 `DonorAccess`

Memverifikasi booking ID + phone, menerapkan rate limit, dan menerbitkan scoped short-lived access token.

### 19.9 `RetentionEngine`

Menentukan row eligible untuk anonymization/deletion, menjaga aggregate non-PII, dan menghasilkan observable idempotent job result.

### 19.10 `ReportExporter`

Menjalankan query tenant-scoped, donor unique calculation, stable CSV schema, escaping, dan formula-injection protection.

### 19.11 `DraftSync`

Mengenkapsulasi mutation ID, server version, incremental pull, dan latest server commit wins untuk Draf SwiftData.

## 20. Implementation Plan

### Phase 0 — Foundation

- Provision local dan staging Supabase.
- Tambahkan migration baseline, enum, vocabulary, extension yang diperlukan, dan seed development.
- Konfigurasikan environment/secrets.
- Bangun test harness database dan Edge Functions.
- Tetapkan API error envelope, request ID, dan idempotency contract.

### Phase 1 — Auth, tenant, dan event

- Supabase Auth Sign in with Apple serta email/password.
- Profile/workspace bootstrap.
- RLS tenant isolation.
- Event CRUD, publish, lifecycle, active-event limit, timezone, dan schedule.
- Banner storage.
- Cache query serta Draf sync.

### Phase 2 — App Clip dan booking

- Invocation token dan resolver.
- Public event DTO.
- Create booking transaction, protected PII, consent, snapshot, booking ID, QR token, dan idempotency.
- Donor verified lookup/status.
- Booking expiry Cron.

### Phase 3 — Reception, capacity, dan reports

- QR resolve.
- Accept/reject transaction.
- Hard capacity dan full-capacity cancellation.
- Dashboard aggregates.
- Recap dan CSV export.

### Phase 4 — Retention dan production hardening

- Retention/anonymization jobs.
- Audit cleanup.
- Metrics, alerts, runbooks, backup/restore test.
- Load, concurrency, abuse, security, and privacy tests.
- Production project, Auth redirect/domain, App Clip invocation, dan TestFlight staging E2E.

## 21. Testing Decisions

### 21.1 Prinsip

- Test memverifikasi behavior dan contract eksternal, bukan detail internal function.
- Semua invariant penting dibuktikan di level database/integration, bukan hanya mock unit test klien.
- RLS dites dengan user/tenant nyata yang berbeda.
- Edge Function dites terhadap database staging/local dan negative abuse cases.
- Test tidak memasukkan PII nyata atau foto donor.
- Waktu dikontrol pada test lifecycle agar tidak bergantung pada wall clock.

### 21.2 Unit/domain tests wajib

- Event validation dan lifecycle.
- Active-event limit.
- Timezone dan schedule mapping.
- Phone normalization Indonesia.
- Booking expiry calculation.
- Snapshot immutability.
- Error mapping.
- CSV escaping/formula mitigation.
- Retention eligibility.
- Draft sync conflict policy.

Scanner Policy dan Donation Flow tetap dites di codebase iOS sesuai PRD induk; backend hanya dites untuk final payload contract dan larangan foto.

### 21.3 Database/integration tests wajib

1. Signup membuat tepat satu workspace.
2. User A tidak dapat membaca atau mengubah row User B pada seluruh tabel/bucket.
3. Publish tanpa field wajib ditolak.
4. Event aktif keenam ditolak pada concurrency.
5. Publish langsung menghasilkan upcoming/ongoing sesuai waktu server.
6. Cron/reconciliation menghasilkan completed pada end time.
7. Event terminal menolak mutation.
8. Edit event tidak mengubah snapshot booking.
9. Kapasitas tidak dapat diturunkan di bawah berat diterima.
10. Create booking idempotent pada retry dan menolak payload berbeda dengan key sama.
11. Booking tidak mengubah kapasitas.
12. Booking expiry memakai min(12 jam, event end).
13. Public request tidak dapat menyisipkan workspace/event lain.
14. Request booking yang memuat foto/binary field ditolak.
15. Dua accept concurrent terhadap sisa kapasitas tidak dapat membuat overflow.
16. Accept yang tepat memenuhi kapasitas membatalkan booking Menunggu lainnya.
17. Accept/reject retry tidak membuat reception kedua.
18. Partial reception tidak dapat direpresentasikan.
19. Rejected tidak mengubah kapasitas.
20. Invalid/expired/cancelled/used QR tidak dapat diproses.
21. Donor lookup salah memberi response generik dan terkena rate limit.
22. Single-booking token tidak dapat membaca booking lain.
23. Close/cancel membatalkan booking Menunggu atomik.
24. CSV hanya memuat tenant/filter yang diminta dan kolom yang disetujui.
25. CSV input formula berbahaya dinetralisasi.
26. Retention menghapus/menganonimkan PII dan raw booking yang eligible.
27. Aggregate kilogram tetap benar setelah retention.
28. Audit cleanup memakai umur satu bulan sejak audit dibuat.
29. Job aman dijalankan ulang.
30. Draf retry tidak membuat event duplikat dan latest server commit wins.

### 21.4 Load dan resilience tests

- Baseline 1.000 booking/hari dengan burst di atas pola rata-rata.
- Resolve invocation dan create booking secara paralel.
- Hot event dengan beberapa accept request pada kapasitas yang sama.
- Cron catch-up setelah job terlambat.
- Edge Function timeout sebelum dan sesudah database commit.
- Storage upload gagal/retry.
- Database connection transient failure.
- Export CSV pada volume pilot maksimum yang realistis.

### 21.5 Security tests

- RLS cross-tenant matrix.
- Service-role endpoint authorization bypass attempt.
- Booking enumeration dan donor lookup brute force.
- QR/invocation token guessing.
- Expired JWT dan donor scoped token.
- Malformed JSON, oversized payload, SQL/meta-character input, dan Unicode edge cases.
- Secret/PII redaction pada logs dan error response.
- Storage content type dan path traversal/prefix isolation.

## 22. Acceptance Criteria

Backend MVP dianggap selesai ketika seluruh kondisi berikut terpenuhi:

1. Pengelola dapat self-register dan login dengan kedua metode auth yang ditetapkan.
2. Setiap Pengelola hanya dapat mengakses workspace sendiri dan negative cross-tenant tests lulus.
3. Event CRUD/publish/edit/close/cancel tersimpan persisten dan mengikuti lifecycle final.
4. Batas lima event aktif ditegakkan atomik.
5. Event selesai otomatis dan booking expiry berjalan dari waktu server.
6. App Clip resolve membuka event yang benar dan tidak mengekspos data private.
7. Booking publik tervalidasi, rate-limited, idempotent, menyimpan snapshot, dan tidak mengubah kapasitas.
8. Tidak ada foto atau histori scan yang digantikan di request, database, storage, analytics, atau logs.
9. Donor dapat melihat satu booking miliknya dengan booking ID + phone tanpa enumerasi yang mudah.
10. QR opaque dapat divalidasi Pengelola pemilik event.
11. Accept/reject bersifat whole-booking, online, idempotent, dan atomik.
12. Tidak ada concurrency path yang dapat membuat berat diterima melampaui kapasitas.
13. Kapasitas penuh membatalkan booking Menunggu lain dan menolak booking baru.
14. Dashboard/recap memakai berat aktual dan donor unik per event.
15. CSV tenant-scoped berisi kolom yang disetujui serta aman dari formula injection.
16. Draf offline dapat disinkronkan dengan policy latest server commit wins; operasi online-only tidak masuk queue.
17. Retention satu bulan dan aggregate non-PII berjalan serta teruji.
18. Metrics, alert, backup, restore procedure, dan runbook minimum tersedia.
19. Local dan staging integration suite lulus; TestFlight menjalankan E2E terhadap backend staging.
20. Production tidak memakai secret staging, free-tier yang dapat pause, atau service key di aplikasi.

### 22.1 Status verifikasi saat ini

Item 1–17 memiliki implementasi source dan test harness lokal yang sesuai, tetapi tidak semuanya
dianggap release evidence sampai integration/E2E test yang relevan dijalankan. Hosted staging
sudah diverifikasi memiliki 10 migration, 11 Edge Function aktif, 14/14 tabel publik dengan RLS,
scheduled jobs aktif, dan health snapshot tanpa backlog atau capacity invariant violation.

Item 18–20 masih merupakan release gate: alert provider, backup/restore drill, production project,
dan TestFlight/App Clip E2E belum dibuktikan oleh dokumen ini. Account linking pada BE-AUTH-05
tetap pending dan tidak boleh dianggap bagian dari acceptance MVP saat ini.

## 23. Risks dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Service key masuk aplikasi | Seluruh RLS dapat dilewati | Hanya publishable/anon key di client, secret scanning, binary/config audit |
| Policy RLS salah | Kebocoran lintas-Pengelola | Default deny, policy terpisah, cross-tenant integration suite |
| Public App Clip disalahgunakan | Spam booking/enumeration | Edge Function, rate limit, idempotency, opaque token, generic error |
| Capacity race | Berat melebihi batas | Row lock, constraint, satu PostgreSQL transaction, concurrency test |
| Cron terlambat | Status event/booking stale | Reconcile pada read/mutation, idempotent catch-up, alert backlog |
| Phone lookup lemah | Booking donor dapat diakses pihak lain | Booking ID entropy, HMAC lookup, rate limit, scoped short-lived token |
| Retention merusak metrik | North-star history hilang | Materialize aggregate non-PII sebelum raw deletion |
| PII muncul di log/CSV sementara | Kebocoran data | Structured redacted logs, short-lived export, access audit, no public file |
| Draf lama sync belakangan | Perubahan lebih baru tertimpa | Policy latest server commit yang eksplisit, version display, idempotent mutation |
| Vendor lock-in Supabase | Migrasi mahal | Domain repository boundary, versioned SQL migrations, standard PostgreSQL |
| Satu region jauh dari pengguna | Latency App Clip tinggi | Pilih region terdekat Indonesia dan ukur p95 dari jaringan nyata |
| Free-tier pause/quota | Pilot terhenti | Production plan berbayar dan quota alerts |

## 24. Out of Scope

- CloudKit sync atau replication.
- Firebase mirror.
- Multi-region active-active.
- Custom Kubernetes/backend server.
- Web admin dan super-admin product UI.
- SMS/WhatsApp verification atau notification.
- Real-time courier status.
- Online payment.
- Raw image/object storage untuk pakaian.
- ML training pipeline cloud.
- Long-term raw donor history setelah retention.
- Multi-organizer membership dalam satu workspace.

## 25. Definition of Ready untuk Implementasi

Implementasi dapat dimulai menggunakan keputusan dalam dokumen ini tanpa pertanyaan produk tambahan. Sebelum production release, tim pembuat aplikasi tetap harus menghasilkan artefak operasional berikut:

- naskah Syarat & Ketentuan serta Kebijakan Privasi dengan version identifier;
- hosted staging dan production Supabase project;
- Sign in with Apple configuration per environment;
- domain dan associated App Clip routing per environment;
- secret management serta rotation owner;
- batas ukuran/dimensi banner berdasarkan budget App Clip dan desain final;
- retention/privacy disclosure yang selaras dengan perilaku backup provider;
- dashboard alert dan incident contact;
- backup/restore runbook yang telah diuji.

Butir tersebut merupakan pekerjaan implementasi/release, bukan pertanyaan ulang terhadap keputusan produk yang telah diselesaikan.

## 26. Referensi Teknis Resmi

- [Supabase Auth — Sign in with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Supabase Database Functions](https://supabase.com/docs/guides/database/functions)
- [Supabase Cron](https://supabase.com/docs/guides/cron)
- [Supabase Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control)
- [Supabase Local Development and CLI](https://supabase.com/docs/guides/local-development)

Dokumentasi resmi menjadi referensi API/platform. Aturan bisnis, lifecycle, retention, dan acceptance criteria .kumpul tetap mengikuti dokumen ini serta PRD produk induk.
