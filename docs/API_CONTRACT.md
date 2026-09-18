# .kumpul API Contract v2

Dokumen ini adalah contract integrasi UI untuk backend `.kumpul` yang berjalan
di Supabase Hosted. Ia melengkapi [BACKEND_PRD.md](BACKEND_PRD.md): bila ada
perbedaan mengenai bentuk request/response, dokumen ini dan source Edge
Function menjadi acuan integrasi; aturan produk tetap mengikuti Sketch/PRD.

## 1. Ruang lingkup dan base URL

Semua API aplikasi memakai Edge Function dengan base URL proyek Supabase:

```text
https://<project-ref>.supabase.co/functions/v1
```

Endpoint aplikasi aktif:

| Endpoint | Pengguna | Tujuan |
| --- | --- | --- |
| `POST /account` | Donor dan Admin | akun, profil, discovery, booking, tracking, riwayat |
| `POST /operations` | Admin | event, QR reception, tracking operasional, recap |
| `POST /admin-banner` | Admin | upload banner event tervalidasi |

Endpoint guest/App Clip berikut **sudah tidak menjadi contract** dan harus
tidak dipanggil UI baru: `resolve-event`, `create-booking`,
`verify-donor-booking`, dan `donor-booking-status`.

## 2. Autentikasi dan envelope

`account`, `operations`, dan `admin-banner` membutuhkan JWT Supabase user
yang valid. Kirim publishable key dan bearer token; jangan pernah menaruh
`service_role` key di klien.

```http
apikey: <publishable-key>
Authorization: Bearer <supabase-access-token>
```

Untuk JSON endpoint, gunakan juga:

```http
Content-Type: application/json
```

### Kebijakan Auth staging saat ini

Email/password dan Sign in with Apple aktif. Anonymous sign-in dan manual
identity linking nonaktif. Secure email change mengharuskan konfirmasi alamat
lama dan baru. Password baru harus minimal 12 karakter serta mengandung huruf
lowercase, uppercase, angka, dan simbol; perubahan password memerlukan recent
authentication dan password saat ini.

Konfirmasi email ketika signup sengaja masih nonaktif di staging sampai UI
cutover membuktikan deep-link/OTP confirmation end-to-end. Leaked-password
protection tersedia hanya pada Supabase Pro; organisasi staging saat ini Free,
dan secara sadar tetap memakai Free untuk MVP. Fitur tersebut bukan blocker
MVP, tetapi harus dievaluasi kembali sebelum production/hardening berbayar.

Setiap respons JSON memiliki envelope berikut.

```json
{
  "data": {},
  "error": null,
  "request_id": "uuid",
  "server_time": "2026-09-09T00:00:00.000Z"
}
```

Pada kegagalan, `data` bernilai `null` dan `error` berisi `code`, `retryable`,
serta `field_errors` hanya bila aman untuk ditampilkan. Simpan `request_id`
untuk laporan incident; backend juga mengembalikannya pada header
`x-request-id`.

```json
{
  "data": null,
  "error": { "code": "CAPACITY_EXCEEDED", "retryable": false },
  "request_id": "uuid",
  "server_time": "2026-09-09T00:00:00.000Z"
}
```

HTTP status utama: `400` request/idempotency key salah, `401` session tidak
valid, `403` role atau onboarding tidak sesuai, `404` resource tidak terlihat,
`409` konflik state/idempotency/kapasitas, `422` validasi bisnis, dan `500`
error retryable tak terklasifikasi.

## 3. Aturan umum mutation

### Idempotency

Mutation berikut wajib memakai header `idempotency-key` sepanjang 8–200
karakter: huruf, angka, `.`, `_`, `:`, atau `-`.

| Endpoint/action | Scope idempotency |
| --- | --- |
| `account:create_booking` | donor + booking request |
| `account:cancel_booking` | donor + booking id |
| `operations:publish_event` | admin + event id |
| `operations:cancel_or_delete_event` | admin + event id |
| `operations:decide_reception` | admin + booking, decision, actual weight |
| `operations:advance_tracking` | admin + booking, status tujuan |

