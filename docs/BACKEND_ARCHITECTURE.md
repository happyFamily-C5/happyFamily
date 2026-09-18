# Dokumentasi Backend Happy Family

> **Status:** dokumentasi implementasi saat ini, diturunkan dari source repository pada 15 September 2026.  
> **Cakupan:** backend Supabase yang dipakai aplikasi iOS Happy Family; tidak memuat nilai credential, token, atau secret.

## 1. Ringkasan

Happy Family memakai **Supabase Hosted** sebagai backend. Arsitekturnya tidak memberi aplikasi iOS akses tulis langsung ke tabel domain. Aplikasi mengautentikasi pengguna melalui Supabase Auth, lalu memanggil Edge Function terautentikasi. Edge Function meneruskan operasi domain ke RPC PostgreSQL. Database menjadi source of truth untuk state event, kapasitas, booking, dan otorisasi tenant.

```text
SwiftUI iOS app
  ├─ Supabase Auth (session/JWT)
  ├─ Storage REST (avatar dan logo yang diizinkan RLS)
  └─ Edge Functions /functions/v1
       ├─ account       — pengalaman donor dan profil akun
       ├─ operations    — operasi admin/workspace
       └─ admin-banner  — upload banner event tervalidasi
              │
              ├─ RPC schema api (security invoker)
              ├─ private implementation (otorisasi + transaksi)
              ├─ public tables (RLS, tanpa direct domain write)
              ├─ Storage buckets
              └─ pg_cron / Edge cleanup jobs
```

Implementasi iOS memakai satu `SupabaseClient` bersama melalui `BackendDependencies`; session yang dibuat saat sign-in dengan demikian dipakai oleh seluruh repository. Konfigurasi aplikasi dibaca dari `KumpulBackendURL`, `KumpulBackendPublishableKey`, dan `KumpulBackendEnvironment`. URL hanya menerima HTTPS, kecuali local host `127.0.0.1` untuk development lokal.

## 2. Komponen dan kepemilikan tanggung jawab

| Komponen | Tanggung jawab |
| --- | --- |
| Supabase Auth | Identitas email/password dan Sign in with Apple, session JWT, perubahan email/password. |
| Edge Functions | Boundary HTTP, validasi request, envelope respons, pemetaan error aman, enkripsi/dekripsi PII yang diperlukan, dan orkestrasi Storage/RPC. |
| `api` schema | RPC yang boleh dieksekusi role `authenticated`; wrapper bersifat `SECURITY INVOKER`. |
| `private` schema | Implementasi privileged, validasi role/tenant, transaksi kapasitas, lifecycle, cleanup, dan helper cursor. Tidak diekspos ke client. |
| `public` schema | Tabel domain, audit, idempotency, dan agregat. Akses tabel langsung client ditolak. |
| Supabase Storage | Media: banner event, avatar donor, dan logo workspace. |
| pg_cron + job | Lifecycle event/booking, retention, dan cleanup object media orphan. |

## 3. Role, tenancy, dan lifecycle domain

Setelah registrasi, pengguna menyelesaikan onboarding sekali sebagai salah satu role berikut:

| Role | Kepemilikan | Hak utama |
| --- | --- | --- |
| `donor` | profil sendiri dan booking miliknya | discovery event, membuat/membatalkan booking, melihat QR dan riwayat sendiri. |
| `admin` | satu workspace yang dimilikinya | mengelola event workspace, scan QR, menerima/menolak donasi, tracking, recap, dan riwayat workspace. |

Role tidak dapat diubah sembarang setelah onboarding. Workspace dapat berstatus `active` atau `disabled`; hanya workspace aktif yang bisa menjalankan operasi admin.

```text
Event:    draft → upcoming / ongoing → completed | cancelled

Booking:  waiting → accepted → processed → recycled
                     └→ rejected
          waiting → expired | cancelled
```

- Donor hanya dapat membatalkan booking `waiting`.
- Reception admin menerima `accepted` atau `rejected`. Penerimaan membutuhkan berat aktual positif dan masih mematuhi kapasitas transaksional.
- Tracking hanya menerima `accepted → processed → recycled`.
- Status event dan expiry booking dihitung server-side; client tidak boleh menentukan status terminal berdasarkan jam perangkat.

## 4. Kontrak HTTP umum

Base URL:

```text
https://<supabase-project-ref>.supabase.co/functions/v1
```

Tiga endpoint aplikasi aktif selalu `POST` dan memerlukan JWT pengguna yang valid:

```http
apikey: <publishable-key>
Authorization: Bearer <access-token>
X-Request-ID: <uuid-optional>
```

