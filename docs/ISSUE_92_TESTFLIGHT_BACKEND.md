# Issue #92: konfigurasi backend dan gate TestFlight

## Kontrak release

| Lane | Xcode | Environment | Backend | Bundle ID |
| --- | --- | --- | --- | --- |
| `beta` | `Release` | `production` | Project ref pada `KUMPUL_PRODUCTION_PROJECT_REF` | `com.academy.hendraaaa.happyFamily` |
| `staging_beta` | `Staging` | `staging` | `tdpvtdblphojutjifdlc` | `com.academy.hendraaaa.happyFamily.staging` |

Push `main` dan tag `v*` tetap memilih `beta`. `staging_beta` hanya dipilih lewat dispatch manual;
workflow itu tetap mereset data staging. Jangan memilihnya untuk memverifikasi production.

GitHub Actions memerlukan secret `KUMPUL_PRODUCTION_BACKEND_URL` dan
`KUMPUL_PRODUCTION_PUBLISHABLE_KEY`, variable `KUMPUL_PRODUCTION_PROJECT_REF`, serta pasangan
secret `KUMPUL_STAGING_BACKEND_URL` dan `KUMPUL_STAGING_PUBLISHABLE_KEY` untuk jalur staging.
Secret signing dan secret reset staging memiliki tujuan terpisah; keduanya bukan key aplikasi.

Workflow membuat `Config/Secrets.xcconfig` sementara dengan permission `0600`. File hanya memuat
pasangan environment terpilih, memakai penulisan `https:/$()/...` agar URL tidak terpotong sebagai
komentar xcconfig, dan dihapus pada cleanup `always()`. File lokal yang sudah ada tidak ditimpa oleh
helper. Jangan commit file ini atau mengunggahnya sebagai artifact.

## Urutan gate

1. Validasi lane, build number, project ref independen, URL hosted HTTPS, dan key client.
2. GET `/auth/v1/health` dengan header `apikey` untuk memastikan URL menerima key tersebut.
3. Periksa nilai efektif target `happyFamily` melalui `xcodebuild -showBuildSettings -json`.
4. Import signing assets lalu build ke directory dan archive unik untuk invocation tersebut.
5. Periksa plist aplikasi di archive dan IPA: environment, URL, key, bundle ID, serta build number
   harus sama dengan nilai yang disetujui sebelum build.
6. Panggil uploader dengan path IPA yang diperiksa secara eksplisit.

Key `sb_secret_*` dan JWT `service_role` ditolak. Legacy JWT hanya diterima untuk role `anon` dan
project ref yang sesuai, lalu tetap harus lolos pemeriksaan gateway. Endpoint `.invalid`, URL contoh,
nilai kosong, substitusi Xcode yang belum terurai, maupun konfigurasi dari project lain memblokir
lane sebelum upload. Error tidak memuat nilai key atau URL.

Untuk invocation lokal, export konfigurasi environment terpilih dari penyimpanan aman, siapkan
ignored xcconfig yang sesuai, lalu panggil `rtk proxy bundle exec fastlane beta build_number:123`.
Nomor build wajib eksplisit. Key tidak diteruskan lewat argumen shell atau `xcargs`.

## Pengujian otomatis

`rtk proxy bundle exec ruby fastlane/tests/backend_release_guard_test.rb` menguji input invalid,
gateway, permission/escaping xcconfig, build settings, binary plist, archive/IPA yang berbeda atau
hilang, output lama, serta memastikan uploader tidak dipanggil saat gate gagal.

Workflow `TestFlight configuration guard` berjalan pada push dan PR yang mengubah area terkait,
tanpa credential backend atau signing. Deployment menjalankan regression suite yang sama.
Log kegagalan hanya diunggah setelah redaksi berhasil; raw log, xcconfig, dan dump plist tidak
diunggah oleh workflow.

## Penyediaan backend baru pada 4 Oktober 2026

- Organisasi: `HendraaaIrwn's Org` (`zrjvohqnrwyvpsnqzjix`).
- Project: `kumpul-production` (`xxoqbfohxcilaapwkakm`), Singapore, PostgreSQL 17.
- Paket Free untuk validasi awal. Backup serta jaminan tidak auto-pause untuk operasional production
  belum terpenuhi; jangan menyamakan kelulusan TestFlight dengan kesiapan operasional penuh.
