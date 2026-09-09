# Backend .kumpul: Local Development, Delivery, and Operations

Dokumen ini adalah runbook implementasi Supabase di `supabase/`. Aturan bisnis dan acceptance
criteria tetap mengacu ke `BACKEND_PRD.md`. Jangan menaruh access token, Apple credential,
service-role key, database password, atau material enkripsi di repository, log CI, issue, maupun
percakapan.

Status saat ini: source dan hosted staging sudah sinkron untuk migration serta Edge Function.
Runbook ini membedakan validasi local Docker yang dijalankan CI dari development Mac yang memakai
hosted staging.

## Toolchain yang Dipin

- Supabase CLI `2.116.0`
- Deno `2.9.6`
- Docker-compatible runtime (Docker Desktop, OrbStack, atau Colima) hanya untuk local CI/test stack
- PostgreSQL local stack mengikuti `supabase/config.toml` dan major version `17`

CI memverifikasi versi berdasarkan field versi, bukan platform CPU runner. Jalankan
`supabase --version` dan `deno --version` sebelum mendiagnosis perbedaan hasil lokal/CI.

## Menjalankan Backend Lokal

1. Salin `supabase/.env.example` menjadi `supabase/.env.local`. File tujuan sudah di-ignore.
2. Buat tiga random key 32-byte Base64 dan satu random cleanup secret. Jangan memakai value contoh.
3. Isi `PII_ENCRYPTION_KEY_BASE64` dan entry aktif pada `PII_ENCRYPTION_KEYS_JSON` dengan key yang
   sama. `TOKEN_KEY_VERSION` harus menunjuk entry aktif tersebut.
4. Export isi file hanya ke shell lokal yang akan menjalankan stack, lalu mulai Supabase.

```bash
set -a
source supabase/.env.local
set +a
supabase start
supabase db reset
```

Supabase local stack menyuntikkan URL, publishable/anon key, dan service-role key internal ke Edge
runtime. Jangan menyalin service-role key ke aplikasi. Untuk Xcode, salin
`Config/Secrets.xcconfig.example` menjadi `Config/Secrets.xcconfig`, lalu isi hanya URL backend dan
publishable key.

Untuk development Mac yang memang diarahkan ke hosted staging, jangan jalankan `supabase start`,
`supabase db reset`, atau stack Docker lokal. Gunakan target `kumpul-staging` yang terautentikasi,
jalankan migration/function audit secara read-only, dan gunakan konfigurasi Xcode `Staging`.

### Gate lokal wajib

```bash
deno fmt --check --config supabase/functions/deno.json \
  supabase/functions supabase/tests/load/run.ts
deno lint --config supabase/functions/deno.json \
  supabase/functions supabase/tests/load/run.ts
find supabase/functions -name '*.ts' -print0 \
  | xargs -0 deno check --config supabase/functions/deno.json
deno check --config supabase/functions/deno.json supabase/tests/load/run.ts
deno test --config supabase/functions/deno.json --allow-env supabase/functions/_tests
supabase test db --local
bash supabase/tests/concurrency/run.sh
bash supabase/tests/http/smoke.sh
bash supabase/tests/load/run.sh
supabase db lint --local --level warning --fail-on warning
supabase db advisors --local --type all --level warn --fail-on warn
supabase db diff --local --schema public,private,api --output-format text
```

`smoke.sh` membuat dan membersihkan organizer sintetis. `load/run.sh` memakai data sintetis, default
1.000 booking, concurrency 25, dan gagal bila p95 lokal melewati guardrail PRD. Ubah skala untuk
diagnostik cepat dengan environment `LOAD_BOOKING_COUNT`, `LOAD_CONCURRENCY`,
`LOAD_RESOLVE_COUNT`, `LOAD_QR_COUNT`, dan `LOAD_DASHBOARD_COUNT`.

Output terakhir `db diff` harus kosong. Pesan `No schema changes found` di stderr boleh muncul;
file/stdout SQL-nya tetap harus kosong.

## Perubahan Schema

Selalu buat file migration melalui CLI agar urutan versioned konsisten:

```bash
supabase migration new nama_perubahan
```

Isi migration yang baru, kemudian jalankan reset, pgTAP, lint, advisors, concurrency, dan schema
drift. Jangan mengedit schema hosted melalui Dashboard kecuali incident. Jika incident memerlukan
SQL langsung, segera buat forward-fix migration yang merekonsiliasi state hosted dengan repository.

Migration production harus additive/backward-compatible selama versi aplikasi lama masih aktif.
Untuk perubahan destructive, siapkan backup, ukuran dampak, query verifikasi, dan forward-fix
sebelum deployment. `migration repair` hanya untuk memperbaiki history yang terbukti tidak sinkron,
bukan untuk menyembunyikan migration gagal.