Untuk `account` dan `operations`, gunakan juga `Content-Type: application/json`. Ukuran JSON dibatasi 32 KiB. `admin-banner` menerima `multipart/form-data`.

Setiap respons memakai envelope yang sama dan mengirim ID yang sama pada header `x-request-id`:

```json
{
  "data": {},
  "error": null,
  "request_id": "uuid",
  "server_time": "2026-09-15T00:00:00.000Z"
}
```

Pada kegagalan, `data` bernilai `null`; `error` memuat `code`, `retryable`, dan—bila aman—`field_errors`.

| HTTP | Makna umum |
| --- | --- |
| 400 | request, format, atau idempotency key tidak valid |
| 401 | JWT tidak ada/tidak valid |
| 403 | role, onboarding, atau workspace tidak berhak |
| 404 | resource/QR tidak ada atau tidak terlihat oleh actor |
| 409 | state, kapasitas, atau idempotency conflict |
| 422 | validasi bisnis/payload |
| 500 | kegagalan internal; hanya retry bila `retryable: true` |

## 5. Endpoint aplikasi aktif

### 5.1 `POST /account`

Semua body memiliki field `action`. Endpoint ini dipakai oleh donor serta profil dasar admin.

| Action | Actor | Input penting | Hasil ringkas |
| --- | --- | --- | --- |
| `complete_onboarding` | user baru | `role: admin | donor` | role, profile, dan workspace bila admin |
| `my_profile` | donor/admin | — | profil actor |
| `update_profile` | donor/admin | nama, telepon E.164, alamat, lokasi, avatar path | profil terbaru |
| `request_email_change` | donor/admin | `email` | status request perubahan email Auth |
| `delete_account` | donor/admin | — | hapus identitas actor; media dibersihkan best-effort |
| `update_workspace` | admin | nama, alamat, telepon, email, logo path | profil workspace |
| `dashboard` | donor | — | profil completion dan rail event |
| `event_detail` | donor | `event_id` | detail event dan availability |
| `my_bookings` | donor | — | booking non-cancelled milik donor |
| `booking_detail` | donor atau admin workspace | `booking_id` | detail/timeline; QR hanya untuk donor pemilik |
| `donation_history` | donor | `limit?`, `cursor?` | riwayat booking donor |
| `event_history` | donor | `terminal?`, `limit?`, `cursor?` | riwayat event donor |
| `create_booking` | donor | `event_id`, `booking`, header idempotency | booking, snapshot, QR token |
| `cancel_booking` | donor | `booking_id`, header idempotency | booking setelah cancel |

`create_booking` tidak menerima identitas donor dari body. Nama dan telepon diambil dari profil actor yang sudah terautentikasi, dinormalisasi, lalu dienkripsi sebelum ditulis. Payload `booking` hanya mengizinkan:

```json
{
  "estimated_weight_grams": 300,
  "item_count": 1,
  "items": [{
    "ordinal": 0,
    "passed": true,
    "scanner_model_version": "model-version",
    "metadata": {}
  }],
  "shipping_method": "direct",
  "scan_model_version": "model-version"
}
```

Validasi booking menolak field tak dikenal, foto/path/URL/blob/embedding/history scanner, item yang tidak `passed`, metadata lebih dari 2 KiB, dan bobot tidak valid. Pilihan `shipping_method` adalah `direct`, `ojek_online`, atau `expedition`.

MVP mengharuskan donor mencentang pernyataan persetujuan di aplikasi sebelum booking. `event_detail` dan payload booking tidak memakai URL atau versi Terms/Privacy; backend merekam `consented_at` pada booking baru. QR token adalah token opaque sensitif: iOS menyimpannya per booking di Keychain dan tidak boleh mengirimkannya ke analytics atau log.

### 5.2 `POST /operations`

Hanya untuk admin workspace aktif. Semua input menggunakan `action`.

| Action | Input penting | Hasil ringkas |
| --- | --- | --- |
| `list_events` | `limit?`, `cursor?` | event workspace berpaginasi |
| `upsert_event_draft` | `event_id?`, `mutation_id`, `payload` | draft baru/terbarui |
| `publish_event` | `event_id`, header idempotency | event dan URL invocation |
| `cancel_or_delete_event` | `event_id`, header idempotency | draft terhapus atau event dibatalkan |
| `workspace_profile` | — | profil workspace |
| `recap` | `event_id?`, `from?`, `to?`, `days?` | agregat dan donasi terbaru |
| `donation_history` | `event_id?`, `limit?`, `cursor?` | riwayat donasi workspace |
| `event_history` | `event_id?`, `limit?`, `cursor?` | riwayat event workspace |
| `resolve_qr` | `qr_token` | booking yang boleh diproses dan PII terbuka untuk admin sah |
| `decide_reception` | booking, decision, actual weight, header idempotency | booking dan status hasil reception |
| `advance_tracking` | booking, `processed | recycled`, header idempotency | status tracking terbaru |