- `white-chorus-staging` (`xdeyotfyafklldslqnhm`) dipause atas keputusan pengguna untuk menyediakan
  kuota. Backend whiteChorus berhenti melayani selama pause; jangan resume tanpa meninjau kuota.
- Client production tersedia di GitHub Secrets/Variables. Material enkripsi/secret baru disimpan
  secara privat di luar repo; jangan memakai material staging.

Seluruh 41 migration source sudah diterapkan berurutan pada database baru melalui koneksi
Supabase setelah pemeriksaan lokal. Tidak dilakukan seed/reset production. Timestamp migration
hosted cocok dengan source. Dry-run CLI hosted belum berhasil karena CLI mengembalikan 403;
jangan menyatakan dry-run hosted lulus berdasarkan pemeriksaan lokal.

Seluruh 15 Edge Function aktif pada versi 1. `admin-banner`, `account`, dan `operations`
memakai `verify_jwt=true`; function lainnya memakai autentikasi sesuai source dengan
`verify_jwt=false`. Lima belas tabel public memiliki RLS, dengan 29 policy public.
Storage menyediakan `event-banners`, `profile-avatars`, dan `workspace-logos`, masing-masing
dengan batas 5 MiB dan MIME JPEG/PNG. Empat job Cron aktif sesuai migration.

Snapshot health menunjukkan backlog, pelanggaran kapasitas, dan failed/stuck job bernilai nol;
lifecycle sudah berhasil berjalan. Retention dan cleanup belum memiliki bukti eksekusi sukses.
Vault masih kosong dan secret Edge production baru belum diunggah. Status function aktif
belum membuktikan alur bisnis berhasil.

Advisor hosted tidak melaporkan warning/error. Tiga INFO RLS tanpa policy merupakan tabel
service-side yang dijelaskan runbook ([penjelasan advisor](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)).
INFO performance mencatat tujuh foreign key tanpa covering index
([remediasi](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys))
dan delapan index belum terpakai pada database baru
([penjelasan](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)).

Provisioning perlu akses CLI/Dashboard production untuk mengunggah secret serta setup Auth.
CLI yang memakai credential Keychain saat pemeriksaan masih hanya melihat staging dan
mengembalikan 403 untuk production; koneksi Supabase pada chat dapat mengakses production.
SMTP, provider Apple, serta URL landing/App Clip yang berfungsi belum tersedia. Origin API
Supabase bukan landing event. Release juga masih membutuhkan entitlement/profile Sign in with
Apple yang sesuai sebelum login Apple dapat diverifikasi. Jangan menonaktifkan fitur sebagai
pengganti setup.

## Hasil pemeriksaan kandidat lokal

- Regression Ruby: 27 test; input salah, archive/IPA/plist hilang atau berbeda, nomor build lama,
  dan output dari directory lain menghentikan uploader. Nilai credential tidak muncul dalam error.
- Ruby syntax, loading lane Fastlane, workflow actionlint, dan `git diff --check` lulus.
- SwiftFormat lulus; SwiftLint exit 0 dengan warning baseline. Formatting baseline diperbaiki
  dalam commit terpisah agar lint release dapat berjalan.
- Build Release simulator lulus; plist hasil build cocok dengan backend production.
- Seluruh unit test iOS: 84 test pada 17 suite lulus. Fixture organizer diperbaiki agar membaca
  body request dari recorder dan menggunakan UUID response yang sama.
- Deno format/lint/type-check lulus; 18 unit test Edge lulus.
- Backend lokal disposable: 153 assertion pgTAP, concurrency, smoke HTTP end-to-end,
  dan load 1.000 booking lulus. Database lint/advisors tanpa warning, schema diff kosong.

Hasil lokal ini belum menggantikan CI pada SHA terakhir, hosted smoke, upload TestFlight,
atau pengujian iPhone. Paket Free tetap untuk validasi awal.

## Bukti penyelesaian yang wajib

Kelulusan fixture guard, build simulator, atau health endpoint belum membuktikan alur device.
Sebelum PR dibuat, simpan hasil pemeriksaan backend lokal/hosted, SHA kandidat, workflow run,
nomor build TestFlight, serta hasil pengguna memasang build tersebut dan menguji login, membaca
data, dan satu alur tulis sintetis pada backend yang dipilih. Bersihkan data sintetis dengan prosedur
yang sesuai. PR dan klaim issue selesai tetap ditahan bila salah satu gate belum tersedia.