Retry dengan key dan payload identik mengembalikan hasil durable yang sama.
Menggunakan key yang sama dengan payload lain mengembalikan
`IDEMPOTENCY_CONFLICT` (`409`). Jangan membuat key baru hanya karena request
timeout sebelum hasil diterima.

`upsert_event_draft` memakai `mutation_id` UUID di body sebagai idempotency
key. UUID ini harus dipersist oleh cache draft offline sampai request berhasil.

### Status domain

Event: `draft` → `upcoming`/`ongoing` → `completed` atau `cancelled`.

Booking: `waiting` → `accepted` → `processed` → `recycled`. Terminal lain:
`rejected`, `expired`, dan `cancelled`. Donor hanya dapat membatalkan booking
berstatus `waiting`. Admin yang mengubah reception/tracking selalu tercatat
dengan timestamp dan actor audit.

## 4. `POST /account`

Semua request memakai field `action`.

| Action | Role | Body tambahan | Hasil `data` |
| --- | --- | --- | --- |
| `complete_onboarding` | user baru | `role`: `admin` atau `donor` | role, profile id, workspace id bila Admin |
| `my_profile` | donor/admin | — | profil actor saat ini |
| `update_profile` | donor/admin | lihat payload profil | profil yang diperbarui |
| `request_email_change` | donor/admin | `email` | email sekarang, pending email, waktu request |
| `update_workspace` | admin | lihat payload workspace | profil workspace |
| `delete_account` | donor/admin | — | object kosong setelah identitas terhapus |
| `dashboard` | donor | — | profil completion, event aktif/rekomendasi/trending |
| `event_detail` | donor | `event_id` | event beserta availability donor |
| `my_bookings` | donor | — | booking non-cancelled actor |
| `booking_detail` | donor/admin workspace | `booking_id` | detail, timeline, QR hanya untuk owner donor |
| `donation_history` | donor | `limit?`, `cursor?` | riwayat donation, halaman cursor |
| `event_history` | donor | `terminal?`, `limit?`, `cursor?` | riwayat event, halaman cursor |
| `create_booking` | donor | `event_id`, `booking` | booking, QR token, snapshot event |
| `cancel_booking` | donor | `booking_id` | status booking sesudah cancel |

### Payload profil dan workspace

```json
{
  "action": "update_profile",
  "display_name": "Nama Donor",
  "phone_e164": "+628123456789",
  "address": "Alamat",
  "location_label": "Jakarta Selatan",
  "latitude": -6.2,
  "longitude": 106.8,
  "avatar_object_path": "<auth-user-id>/avatar.png"
}
```

`avatar_object_path` harus berupa object yang telah diupload donor sendiri ke
bucket private `profile-avatars`; mengosongkan field akan melepas avatar.

```json
{
  "action": "update_workspace",
  "name": "Nama Pengelola/Kantor",
  "address": "Alamat kantor",
  "phone_e164": "+628123456789",
  "email": "office@example.com",
  "logo_object_path": "<workspace-id>/logo.png"
}
```

Nama kantor adalah nama Pengelola. Alamat, telepon, email, dan logo bersifat
persisten. Workspace profile harus lengkap sebelum membuat event draft baru
atau mempublish event.

`delete_account` hanya menghapus identitas actor yang sedang terautentikasi;
client tidak dapat mengirim user id milik pihak lain. Untuk donor, relasi
booking dilepas dari akun dan profil dihapus. Untuk admin, workspace dinonaktifkan
dan owner dilepas agar akses tercabut sementara histori operasional dan agregat
tetap bertahan. Avatar/logo dihapus secara best-effort dan sisanya ditangani job
orphan cleanup.

### Discovery dan booking

`event_detail.data.availability` memiliki:

```json
{
  "bookable": true,
  "available_weight_grams": 4700
}
```

MVP mewajibkan donor menerima pernyataan persetujuan di aplikasi sebelum
membuat booking. `event_detail` tidak mengembalikan URL atau versi Terms/Privacy,
dan body booking tidak mengirim field tersebut. Server merekam `consented_at`
ketika booking dibuat.

`bookable` sudah memperhitungkan waktu server, kapasitas, dan booking aktif
donor tersebut. UI tetap harus menangani `CAPACITY_EXCEEDED` karena kapasitas
adalah invariant transaksional dan dapat berubah secara bersamaan.

```json
{
  "action": "create_booking",
  "event_id": "uuid",
  "booking": {
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
}
```

`shipping_method` valid: `direct`, `ojek_online`, atau `expedition`. Backend
tidak menerima foto, path foto, embedding, atau history scanner. Respons
berhasil berisi `booking_id`, `public_booking_id`, `status`, `expires_at`,
`event_snapshot`, `qr_token`, dan `idempotent_replay`. `qr_token` hanya boleh
disimpan di secure local storage donor; jangan ditulis ke analytics atau log.

## 5. `POST /operations`

| Action | Body tambahan | Hasil |
| --- | --- | --- |
| `list_events` | `limit?`, `cursor?` | halaman event workspace `{ items, next_cursor }` |
| `upsert_event_draft` | `event_id?`, `mutation_id`, `payload` | event draft |
| `publish_event` | `event_id` | event published |
| `cancel_or_delete_event` | `event_id` | draft terhapus atau event published dibatalkan |
| `workspace_profile` | — | profil workspace Admin |
| `recap` | `event_id?`, `from?`, `to?`, `days?` | recap daily/month |
| `donation_history` | `event_id?`, `limit?`, `cursor?` | riwayat donor workspace |
| `event_history` | `event_id?`, `limit?`, `cursor?` | riwayat event workspace |
| `resolve_qr` | `qr_token` | booking yang dapat diproses + PII terbuka untuk Admin sah |
| `decide_reception` | `booking_id`, `decision`, `actual_weight_grams?` | status booking reception |
| `advance_tracking` | `booking_id`, `status` | status tracking baru |

### Event draft/publish

```json
{
  "action": "upsert_event_draft",
  "event_id": "uuid-optional-for-new-draft",
  "mutation_id": "uuid",
  "payload": {
    "name": "Bank Sampah Akhir Pekan",
    "description": "...",
    "banner_object_path": "<workspace-id>/<uuid>/banner.jpg",
    "start_at": "2026-09-12T01:00:00.000Z",
    "end_at": "2026-09-13T09:00:00.000Z",
    "timezone_name": "Asia/Jakarta",
    "operational_days": [1, 2, 3, 4, 5, 6, 7],
    "opens_at_local": "09:00",
    "closes_at_local": "17:00",
    "location_name": "Drop point",
    "location_address": "Jakarta",
    "location_country_code": "ID",
    "latitude": -6.2,
    "longitude": 106.8,
    "capacity_grams": 5000,
    "max_donation_per_user_grams": 1000,
    "criteria": ["cotton", "denim"]
  }
}
```

Criteria valid: `cotton`, `linen`, `rayon`, `wool`, `tencel`, `silk`,
`non_stretch`, `denim`, `no_lace`, dan `polyester`.

`max_donation_per_user_grams` wajib positif dan dikonfigurasi per event.
Receiver bukan field yang dapat dioverride UI: saat event dibuat, backend
menyalin nama, alamat, dan telepon workspace sebagai snapshot immutable.

Field event sendiri boleh belum lengkap selama event masih draft. Namun,
pembuatan draft baru memerlukan workspace profile lengkap (nama, alamat,
telepon, dan email); bila belum lengkap backend menolak dengan
`WORKSPACE_PROFILE_INCOMPLETE`. Update draft yang sudah dimiliki workspace
tetap diizinkan agar Pengelola dapat melanjutkan pekerjaan yang tersimpan.

