# Rekonsiliasi Migration Repository dengan Database Hosted

Dokumen ini menjelaskan cara menangani kondisi ketika file migration sudah benar di
repository, tetapi perubahan tersebut belum ada pada database Supabase Hosted.
Contoh gejalanya: kode dan test lokal sudah lulus, namun aplikasi yang terhubung
ke staging masih menjalankan validasi atau fungsi database versi lama.

Panduan ini berlaku untuk staging dan production, tetapi contoh project di bawah
memakai staging `.kumpul` (`kumpul-staging`, ref `tdpvtdblphojutjifdlc`).

> Jangan gunakan `supabase db reset` pada Hosted untuk masalah ini. Perintah reset
> dapat menghapus data environment. Perbaiki state dengan migration yang sudah ada
> atau dengan forward-fix yang tercatat di repository.

## Konsep yang perlu dipahami

Ada dua bukti yang berbeda:

| Bukti | Menjawab pertanyaan |
| --- | --- |
| File di `supabase/migrations/` pada commit/branch yang benar | Apakah perubahan yang dimaksud ada di repository? |
| History `supabase_migrations.schema_migrations` dan definisi object database Hosted | Apakah perubahan itu benar-benar telah diterapkan dan sedang dipakai Hosted? |

File migration yang ada secara lokal tidak mengubah Hosted secara otomatis.
Sebaliknya, row history yang terlihat `applied` belum cukup membuktikan isi fungsi,
policy, trigger, atau schema Hosted benar apabila sebelumnya pernah ada perubahan
manual atau deployment terputus.

Jangan memperlakukan `supabase migration repair` sebagai deployment. Perintah itu
hanya mengubah catatan history migration; ia tidak menjalankan isi SQL migration.

## Kondisi awal dan batas aman

Sebelum mulai, pastikan hal berikut.

1. Gunakan branch/commit yang memang berisi perbaikan yang disetujui.
2. Catat environment target. Untuk staging project ini, ref harus
   `tdpvtdblphojutjifdlc`.
3. Jangan salin access token, password database, encryption key, atau isi `.env`
   ke terminal history, issue, commit, maupun chat.
4. Jangan menjalankan reset Hosted, `migration down`, atau SQL destructive untuk
   memperbaiki history yang tidak sinkron.
5. Jika target adalah production, siapkan backup dan jalankan prosedur production
   pada [BACKEND_RUNBOOK.md](BACKEND_RUNBOOK.md) terlebih dahulu.

## 1. Identifikasi migration dan perubahan yang seharusnya ada

Cari file migration yang terkait dengan bug, lalu baca seluruh isi file tersebut.

```bash
cd /Users/neuhendra/Developer/happyFamily
rtk find supabase/migrations
rtk read supabase/migrations/<versi>_<nama>.sql
```

Simpan tiga hal di catatan incident:

- versi migration, yaitu angka di awal nama file, misalnya `20260917000002`;
- object database yang diubah, misalnya function, table, policy, trigger, atau
  view;
- perubahan perilaku yang dapat diverifikasi tanpa data sensitif.

Contoh kasus optional description memakai:

```text
supabase/migrations/20260917000002_make_event_description_optional.sql
```

Migration tersebut mengganti `private.publish_event_v2_impl(uuid, uuid)` agar
`events.description` tidak lagi menjadi field wajib saat publish. Validasi nama,
banner, jadwal, lokasi, kapasitas, criteria, dan profil workspace tetap wajib.

## 2. Autentikasi CLI tanpa memuat secret aplikasi

Jangan menjalankan `source .env.local` di root repository untuk login Supabase
CLI. File itu adalah konfigurasi aplikasi dan dapat memuat nilai yang tidak valid
sebagai sintaks shell, termasuk key enkripsi. Selain itu,
`SUPABASE_ACCESS_TOKEN` yang sudah diexport dapat menimpa session hasil login
CLI.

Login memakai credential storage CLI:

```bash
cd /Users/neuhendra/Developer/happyFamily
unset SUPABASE_ACCESS_TOKEN
supabase login
unset SUPABASE_ACCESS_TOKEN
supabase projects list
```

Selesaikan login browser dan pastikan project target terlihat pada daftar. Jika
CLI meminta token secara eksplisit, buat Personal Access Token baru di Supabase
Dashboard dan gunakan token format `sbp_...`; jangan menyimpan atau menampilkannya
di dokumen ini.

