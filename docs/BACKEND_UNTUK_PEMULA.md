# Backend Happy Family — Penjelasan untuk Pemula

> **Status:** dokumen pengantar untuk kontributor baru, diturunkan dari source repository dan
> [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md).
> **Cakupan:** penjelasan konsep backend Happy Family dengan bahasa sederhana. Tidak memuat nilai
> credential, token, atau secret.
> **Untuk siapa:** kamu yang baru masuk project ini dan belum pernah menyentuh backend.

---

## 1. Singkatnya, backend itu apa?

Aplikasi iOS cuma "wajah". Dia butuh tempat menyimpan data (akun, event, booking donasi) yang bisa
diakses banyak orang sekaligus, dan tempat itu harus aman. Bagian itulah **backend**.

Di project ini backend-nya **bukan** server Node/Python/Express yang kita tulis sendiri.
Backend-nya adalah **Supabase** — layanan siap pakai yang menyediakan database + login +
penyimpanan file + fungsi server, semuanya di-host di cloud. Jadi kita tidak mengurus server,
patching, atau scaling; kita "menyewa" milik Supabase.

Analogi restoran:

| Bagian | Analogi | Di project ini |
| --- | --- | --- |
| Aplikasi iOS | Pelanggan di meja | SwiftUI app di `App/`, `Features/` |
| Database | Gudang bahan makanan | PostgreSQL di Supabase |
| Edge Functions | Pelayan yang menerima pesanan & mengecek aturan | `supabase/functions/` |
| RPC | Koki yang memasak | fungsi SQL di schema `api` / `private` |
| Storage | Kulkas untuk foto | bucket banner/avatar/logo |
| Supabase Auth | Satpam yang memberi gelang tamu | login email + Apple |
| pg_cron | Petugas kebersihan malam | job lifecycle, retention, cleanup |

---

## 2. Tiga komponen utama yang dipakai

### a. Database — PostgreSQL 17

Data disimpan di tabel, di schema `public`. Tabel intinya:

| Tabel | Isi |
| --- | --- |
| `profiles` | satu profil per user: role, nama, telepon, alamat/lokasi, avatar |
| `workspaces` | "kantor/yayasan" milik admin: identitas, status, logo |
| `events` | event pengumpulan donasi milik workspace: jadwal, lokasi, banner, kapasitas, receiver snapshot, limit donor |
| `event_criteria` | jenis kain yang diterima per event |
| `bookings` | donasi yang dijadwalkan/dikirim: donor, snapshot event, bobot, shipping, consent legal, status |
| `booking_items` | item yang lolos scan dalam satu booking |
| `receptions` | keputusan penerimaan admin dan berat aktual |
| `booking_status_events` | timeline perubahan status booking (append-only) |

Tabel "mesin" pendukung: `idempotency_keys`, `audit_events`, `job_runs`, `rate_limit_buckets`,
`impact_aggregates`, `legal_document_versions`, `event_invocations`.

### b. Edge Functions — TypeScript / Deno 2

Ini "server"-nya. Ada 17 fungsi di `supabase/functions/`, tetapi aplikasi iOS hanya memakai
**3 endpoint aktif**:

| Endpoint | Untuk siapa | Isi |
| --- | --- | --- |
| `POST /account` | donor & profil dasar admin | onboarding, profil, dashboard, event detail, buat/batal booking, riwayat |
| `POST /operations` | admin workspace aktif | kelola event, publish, scan QR, terima/tolak donasi, rekap |
| `POST /admin-banner` | admin workspace aktif | upload gambar banner (khusus gambar, maksimal 5 MiB) |

Semua endpoint selalu `POST`, memakai field `action` di body, dan butuh JWT pengguna yang valid.

Fungsi lain di folder yang sama (`resolve-event`, `create-booking`, `verify-donor-booking`,
`donor-booking-status`, dan helper lama lainnya) adalah **fungsi legacy** yang disimpan demi
kompatibilitas/retensi. Mereka **bukan** contract UI baru — UI baru tidak boleh menambah traffic ke
sana.

### c. Supabase Auth, Storage, dan pg_cron

- **Auth** — login email/password dan Sign in with Apple; password minimal 12 karakter; rotasi
  refresh token aktif.
- **Storage** — 3 bucket:

  | Bucket | Akses | Path |
  | --- | --- | --- |
  | `event-banners` | baca publik; write server-side lewat `admin-banner` | dibuat server per workspace/event |
  | `profile-avatars` | private; user hanya kelola folder sendiri | `<auth-user-id>/<filename>` |
  | `workspace-logos` | baca publik; admin pemilik boleh tulis | `<workspace-id>/<filename>` |

  Avatar dan logo diunggah klien iOS langsung ke Storage REST dengan JWT; banner event **tidak**
  boleh diunggah klien langsung.

- **pg_cron** — tugas otomatis: rekonsiliasi event/booking kedaluwarsa (tiap menit), retensi data
  (harian), cleanup banner orphan (harian), cleanup profile media orphan (harian, 20:17 UTC).

---

## 3. Alur satu request (bagian terpenting)