Draft event memuat jadwal, alamat/koordinat Indonesia, kapasitas dalam gram, limit donasi per donor, banner, dan criteria. Criteria yang diizinkan: `cotton`, `linen`, `rayon`, `wool`, `tencel`, `silk`, `non_stretch`, `denim`, `no_lace`, `polyester`.

Data penerima event bukan input UI: server membuat snapshot nama, alamat, dan telepon dari workspace ketika event dibuat. Publish memerlukan profil workspace lengkap, field operasional lengkap, banner, criteria, kapasitas, dan limit donasi donor. Maksimum lima event aktif per workspace.

### 5.3 `POST /admin-banner`

Endpoint khusus upload banner, terpisah dari JSON agar byte gambar tidak masuk ke payload database.

- hanya Admin workspace aktif;
- `multipart/form-data` dengan tepat satu field `file`;
- hanya JPEG atau PNG dengan signature/MIME/dimensi tervalidasi;
- batas maksimum 5 MiB;
- menyimpan object pada bucket `event-banners` dan mengembalikan `object_path`, `content_type`, `width`, serta `height` dengan status `201`.

`object_path` hasilnya dipakai di `operations:upsert_event_draft`. Client tidak boleh upload banner langsung ke Storage.

## 6. Idempotency, cursor, dan concurrency

Mutation berikut membutuhkan header `Idempotency-Key`: `create_booking`, `cancel_booking`, `publish_event`, `cancel_or_delete_event`, `decide_reception`, dan `advance_tracking`. Key menerima 8–200 karakter `[A-Za-z0-9._:-]`.

- Retry dengan key dan payload yang sama mengembalikan hasil durable yang sama.
- Key sama dengan payload berbeda menghasilkan `IDEMPOTENCY_CONFLICT`.
- Jika timeout terjadi sebelum respons, retry memakai key yang sama—jangan membuat key baru.
- `upsert_event_draft` memakai `mutation_id` UUID dalam body; ID ini perlu dipertahankan oleh cache draft hingga berhasil.

Kapasitas dihitung server dalam transaksi melalui berat yang sudah diterima ditambah berat yang direservasi. UI boleh menampilkan availability, tetapi tetap wajib menangani `CAPACITY_EXCEEDED`, `EVENT_FULL`, dan `DONATION_LIMIT_EXCEEDED` sebagai hasil authoritative.

Pagination memakai cursor opaque. `limit` positif dengan maksimum 100; respons berpaginasi berbentuk `{ "items": [], "next_cursor": "... | null" }`. Cursor tidak boleh dibaca, dimodifikasi, atau dipakai pada endpoint/scope lain. Ketika `CURSOR_INVALID`, muat kembali halaman pertama.

## 7. Model data PostgreSQL

### Tabel domain utama

| Tabel | Isi dan relasi utama |
| --- | --- |
| `profiles` | satu profil per `auth.users`; role, nama, telepon, alamat/lokasi rekomendasi, avatar. |
| `workspaces` | satu workspace milik admin; identitas kantor, status, dan logo. |
| `events` | event milik workspace; jadwal, lokasi, banner, kapasitas, bobot diterima/dicadangkan, receiver snapshot, dan limit donor. |
| `event_criteria` | criteria material per event. |
| `bookings` | booking event/workspace; donor account, snapshot event, bobot, shipping, waktu persetujuan MVP, status, QR/PII terenkripsi. |
| `booking_items` | item yang lolos scan dalam booking. |
| `receptions` | keputusan penerimaan admin dan berat aktual. |
| `booking_status_events` | timeline append-only transisi booking dengan actor dan request ID. |

### Tabel pendukung

| Tabel | Fungsi |
| --- | --- |
| `event_invocations` | token invocation event terenkripsi dan dapat dicabut; dipertahankan untuk kompatibilitas lifecycle. |
| `idempotency_keys` | request hash, scope actor, response durable, dan expiry idempotency. |
| `legal_document_versions` | data Terms dan Privacy lama yang dipertahankan untuk kompatibilitas dan histori; bukan bagian dari alur iOS MVP aktif. |
| `audit_events` | jejak tindakan domain beserta request ID dan metadata aman. |
| `impact_aggregates` | agregat dampak per workspace/event/periode. |
| `job_runs` | status, hasil, dan error aman background job. |
| `rate_limit_buckets` | counter rate limit berbasis fingerprint hash. |

