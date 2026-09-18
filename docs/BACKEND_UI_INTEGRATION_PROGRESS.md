# Backend UI Integration Progress

Status per 2026-09-09. Dokumen ini mencatat implementasi aktual dan batas
verifikasi yang masih tersisa.

## Update 2026-09-10

- `operations` deployed ke hosted staging sebagai versi 9 dengan JWT
  verification tetap aktif. Action `export_report` dan `delete_donor_data`
  dihapus dari function agar kembali selaras dengan kontrak v2.
- `staging_account_contract.ts` run `v9-20260910054024-25044` lulus, termasuk
  assertion isolasi `list_events` dua workspace dan race capacity.
- Retry create draft sekarang mempertahankan event ID serta `mutation_id` yang
  sama sampai respons final; dashboard juga reset ke halaman pertama pada
  `CURSOR_INVALID`.
- Dashboard memiliki loading state dan filter status; reception/tracking
  memicu refresh daftar event dan recap. Kartu recap "Acara Selesai" dihapus
  karena respons `operations:recap` belum menyediakan metrik tersebut.
- Unit test iOS (68) dan test Edge Function (18) lulus; Debug simulator build
  lulus. Full UI suite masih gagal pada locator login/create yang tidak lagi
  cocok dengan auth UI WIP, sehingga journey UI kandidat release belum dapat
  dinyatakan lulus.

## Selesai pada sesi ini

- Mempertahankan auth WIP pengguna yang sudah ada; tidak ada reset, stash, atau
  perubahan pada file auth tersebut.
- Menambahkan `operations:list_events` pada Edge Function. Action ini memakai
  JWT Admin/RLS yang sudah ada, membungkus `api.list_events_v2`, menerima
  `cursor`/`limit`, dan mengembalikan `{ items, next_cursor }`.
- `account:event_detail` hanya mengembalikan detail event dan availability.
  MVP memakai pernyataan persetujuan di aplikasi; booking mencatat
  `consented_at` tanpa URL atau versi Terms/Privacy.
- Memperbarui `docs/API_CONTRACT.md` untuk kedua perubahan contract dan
  memperjelas bahwa identity/profile Admin tetap memakai `/account`.
- Memindahkan `SupabaseEventRepository.list` dari RPC langsung ke
  `OrganizerBackendHTTPClient.listEvents`, yang sekarang memanggil
  `POST /operations` action `list_events`.
- Memindahkan publish event dari endpoint legacy `publish-event` ke
  `operations:publish_event` dengan idempotency key deterministik per event.
- Memindahkan QR resolve Admin dari endpoint legacy `resolve-qr` ke
  `operations:resolve_qr`; request hanya mengirim opaque QR token.
- Menambah unit test request/response untuk `listEvents` dan assertion staging
  E2E untuk list event.
- Menyelesaikan signup email/password pada layar registrasi dengan
  `AuthViewModel`: validasi password contract dijalankan sebelum request dan
  error Auth ditampilkan pada form.
- Bootstrap session sekarang memanggil `account:my_profile` setelah mengambil
  session Supabase. Role server menentukan role-selection, completion donor,
  completion workspace Admin, donor home, atau Admin dashboard; tidak ada lagi
  fallback session langsung ke dashboard Admin.
- Menambah client typed untuk `my_profile`, `update_profile`,
  `update_workspace`, dan `request_email_change`. Admin bootstrap juga membaca
  `operations:workspace_profile.publishable` sebelum masuk dashboard.
- Menghubungkan `complete_onboarding` dari pemilihan peran, profile completion
  donor, serta workspace completion Admin ke endpoint `account` yang sesuai.
- Menyimpan edit profil Admin ke workspace backend; bila email diubah, UI
  mengirim `request_email_change` dan membiarkan Supabase menjalankan flow
  secure email confirmation.
- Logout kini hanya kembali ke login setelah global sign-out dan purge cache
  berhasil. Kegagalan logout tetap mempertahankan session dan ditampilkan ke
  pengguna.

## Verifikasi berhasil

- `deno check --config supabase/functions/deno.json` untuk seluruh Edge
  Function berhasil.
- `deno test --config supabase/functions/deno.json --allow-env supabase/functions/_tests`:
  18 passed, 0 failed.
- Debug simulator build `happyFamily` berhasil dengan Supabase Swift 2.55.1.
- Focused `OrganizerOperationsClientTests`: 8 passed, 0 failed, mencakup list,
  publish, dan resolve QR melalui `/operations`.
- `git diff --check` berhasil.
- Deploy hosted staging memakai Supabase MCP berhasil: `account` aktif versi 7
  dan `operations` aktif versi 8, keduanya dengan JWT verification.
- E2E hosted `v2-contract-20260909-2139` berhasil untuk signup/onboarding,
  profile, booking, QR reception, tracking, history, recap, dan race capacity.
  Rerun assertion isolasi dua workspace belum memiliki
  output final yang dapat diandalkan sehingga belum dinyatakan lulus.
- Debug simulator build berhasil setelah perubahan auth/onboarding. Focused
  `AuthRoutingTests` dan `AuthViewModelTests` selesai tanpa failure yang
  dilaporkan runner.

## Belum dilakukan

### Deployment dan proof contract

- Tangkap hasil final yang deterministik untuk rerun assertion isolasi
  `list_events` di dua workspace Admin. Run sebelumnya berhenti di wrapper
  sekitar 30 detik, jadi tidak boleh dianggap bukti lulus.

### Auth dan onboarding

- Wire Sign in with Apple pada layar registrasi secara eksplisit. Layar login
  sudah menggunakan native Apple sign-in; signup Apple belum menggantikan
  tombol sosial statis pada layar registrasi.
- Upload avatar donor dan logo workspace ke bucket private sebelum mengirim
  object path. Saat ini completion/edit text profile sudah backend-backed,
  sedangkan image masih state lokal.
- Ganti donor home placeholder dengan `account:dashboard` dan tampilkan
  confirmation/pending state setelah secure email change dikirim.

### Admin

- Hubungkan load-more/search/status event, publish, workspace profile/logo,
  recap, histories, QR opaque, reception accept/reject, dan tracking.
- Hapus flow lokal `AdminEventStore` setelah seluruh reception memakai backend.
- Migrasikan endpoint legacy Admin yang tersisa: `export-report`,
  `delete-donor-data`, `recap_v1`, dan `decide_reception_v1`.

### Donor

- Ganti dashboard/detail event hardcoded dengan `account:dashboard` dan
  `account:event_detail`.
- Hubungkan profile/avatar, scan summary, shipping, create/cancel booking,
  my bookings/detail, timeline, dan histories.
- Tambahkan persistent booking attempt/idempotency serta Keychain QR store;
  hapus semua QR console logging.

### Cutover akhir

- Hapus seluruh caller guest legacy: `resolve-event`, `create-booking`,
  `verify-donor-booking`, dan `donor-booking-status`.
- Tambahkan static grep gate untuk endpoint/RPC legacy dan QR logging.
- Jalankan E2E Admin/Donor nyata dan race-capacity terhadap build release.

## Worktree dan kelanjutan aman

- Perubahan sesi ini belum di-commit.
- Worktree sudah berisi auth WIP pengguna sebelum sesi ini; jangan menggunakan
  `git reset`, `git checkout --`, stash, atau `git add -A`.
- Perubahan sesi ini terbatas pada contract backend, client/repository event,
  satu test client, satu test E2E, dan dokumen contract/progress.