Contoh: donor menekan "Booking".

```text
1. App mengambil JWT (token login) dari Supabase Auth
2. App mengirim POST ke /functions/v1/account
   header: Authorization: Bearer <JWT>, apikey: <publishable key>, Idempotency-Key
3. Edge Function memeriksa request (validasi, rate limit, izin, role)
4. Edge Function memanggil RPC database, mis. create_account_booking_v2
5. RPC schema `api` (SECURITY INVOKER) → implementasi di schema `private`
   → cek auth.uid(), role, workspace → tulis ke tabel `public` dalam satu transaksi
6. Balasan selalu berbentuk sama:
   { "data": {...}, "error": null, "request_id": "…", "server_time": "…" }
```

Diagram komponennya:

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

**Kunci desainnya:** aplikasi **tidak pernah** menulis langsung ke tabel domain. Migration
`20260910000006_reject_direct_table_writes.sql` menolak insert langsung dari role aplikasi. Semua
harus lewat Edge Function. Tujuannya: semua aturan bisnis (kapasitas penuh? sudah pernah booking
event ini? role-nya benar?) diperiksa di satu tempat yang tidak bisa dibohongi app.

Di sisi iOS: SDK `supabase-swift` (pin 2.55.1) dipakai **hanya untuk Auth** lewat
`Core/Backend/Supabase/SupabaseAuthSession.swift`. Semua akses data memakai `URLSession` biasa ke
Edge Functions, dengan token dari SDK ditempel manual ke header oleh
`OrganizerBackendHTTPClient` dan `AccountBackendHTTPClient`.

### Bentuk respons

```json
{
  "data": {},
  "error": null,
  "request_id": "uuid",
  "server_time": "2026-09-15T00:00:00.000Z"
}
```

Saat gagal: `data` bernilai `null`, `error` memuat `code`, `retryable`, dan — bila aman —
`field_errors`.

| HTTP | Makna umum |
| --- | --- |
| 400 | request, format, atau idempotency key tidak valid |
| 401 | JWT tidak ada/tidak valid |
| 403 | role, onboarding, atau workspace tidak berhak |
| 404 | resource/QR tidak ada atau tidak terlihat oleh actor |
| 409 | state, kapasitas, atau idempotency conflict |
| 422 | validasi bisnis/payload |
| 500 | kegagalan internal; hanya retry bila `retryable: true` |

---

## 4. Yang membuat backend ini dijaga ketat

Penjelasan sederhananya:

- **RLS (Row Level Security)** — setiap baris tabel punya "label pemilik", dan database sendiri
  menolak kalau kamu bukan pemiliknya. Jadi walau ada bug di server, donor A tidak bisa melihat
  data donor B.
- **Idempotency Key** — kalau koneksi putus lalu app retry, sistem tidak membuat booking dobel. Ia
  mengenali "ini request yang sama" lewat kunci unik. Berguna untuk `create_booking`,
  `cancel_booking`, `publish_event`, `cancel_or_delete_event`, `decide_reception`, dan
  `advance_tracking`.
- **PII dienkripsi** — nama donor, nomor telepon, dan QR token disimpan dengan AES-GCM; hash
  terpisah dipakai untuk lookup. QR token ditaruh di Keychain iOS
  (`Core/Backend/Domain/QRTokenKeychain.swift`) dan dilarang masuk log atau analytics.
- **Dua kunci berbeda** — `publishable key` aman berada di app; `service-role key` (kunci
  "superadmin" yang bisa menembus RLS) hanya boleh ada di secret server. Aturan keamanan nomor satu:
  **jangan pernah** menaruh service-role key di aplikasi, konfigurasi publik, log, atau dokumentasi.
- **Kapasitas dan status dihitung server** — status event dan kedaluwarsa booking ditentukan
  server-side; client tidak boleh menentukan status terminal berdasarkan jam perangkat.
- **Log aman** — Edge Function hanya mencatat request ID, nama function, durasi, outcome, dan safe
  error code — bukan body, PII, ciphertext, atau token.

---

## 5. Role dan alur status domain

Setelah registrasi, pengguna menyelesaikan onboarding sekali sebagai salah satu role:

| Role | Kepemilikan | Hak utama |
| --- | --- | --- |
| `donor` | profil sendiri dan booking miliknya | discovery event, membuat/membatalkan booking, melihat QR dan riwayat sendiri |
| `admin` | satu workspace yang dimilikinya | mengelola event workspace, scan QR, menerima/menolak donasi, tracking, recap, riwayat workspace |

Role tidak dapat diubah sembarang setelah onboarding. Workspace bisa `active` atau `disabled`;
hanya workspace aktif yang bisa menjalankan operasi admin.

```text
Event:    draft → upcoming / ongoing → completed | cancelled

Booking:  waiting → accepted → processed → recycled
                     └→ rejected
          waiting → expired | cancelled
```

- Donor hanya dapat membatalkan booking berstatus `waiting`.
- Reception admin menerima `accepted` atau `rejected`; penerimaan butuh berat aktual positif.
- Tracking hanya menerima `accepted → processed → recycled`.