## 3. Bandingkan history migration lokal dengan Hosted

Link checkout hanya ke project target, lalu tampilkan perbandingan history.

```bash
supabase link --project-ref tdpvtdblphojutjifdlc
supabase migration list --linked
```

Untuk setiap versi yang diperiksa, interpretasikan hasilnya seperti ini:

| Kondisi | Arti | Langkah berikutnya |
| --- | --- | --- |
| Versi ada pada `LOCAL`, kosong pada `REMOTE` | Migration repository belum tercatat/dijalankan di Hosted. | Lanjut ke dry-run dan `db push`. |
| Versi ada pada `LOCAL` dan `REMOTE` | History sinkron. | Tetap verifikasi object runtime bila bug Hosted masih terjadi. |
| Versi ada pada `REMOTE`, kosong pada `LOCAL` | Hosted punya perubahan yang tidak ada di checkout. | Berhenti; cari branch/migration sumber atau lakukan rekonsiliasi terpisah. Jangan push membabi buta. |
| Tidak ada baris versi, padahal file ada lokal | Pastikan nama file dan timestamp migration benar serta checkout berada pada branch yang tepat. | Perbaiki sumber/checkout dulu. |

Jika CLI tidak dapat dipakai, gunakan SQL Editor Hosted untuk pemeriksaan read-only:

```sql
select version, inserted_at
from supabase_migrations.schema_migrations
where version = '20260917000002';
```

Ganti versi dengan timestamp migration yang sedang diperiksa. Tidak ada row berarti
migration belum tercatat sebagai applied pada Hosted.

## 4. Jalur utama: deploy migration dengan Supabase CLI

Jalur ini dipilih bila migration ada di repository tetapi belum ada pada history
Hosted.

1. Pastikan `supabase migration list --linked` menunjukkan versi hanya di kolom
   `LOCAL`.
2. Preview SQL yang akan dikirim:

   ```bash
   supabase db push --linked --dry-run
   ```

3. Periksa output. Pastikan hanya migration yang memang disetujui untuk target
   environment yang akan diterapkan.
4. Terapkan migration:

   ```bash
   supabase db push --linked
   ```

5. Jalankan ulang:

   ```bash
   supabase migration list --linked
   ```

   Versi harus muncul pada `LOCAL` dan `REMOTE`.
6. Lanjutkan ke verifikasi runtime pada bagian 6. History yang sinkron belum
   menggantikan verifikasi runtime.

## 5. Jalur incident manual: SQL Editor, lalu perbaiki history

Gunakan jalur ini hanya saat deployment CLI benar-benar tidak dapat digunakan,
atau saat perbaikan harus diterapkan segera pada Hosted. Jangan menulis ulang SQL
berdasarkan ingatan.

1. Buka **Supabase Dashboard → project target → SQL Editor**.
2. Salin **seluruh** isi file migration dari repository yang sudah diverifikasi
   pada bagian 1, tanpa mengubah urutan atau menggabungkannya dengan migration
   lain.
3. Periksa sekali lagi bahwa project target adalah environment yang dimaksud.
4. Jalankan SQL tersebut dan simpan hasil suksesnya sebagai bukti incident.
5. Verifikasi object runtime dengan query pada bagian 6.
6. Hanya setelah hasil runtime benar, catat migration sebagai applied:

   ```bash
   supabase migration repair 20260917000002 --status applied --linked
   supabase migration list --linked
   ```

   Ganti `20260917000002` dengan versi yang benar. Tujuannya hanya menyelaraskan
   history karena body SQL sudah dijalankan manual pada langkah 4.

Jika SQL manual gagal, jangan menjalankan `migration repair --status applied`.
Perbaiki error dengan migration baru yang bersifat forward-fix, atau eskalasikan
jika penyebabnya tidak jelas.

## 6. Verifikasi object runtime yang dipakai Hosted

Lakukan query read-only di SQL Editor yang sesuai dengan jenis perubahan.

### Function PostgreSQL

Untuk memastikan body function Hosted, gunakan `pg_get_functiondef`:

```sql
select pg_get_functiondef(
  'private.publish_event_v2_impl(uuid,uuid)'::regprocedure
) as function_definition;
```