## Delivery Local ke Staging ke Production

Gunakan project Supabase, Auth credential, secret, Storage, domain, dan backup terpisah. Jangan
menggunakan file secret staging untuk production.

### Staging

1. Pastikan seluruh gate lokal dan build iOS lulus.
2. Untuk target yang sedang dipakai, project staging adalah `kumpul-staging` dengan ref
   `tdpvtdblphojutjifdlc`. Link checkout ke project staging:
   `supabase link --project-ref <staging-project-ref>`.
3. Periksa history dengan `supabase migration list --linked`.
4. Preview migration dengan `supabase db push --linked --dry-run`.
5. Set Edge secrets dari file yang berada di luar repository menggunakan
   `supabase secrets set --project-ref <staging-project-ref> --env-file <secure-env-file>`.
6. Terapkan migration dengan `supabase db push --linked`.
7. Deploy seluruh function dengan `supabase functions deploy --project-ref <staging-project-ref> --use-api`.
8. Provision Vault untuk Cron banner, periksa `cron.job`, lalu jalankan smoke/E2E memakai akun
   sintetis staging.
9. Jalankan TestFlight main app dan App Clip terhadap konfigurasi `Staging`.

Staging completion tidak berarti production readiness. Simpan bukti migration history, function
versions/checksum, Vault names, Cron health, Auth settings, Storage policy, dan smoke/E2E result
tanpa menyimpan secret value.

### Production

1. Bekukan kandidat release yang sudah lulus staging E2E.
2. Konfirmasi backup terakhir dan tulis timestamp rollback/restore evidence.
3. Jalankan dry-run migration terhadap production dan review SQL yang akan diterapkan.
4. Terapkan migration lebih dahulu, lalu Edge Functions yang kompatibel dengan app lama.
5. Jalankan smoke read-only, satu transaksi booking sintetis terkontrol, job health, dan capacity
   invariant query.
6. Promosikan aplikasi hanya setelah metrics dan alert aktif.

Jangan menjalankan `migration down` pada production yang sudah menerima data. Gunakan forward-fix
untuk database; untuk Edge Function, deploy kembali implementasi dari Git revision yang diketahui
baik selama kontrak databasenya masih kompatibel.

## Secret dan Rotasi Key

| Secret | Dipakai oleh | Dampak rotasi |
|---|---|---|
| `PII_ENCRYPTION_KEYS_JSON` | AES-GCM donor, QR recovery, invocation recovery | Simpan seluruh versi yang masih direferensikan row |
| `TOKEN_KEY_VERSION` | Versi AES-GCM untuk write baru | Naikkan hanya setelah keyring baru terpasang |
| `PII_HMAC_KEY_BASE64` | Phone lookup dan fingerprint rate limit | Mengubah lookup hash; jangan rotasi rutin tanpa migration/re-hash plan |
| `DONOR_ACCESS_SIGNING_KEY_BASE64` | Token satu-booking 10 menit | Semua donor token aktif langsung invalid |
| `BANNER_CLEANUP_SECRET` | Cron ke cleanup Edge Function | Update Edge secret dan Vault secara atomik |
| `PROFILE_MEDIA_CLEANUP_SECRET` | Cron ke cleanup orphan avatar/logo | Update Edge secret dan Vault secara atomik |
| `PUBLIC_BOOKING_ENABLED` | Kill switch create booking | `false` menutup write publik, resolve event tetap hidup |

### Rotasi AES-GCM aman

1. Ambil inventory non-PII `crypto_key_version` yang masih dipakai pada `bookings` dan
   `event_invocations`.
2. Tambahkan key baru ke JSON keyring tanpa menghapus versi lama.
3. Deploy keyring, lalu ubah `TOKEN_KEY_VERSION` ke versi baru dan deploy/restart function.
4. Uji decrypt row lama serta create/resolve row baru.
5. Hapus key lama hanya setelah tidak ada row yang mereferensikannya dan backup/retention policy
   mengizinkan retirement.

Key HMAC tidak memiliki version column pada MVP. Rotasi darurat akan membuat donor lookup lama tidak
cocok. Aktifkan kill switch, catat dampak, dan pilih migration/re-encryption terkontrol sebelum
memulihkan lookup; jangan diam-diam mengganti key.

## Vault dan Scheduled Jobs

Melalui Vault UI/SQL yang terautorisasi, buat secret berikut di setiap hosted project:

- `kumpul_project_url`: origin project Supabase environment tersebut.
- `kumpul_banner_cleanup_secret`: value yang sama dengan Edge secret
  `BANNER_CLEANUP_SECRET` pada environment itu.
- `kumpul_profile_media_cleanup_secret`: value yang sama dengan Edge secret
  `PROFILE_MEDIA_CLEANUP_SECRET` pada environment itu.