---

## 6. Konfigurasi dan cara menjalankan

### Sisi aplikasi iOS

Konfigurasi dibaca dari `Config/Base.xcconfig` + `Config/{Debug,Staging,Release}.xcconfig`. Nilai
aslinya berada di `Config/Secrets.xcconfig` (gitignored). Nilai diteruskan menjadi:

- `KumpulBackendURL`
- `KumpulBackendPublishableKey`
- `KumpulBackendEnvironment`

URL hanya menerima HTTPS, kecuali local host `127.0.0.1` untuk development lokal. Yang berada di app
hanya publishable/anon key.

### Sisi backend lokal

Konfigurasi ada di `supabase/config.toml`. Validasi yang tersedia:

```bash
supabase start                      # nyalakan Supabase lokal (butuh Docker)
supabase db reset                   # jalankan semua migration + seed.sql
supabase test db --local            # test database (pgTAP)
bash supabase/tests/concurrency/run.sh
bash supabase/tests/http/smoke.sh
bash supabase/tests/load/run.sh

deno fmt --check --config supabase/functions/deno.json supabase/functions supabase/tests/load/run.ts
deno lint --config supabase/functions/deno.json supabase/functions supabase/tests/load/run.ts
deno test --config supabase/functions/deno.json --allow-env supabase/functions/_tests
```

⚠️ **Penting:** untuk development Mac yang memakai hosted staging, **jangan** menjalankan local
Docker / `supabase start` / `supabase db reset`. Pakai konfigurasi Xcode `Staging` dan audit
read-only.

### Aturan mengubah database

- Repository memakai migration imperatif berurutan di `supabase/migrations/` — **selalu** buat file
  migration baru lewat CLI, review SQL-nya, lalu validasi.
- Jangan mengedit hosted database lewat Dashboard kecuali dalam keadaan incident.
- Jangan mengubah `.xcodeproj` untuk konfigurasi backend.
- CI backend: `.github/workflows/backend-ci.yml`.

---

## 7. Data offline di perangkat

App menyimpan sebagian data di SwiftData agar tetap nyaman dipakai saat sinyal buruk
(`Core/Backend/Cache/`).

| Perilaku | Isi |
| --- | --- |
| Di-cache | daftar event admin + banner (`CachedEvent`), cursor sinkronisasi (`SyncState`) |
| Antre offline | **hanya** draft event admin (`PendingDraft`), dikirim saat kembali online |
| Wajib online | publish event, batal/hapus event, semua operasi donor (booking, QR), reception, dan report |
| Tidak di-cache | data donor |

Cache dipurge saat logout atau hapus akun.

---

## 8. Glosarium istilah

| Istilah | Arti gampang |
| --- | --- |
| **Edge Function** | fungsi server yang jalan hanya saat dipanggil (serverless), bahasa TypeScript di Deno |
| **RPC** | fungsi yang disimpan di dalam database, dipanggil server untuk melakukan satu operasi utuh |
| **Migration** | file SQL untuk mengubah struktur database secara berurutan dan tercatat di git |
| **RLS** | aturan "siapa boleh lihat/ubah baris mana" yang ditegakkan oleh database |
| **JWT** | karcis bukti login, ditempel di header tiap request |
| **Idempotency** | anti-duplikasi: request yang sama diulang menghasilkan satu hasil saja |
| **Cursor** | penanda halaman berikutnya untuk pagination; opaque, tidak boleh dibaca/dimodifikasi |
| **Cron** | tugas otomatis terjadwal (mis. bersih-bersih file orphan) |
| **PII** | data pribadi: nama, telepon, alamat |

---

## 9. Kalau mau baca lebih lanjut

| Topik | Lokasi |
| --- | --- |
| Gambaran arsitektur (paling enak dibaca setelah dokumen ini) | [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) |
| Contract request/response rinci | [`API_CONTRACT.md`](API_CONTRACT.md) |
| Aturan produk backend | [`BACKEND_PRD.md`](BACKEND_PRD.md) |
| Runbook development, delivery, incident | [`BACKEND_RUNBOOK.md`](BACKEND_RUNBOOK.md) |
| Konfigurasi lokal Supabase | [`supabase/config.toml`](../supabase/config.toml) |
| Migration database | [`supabase/migrations/`](../supabase/migrations) |
| Edge Functions dan helper shared | [`supabase/functions/`](../supabase/functions) |
| Boundary client iOS | [`Core/Backend/`](../Core/Backend) |

---

**Ringkasnya:** backend project ini = Supabase (Postgres + Auth + Storage + Edge Functions
TypeScript), dan pola wajibnya adalah *"app → login dulu → panggil Edge Function → Edge Function
memanggil RPC database → database memutuskan"*. App tidak pernah menyentuh tabel domain langsung,
dan semua kunci rahasia berat tetap berada di server.

Saat ada perbedaan, source Edge Function dan migration terbaru adalah implementasi authoritative;
`API_CONTRACT.md` adalah contract integrasi UI; `BACKEND_PRD.md` memegang aturan produk.