Bandingkan definisi yang keluar dengan migration sumber. Pada kasus optional
description, body Hosted tidak boleh membangun `field_errors` untuk
`v_event.description`.

Query ringkas berikut dapat dipakai sebagai indikator tambahan, tetapi bukan
pengganti membaca definisi saat hasilnya meragukan:

```sql
select position(
  'v_event.description' in pg_get_functiondef(
    'private.publish_event_v2_impl(uuid,uuid)'::regprocedure
  )
) as description_validation_position;
```

Nilai `0` berarti string tersebut tidak ada di body function. Untuk migration
lain, ganti `regprocedure` dengan signature function sebenarnya.

### Table, column, constraint, policy, trigger, atau view

Gunakan catalog PostgreSQL dan bandingkan dengan SQL migration:

```sql
-- Kolom dan nullable status
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = '<nama_tabel>'
order by ordinal_position;

-- Constraint tabel
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.<nama_tabel>'::regclass;

-- RLS policy
select policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = '<nama_tabel>';
```

Untuk view gunakan `pg_get_viewdef`, dan untuk trigger gunakan `pg_get_triggerdef`.
Pilih query yang membuktikan perilaku yang berubah, bukan hanya keberadaan nama
object.

## 7. Validasi perilaku tanpa smoke test

Dokumen ini tidak meminta menjalankan smoke test. Setelah object runtime benar,
lakukan satu pemeriksaan manual yang sempit dan sesuai incident pada staging.

Untuk kasus deskripsi event opsional:

1. Gunakan draft event yang seluruh field publish wajibnya sudah lengkap selain
   `description`.
2. Kosongkan description dan simpan draft.
3. Publish event.
4. Pastikan publish berhasil, dan pastikan error yang sama tidak muncul.

Jika tetap gagal, catat `request_id`, safe error code, waktu, environment, dan
action yang dipanggil. Jangan menyertakan data donor, token, atau payload sensitif.
Periksa kembali definisi function Hosted, karena UI yang benar tidak dapat
mengompensasi validasi database lama.

## 8. Bila history dan runtime tidak cocok

| Temuan | Tindakan aman |
| --- | --- |
| History belum applied, runtime masih lama | Deploy migration melalui `db push`; gunakan SQL Editor hanya untuk incident. |
| History belum applied, runtime sudah benar karena SQL Editor dipakai | Verifikasi runtime, lalu `migration repair <versi> --status applied --linked`. |
| History applied, runtime masih lama | Jangan menjalankan repair lagi. Investigasi perubahan manual, project/link yang salah, signature object yang salah, atau buat forward-fix migration baru. |
| History applied, runtime benar, UI masih gagal | Telusuri request aktual, cache/state draft, payload, dan error backend; jangan menyalahkan migration tanpa bukti. |
| Remote punya migration yang lokal tidak punya | Jangan push. Pulihkan canonical source atau lakukan rekonsiliasi yang ditinjau sebelum deployment berikutnya. |

Hindari `supabase db pull` sebagai respons pertama untuk incident ini. `db pull`
menghasilkan migration baru dari schema remote dan dapat memperumit urutan source
yang sebenarnya sudah canonical. Gunakan hanya setelah tim memutuskan Hosted adalah
source of truth untuk perubahan yang memang tidak ada di repository.

## Checklist penutupan incident

- [ ] Environment target dan project ref sudah dikonfirmasi.
- [ ] File migration dan versi canonical di repository sudah dibaca.
- [ ] `supabase migration list --linked` atau query history Hosted sudah dicatat.
- [ ] Jalur CLI atau SQL Editor dijalankan untuk migration yang tepat.
- [ ] Jika SQL Editor digunakan, `migration repair` dilakukan hanya setelah verifikasi runtime berhasil.
- [ ] Definisi object runtime Hosted cocok dengan migration sumber.
- [ ] Perilaku incident diverifikasi secara manual di staging tanpa smoke test.
- [ ] Tidak ada secret, token, password, key enkripsi, atau payload PII yang tersimpan dalam bukti incident.

## Referensi repository

- [Backend runbook](BACKEND_RUNBOOK.md) untuk delivery environment dan batas
  staging/production.
- [API contract](API_CONTRACT.md) untuk contract publish event dan aturan bahwa
  `description` bersifat opsional.
- `supabase/migrations/` sebagai source of truth perubahan database versioned.