Jangan menulis value ke migration. Migration hanya membaca `vault.decrypted_secrets` saat job
berjalan. Job yang tersedia:

- `kumpul-lifecycle-expiry`: setiap menit.
- `kumpul-retention`: setiap hari.
- `kumpul-banner-orphan-cleanup`: setiap hari; menjadi no-op sebelum Vault lengkap.
- `kumpul-profile-media-orphan-cleanup`: setiap hari pukul 20:17 UTC; menghapus
  avatar/logo orphan yang sudah melewati grace period tujuh hari.

`private.run_lifecycle_job()` dan `private.run_retention_job()` idempotent dan hanya executable oleh
`service_role`. Cleanup banner memakai protected Edge Function endpoint dengan custom constant-time
shared-secret check dan mencatat run ke `job_runs`; endpoint ini bukan anonymous public API.

## Monitoring, Backlog, dan Alert

Edge Functions menghasilkan JSON log teredaksi dengan `request_id`, nama function, duration,
outcome, dan safe error code. Agregator hosted harus menghitung request count, error rate, dan
p50/p95/p99 per function tanpa menyimpan request body, phone, donor name, token, atau ciphertext.

View `api.operational_health_v1` hanya dapat dibaca `service_role` dan memberikan satu snapshot:

```sql
select * from api.operational_health_v1;
```

Alert minimum:

- `capacity_invariant_violations > 0`: page segera dan tutup reception write.
- lifecycle/booking backlog tetap `> 0` lebih dari lima menit: alert.
- `failed_job_runs_24h > 0` atau `stuck_job_runs > 0`: alert.
- `last_lifecycle_success_at` lebih lama lima menit: alert.
- `last_retention_success_at` lebih lama 36 jam: alert.
- p95 resolve event/QR di atas 800 ms atau create/decision/dashboard di atas 1.500 ms secara
  berkelanjutan: alert.
- database/storage quota mendekati batas plan: alert provider.
- leaked password protection Auth hanya tersedia pada Supabase Pro. Staging MVP saat ini
  sengaja tetap Free sehingga advisor akan melaporkannya disabled; ini bukan blocker MVP,
  tetapi harus dievaluasi ulang sebelum production/hardening berbayar.
- `idempotency_keys`, `job_runs`, dan `rate_limit_buckets` adalah tabel service-side dengan RLS
  tanpa policy user-facing; akses publik harus tetap ditolak dan exception ini perlu dipantau saat
  migration berubah.

`api.job_health_v1` menyediakan latest run per job untuk diagnosis. Jalankan job secara manual hanya
setelah penyebab dipahami; fungsi dirancang aman untuk catch-up/replay.

Account linking provider belum tersedia pada `AuthSession`/source saat ini. Jangan mencatat BE-AUTH-05
sebagai gate lulus sampai operasi linking yang aman benar-benar diimplementasikan dan diuji.

## Incident dan Kill Switch

Untuk menutup create booking tanpa mematikan event context, set `PUBLIC_BOOKING_ENABLED=false` pada
environment yang terdampak dan redeploy/restart Edge Functions. Verifikasi `create-booking`
mengembalikan `PUBLIC_BOOKING_DISABLED`, sedangkan `resolve-event` tetap 200.

Urutan umum incident PII/token:

1. Aktifkan kill switch bila write publik memperbesar dampak.
2. Simpan request ID, safe error code, waktu, function, dan environment; jangan salin payload/log PII.
3. Revoke invocation lewat terminate/re-publish event atau hapus donor data melalui endpoint
   terautorisasi sesuai cakupan.
4. Rotasi secret yang benar dengan dampak pada tabel di atas.
5. Jalankan capacity/backlog health dan tenant-isolation smoke.
6. Dokumentasikan data yang terdampak serta pemulihan sebelum membuka booking kembali.

## Backup dan Restore Drill

Production wajib memakai plan yang tidak dapat pause dan backup sesuai RPO 24 jam. Daftar backup
dapat diperiksa dengan `supabase backups list --project-ref <production-project-ref>`. PITR restore
melalui `supabase backups restore --project-ref <project-ref> --timestamp <unix-seconds>` bersifat
material/destructive terhadap target; jangan menjalankannya pada production sebagai latihan.

Lakukan drill pada project terisolasi dengan logical backup atau salinan yang disetujui. Catat:

- backup timestamp dan ukuran;
- start/end restore untuk membuktikan RTO maksimum delapan jam;
- migration version sebelum/sesudah;
- row counts non-PII, RLS/advisor result, job schedule, dan smoke test;
- perbedaan Storage object, Auth/provider config, Vault, dan Edge secret yang perlu diprovision ulang.

Drill belum dianggap lulus hanya karena database dapat di-connect; Auth, Storage, functions, Cron,
tenant isolation, serta satu booking/reception sintetis juga harus berhasil.