Enum penting: `workspace_status` (`active`, `disabled`), `event_status`, `booking_status`, `shipping_method`, `reception_decision`, `criterion_code`, dan `app_role`.

Tabel menyimpan constraint untuk urutan waktu, hari operasional, koordinat Indonesia, kapasitas tidak negatif, unique booking aktif donor-per-event, dan format nomor Indonesia `+62…`. Trigger `set_updated_at` memperbarui timestamp entitas yang relevan.

## 8. RPC dan akses database

Edge Function tidak membangun SQL domain sendiri; ia memanggil RPC pada schema `api`, misalnya `complete_onboarding_v1`, `user_dashboard_v1`, `event_detail_v2`, `create_account_booking_v2`, `upsert_event_draft_v2`, `publish_event_v2`, `resolve_account_qr_v2`, dan `decide_reception_v2`.

Wrapper `api.*` bersifat **security invoker**. Implementasi yang membutuhkan akses lebih tinggi berada di `private.*`, memakai pemeriksaan `auth.uid()`, role, dan workspace sebelum menyentuh data. Direct table write dari role aplikasi ditolak. Ini berarti UI harus memakai Edge Function/RPC contract, bukan PostgREST langsung terhadap tabel domain.

## 9. Storage dan media

| Bucket | Akses | Path yang disyaratkan |
| --- | --- | --- |
| `event-banners` | baca publik; write server-side melalui `admin-banner` | path dibuat server per workspace/event upload |
| `profile-avatars` | private; donor hanya kelola folder sendiri | `<auth-user-id>/<filename>` |
| `workspace-logos` | baca publik; admin owner workspace boleh tulis | `<workspace-id>/<filename>` |

Client iOS mengunggah avatar dan logo langsung ke Storage REST menggunakan JWT dan publishable key. Ia menormalisasi gambar menjadi PNG/JPEG, membatasi payload di bawah 4,5 MB, dan mengembalikan object path untuk disimpan melalui `account:update_profile` atau `account:update_workspace`. Saat media diganti, backend mencoba menghapus object lama; orphan yang tertinggal dibersihkan job setelah grace period.

## 10. PII, token, dan keamanan

- Publishable key boleh berada di app; **service-role key tidak boleh pernah berada di aplikasi, konfigurasi publik, log, atau dokumentasi.**
- Nama donor, telepon, dan QR token pada booking disimpan dengan AES-GCM; hash terpisah dipakai untuk lookup/validasi. QR plaintext hanya didekripsi pada `booking_detail` milik donor atau diserahkan kepada admin sah saat `resolve_qr`.
- `phone_e164` dinormalisasi ke format Indonesia sebelum update profil dan sebelum booking.
- Log Edge Function hanya mencatat request ID, nama function, durasi, outcome, dan safe error code—bukan body, PII, ciphertext, atau token.
- Semua tabel `public` menggunakan RLS; policy membatasi row ke owner donor atau workspace admin. Tabel internal (`idempotency_keys`, `job_runs`, `rate_limit_buckets`) tidak memiliki policy user-facing.
- Penghapusan akun menonaktifkan workspace milik admin sebelum penghapusan identity. Untuk donor, relasi booking dilepas dan profil dihapus; histori operasional/agregat dipertahankan sesuai lifecycle backend.

## 11. Auth dan konfigurasi environment

Konfigurasi lokal ada di `supabase/config.toml` dan contoh secret name di `supabase/.env.example`. Tidak ada nilai secret yang boleh dikomit.

Konfigurasi Auth lokal yang relevan:

- signup email aktif, anonymous sign-in dan manual linking nonaktif;
- password minimum 12 karakter dengan huruf lower/upper dan angka;
- refresh token rotation aktif;
- konfirmasi signup email nonaktif di staging saat ini sampai deep-link/OTP E2E terbukti;
- perubahan email meminta konfirmasi alamat lama dan baru.

Environment backend: `local`, `staging`, dan `production`. Variable server penting mencakup URL dan key Supabase internal, keyring PII, key HMAC lookup, versi key token, `APP_ENVIRONMENT`, URL invocation, kill switch `PUBLIC_BOOKING_ENABLED`, serta secret terpisah untuk cron cleanup. Nama saja boleh didokumentasikan; value tetap hanya berada di secret store/environment runtime.

## 12. Background job, health, dan operasional