`description` bersifat opsional pada payload draf. Field ini boleh tidak
dikirim, bernilai string kosong atau hanya spasi, maupun `null`; backend
menyimpannya sebagai `null`. Publish tetap menerima event dengan deskripsi
`null`, dan respons event atau `event_snapshot` dapat berisi
`"description": null`.

Publish memerlukan semua field operasional, banner, criteria, kapasitas, limit
donasi per donor, dan workspace profile lengkap. Maksimal lima event aktif per
workspace.

### QR, reception, dan tracking

```json
{ "action": "resolve_qr", "qr_token": "opaque-donor-qr-token" }
```

Hanya Admin dari workspace yang sesuai yang dapat resolve QR. Jangan mencoba
resolve QR di client donor atau memakai `public_booking_id` sebagai kredensial.

`resolve_qr.data.event_snapshot` adalah snapshot immutable yang disalin saat
booking dibuat dari `private.event_user_json`. Bentuknya sama dengan
`DonorEventDTO`, bukan `PublicEventDTO`; karena itu snapshot membawa field
donor seperti `reserved_weight_grams`, `used_weight_grams`, dan
`organization_name`, sementara metadata ketersediaan event seperti
`availability` tidak ada. Field branding, jarak, banner, dan receiver dapat
bernilai `null` pada data historis dan client harus menanganinya.

```json
{
  "action": "decide_reception",
  "booking_id": "uuid",
  "decision": "accepted",
  "actual_weight_grams": 850
}
```

`decision` adalah `accepted` atau `rejected`. Untuk `accepted`, actual weight
wajib positif, tidak boleh melampaui limit event, dan harus masih muat di
kapasitas transaksional. Untuk `rejected`, jangan kirim actual weight atau
alasan; MVP hanya mencatat penolakan Admin.

Respons sukses `decide_reception` hanya membawa identitas booking dan status
terbaru. Nilai kapasitas tidak dikirim oleh mutation ini; gunakan endpoint
history atau recap bila UI membutuhkan agregat kapasitas terbaru.

```json
{
  "booking_id": "uuid",
  "public_booking_id": "KMP-TEST-001",
  "status": "accepted"
}
```

```json
{
  "action": "advance_tracking",
  "booking_id": "uuid",
  "status": "processed"
}
```

Tracking hanya menerima `processed` setelah `accepted`, lalu `recycled`
setelah `processed`; transisi lain menghasilkan `INVALID_BOOKING_TRANSITION`.
Respons sukses tracking berbentuk `booking_id`, `status`, dan
`status_updated_at`.

## 6. `POST /admin-banner`

Endpoint ini memakai `multipart/form-data`, bukan JSON. Body hanya boleh
memiliki satu field bernama `file`.

```text
file: image/jpeg atau image/png
```

Ukuran maksimum 5 MiB; lebar dan tinggi masing-masing maksimum 4096 piksel.
Client iOS menyiapkan gambar sebelum upload, tetapi server tetap memeriksa
signature, MIME, dan dimensi gambar.
Respons `201` berisi `object_path`, `content_type`, `width`, dan `height`.
Masukkan `object_path` tersebut ke `payload.banner_object_path` pada
`upsert_event_draft`.

## 7. Storage direct upload

Banner tidak boleh diupload langsung ke Storage. Avatar dan logo dapat
diupload melalui Storage REST dengan JWT user:

| Bucket | Path wajib | RLS write |
| --- | --- | --- |
| `profile-avatars` | `<auth-user-id>/<filename>` | hanya owner user tersebut |
| `workspace-logos` | `<workspace-id>/<filename>` | hanya Admin owner workspace |
| `event-banners` | tidak ada direct client write | hanya `admin-banner` server-side |

Upload ke folder actor lain akan ditolak oleh RLS. API Storage dapat memetakan
policy denial ke HTTP `400` atau `403`; keduanya harus ditampilkan sebagai
upload tidak diizinkan, bukan retry otomatis.

Saat `update_profile` atau `update_workspace` mengganti object path, backend
menghapus object sebelumnya secara best-effort. Orphan lama dipungut oleh job
cleanup setelah grace period.

## 8. Pagination dan sejarah

`limit` adalah integer positif dan maksimal 100. Bila `limit` diberikan,
riwayat mengembalikan bentuk:

```json
{ "items": [], "next_cursor": "opaque-or-null" }
```

Tanpa `limit`, endpoint legacy-compatible dapat mengembalikan array langsung.
Cursor adalah opaque: jangan dibaca, dimodifikasi, atau digunakan dengan scope
endpoint lain. Gunakan `next_cursor` sampai `null`.

## 9. Stable error code penting

| Code | UI yang disarankan |
| --- | --- |
| `AUTH_INVALID`, `AUTH_REQUIRED` | refresh/sign-in ulang |
| `ONBOARDING_REQUIRED`, `ROLE_FORBIDDEN` | arahkan onboarding atau blokir layar |
| `PROFILE_INCOMPLETE`, `WORKSPACE_PROFILE_INCOMPLETE` | tampilkan field profil yang perlu dilengkapi |
| `BOOKING_ALREADY_EXISTS` | buka tracking booking yang sudah ada |
| `BOOKING_NOT_CANCELLABLE` | sembunyikan/nonaktifkan cancel |
| `CAPACITY_EXCEEDED`, `EVENT_FULL`, `EVENT_UNAVAILABLE` | refresh detail event dan tampilkan event penuh |
| `DONATION_LIMIT_EXCEEDED` | tampilkan limit per event |
| `IDEMPOTENCY_CONFLICT` | jangan retry dengan key sama dan payload berbeda |
| `IDEMPOTENCY_INCOMPLETE`, `INTERNAL_ERROR` | retry dengan key/payload sama bila `retryable: true` |
| `INVALID_BOOKING_TRANSITION` | refresh timeline tracking |
| `CURSOR_INVALID` | mulai ulang pagination dari halaman pertama |

## 10. Operasional, lifecycle, dan cleanup

Lifecycle server menangani event mulai/selesai serta expiry booking. Client
tidak menghitung state terminal dari jam perangkat. Admin dapat memantau
`api.operational_health_v1` melalui server/service role; view ini tidak boleh
dipanggil aplikasi user.

`cleanup-orphan-profile-media` adalah endpoint internal Cron, bukan API UI:

```http
POST /functions/v1/cleanup-orphan-profile-media
x-cron-secret: <PROFILE_MEDIA_CLEANUP_SECRET>
```

Ia memakai service role internal, mencatat `job_runs`, dan hanya menghapus
avatar/logo yang tidak direferensikan serta berumur minimal tujuh hari. UI
tidak boleh memanggil endpoint ini atau menyimpan secret Cron.

## 11. Acceptance UI cutover

UI dianggap sudah pindah ke v2 hanya bila seluruh kondisi berikut terbukti di
staging:

1. Semua call user menggunakan `account`, semua call Admin menggunakan
   `operations`/`admin-banner`, kecuali identity/profile Admin yang memang
   didefinisikan pada `account` (`my_profile`, `update_profile`,
   `request_email_change`, dan `update_workspace`).
2. Booking, cancel `waiting`, QR reception, processed/recycled, history,
   recap, profile, dan per-event donation limit berjalan dengan akun nyata.
3. UI mengirim idempotency key yang persisten untuk semua mutation wajib.
4. Tidak ada traffic ke endpoint guest/App Clip legacy.
5. E2E Admin/Donor dan race kapasitas lulus terhadap build UI yang di-release.

Setelah bukti tersebut tersedia, endpoint guest dan target App Clip dapat
didekomisi dengan acceptance akhir terpisah.