| Job | Jadwal / pemicu | Peran |
| --- | --- | --- |
| lifecycle expiry | tiap menit | rekonsiliasi event dan booking yang kedaluwarsa. |
| retention | harian | menjalankan retensi data sesuai aturan database. |
| banner orphan cleanup | harian | menghapus banner tidak direferensikan setelah grace period. |
| profile-media orphan cleanup | harian 20:17 UTC | menghapus avatar/logo orphan setelah 7 hari. |

Cleanup banner dan profile media adalah Edge Function internal berheader `x-cron-secret`; UI tidak boleh memanggilnya. Setiap run dicatat ke `job_runs`.

View operasional hanya untuk `service_role`:

- `api.operational_health_v1`: snapshot health (invariant kapasitas, backlog, job, dan metrik terkait);
- `api.job_health_v1`: run terbaru per job.

Alert minimum: pelanggaran capacity invariant, lifecycle backlog lebih dari lima menit, job gagal/stuck, lifecycle sukses terakhir lebih dari lima menit, retention terakhir lebih dari 36 jam, p95 tinggi, serta quota database/storage mendekati limit plan.

## 13. Endpoint legacy dan batas migrasi

Folder `supabase/functions/` masih berisi beberapa Edge Function legacy (`resolve-event`, `create-booking`, `verify-donor-booking`, `donor-booking-status`, serta helper legacy lain) demi kompatibilitas/retensi. Mereka **bukan contract UI baru**. Migration terkini mencabut EXECUTE RPC guest legacy untuk role `anon` dan `authenticated`.

Aplikasi iOS saat ini menelusuri endpoint `account`, `operations`, dan `admin-banner`; UI baru tidak boleh menambah traffic ke endpoint guest/App Clip legacy. `event_invocations` dan URL invocation masih dapat dibuat saat publish untuk lifecycle kompatibilitas, tetapi bukan jalur booking aplikasi authenticated.

## 14. Pengembangan, pengujian, dan delivery

Repository memakai migration imperatif berurutan di `supabase/migrations/`; jangan mengubah `.xcodeproj` untuk konfigurasi backend dan jangan mengedit hosted database lewat Dashboard kecuali incident. Untuk perubahan schema, buat migration lewat CLI, review SQL, lalu validasi stack yang sesuai.

Untuk development Mac yang memakai hosted staging, jangan menjalankan local Docker/`supabase start` atau `supabase db reset`; gunakan konfigurasi Xcode `Staging` dan audit read-only yang relevan. Validasi local/CI yang tersedia meliputi:

```bash
deno fmt --check --config supabase/functions/deno.json supabase/functions supabase/tests/load/run.ts
deno lint --config supabase/functions/deno.json supabase/functions supabase/tests/load/run.ts
deno test --config supabase/functions/deno.json --allow-env supabase/functions/_tests
supabase test db --local
bash supabase/tests/concurrency/run.sh
bash supabase/tests/http/smoke.sh
bash supabase/tests/load/run.sh
supabase db lint --local --level warning --fail-on warning
supabase db advisors --local --type all --level warn --fail-on warn
```

Validasi source/local tidak sama dengan bukti deployment staging, E2E perangkat nyata, TestFlight, atau production readiness. Delivery staging harus membuktikan history migration, function version/checksum, konfigurasi Auth/Storage yang benar, health job, dan smoke/E2E memakai akun sintetis tanpa menyimpan PII atau secret pada log.

## 15. Referensi source of truth

| Topik | Lokasi |
| --- | --- |
| Pengantar konsep dengan bahasa sederhana (untuk pemula) | [BACKEND_UNTUK_PEMULA.md](BACKEND_UNTUK_PEMULA.md) |
| Contract request/response rinci | [API_CONTRACT.md](API_CONTRACT.md) |
| Aturan produk backend | [BACKEND_PRD.md](BACKEND_PRD.md) |
| Runbook development, delivery, incident | [BACKEND_RUNBOOK.md](BACKEND_RUNBOOK.md) |
| Konfigurasi lokal Supabase | [`supabase/config.toml`](../supabase/config.toml) |
| Migration database | [`supabase/migrations/`](../supabase/migrations/) |
| Edge Functions dan helper shared | [`supabase/functions/`](../supabase/functions/) |
| Boundary client iOS | [`Core/Backend/`](../Core/Backend/) |

Saat ada perbedaan, source Edge Function dan migration terbaru adalah implementasi authoritative. `API_CONTRACT.md` adalah contract integrasi UI; `BACKEND_PRD.md` memegang aturan produk; dokumen ini menjelaskan arsitektur dan hubungan antarkomponen.
