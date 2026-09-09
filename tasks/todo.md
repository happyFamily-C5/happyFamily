# Todo: Penutupan Gap Backend vs PLAN.md

> Rencana desain: `tasks/plan.md`. Task dikerjakan berurutan (Phase 1 → 3).
> Verifikasi standar setiap task: `deno fmt --check && deno lint && deno check` pada `supabase/functions`, lalu CI backend (`.github/workflows/backend-ci.yml`: `supabase db reset` + `supabase test db --local` + smoke + lint/advisor + drift) hijau. Tidak ada Docker Supabase lokal di Mac.

## Phase 1: Kontrak read/detail yang hilang

### Task 1: `event_detail_v2` — RPC event detail donor
**Description:** Tambahkan `private.event_detail_impl` + `api.event_detail_v2(p_event_id)` yang mengembalikan `private.event_user_json` plus `availability` (published, belum berakhir, sisa kapasitas > 0) dan `distance_km` bila user punya lokasi rekomendasi. Event draft/cancelled/completed tidak boleh direturn. Pasang action `event_detail` di `functions/account/index.ts` (donor role).
**Acceptance criteria:**
- [ ] `event_detail_v2` mereturn max donation, received, reserved, used, availability, criteria, banner/logo, lokasi, jarak (bila ada), receiver snapshot
- [ ] Donor tanpa role / JWT invalid / event non-published → error stabil (`ROLE_FORBIDDEN` / `EVENT_NOT_FOUND`)
- [ ] pgTAP: donor dapat detail event published; draft event milik workspace tidak terlihat
**Verification:**
- [ ] pgTAP baru lulus di CI (`supabase test db --local`)
- [ ] `deno check` lulus untuk `functions/account/index.ts`
**Dependencies:** None
**Files likely touched:** migration baru, `supabase/functions/account/index.ts`, `supabase/tests/full_account_contract_test.sql`
**Estimated scope:** Medium (3 file)

### Task 2: `my_profile_v1` + `workspace_profile_v1` (read)
**Description:** RPC read profil sendiri (`api.my_profile_v1`, donor/admin) dan workspace milik admin (`api.workspace_profile_v1`) dengan shape sama seperti response `update_*_v1`. Pasang action `my_profile` (account fn) dan `workspace_profile` (operations fn).
**Acceptance criteria:**
- [ ] `my_profile_v1` mereturn role, nama, telepon, alamat, lokasi, avatar path tanpa bisa membaca profil lain
- [ ] `workspace_profile_v1` hanya untuk admin dengan workspace aktif
- [ ] pgTAP: cross-account read ditolak
**Verification:**
- [ ] pgTAP baru lulus di CI
- [ ] `deno check` lulus
**Dependencies:** None
**Files likely touched:** migration baru, `supabase/functions/account/index.ts`, `supabase/functions/operations/index.ts`, `supabase/tests/full_account_contract_test.sql`
**Estimated scope:** Small (4 file)

### Task 3: `my_bookings_v1` — daftar booking donor
**Description:** `api.my_bookings_v1()` mereturn seluruh booking milik caller (kecuali `cancelled` yang tersembunyi), berisi `booking_id`, `public_booking_id`, `status`, `estimated_weight_grams`, `actual_weight_grams` (bila accepted), `can_cancel`, event snapshot, `created_at`. Pasang action `my_bookings` di account fn.
**Acceptance criteria:**
- [ ] Hanya booking dengan `donor_user_id = auth.uid()`; booking guest legacy tidak muncul
- [ ] `can_cancel` benar hanya untuk `waiting` milik sendiri
- [ ] pgTAP: donor lain tidak melihat booking orang lain
**Verification:**
- [ ] pgTAP baru lulus di CI
- [ ] `deno check` lulus
**Dependencies:** None
**Files likely touched:** migration baru, `supabase/functions/account/index.ts`, `supabase/tests/full_account_contract_test.sql`
**Estimated scope:** Small (3 file)

### Task 4: QR payload + actual weight di `booking_detail_v2`
**Description:** Perluas `private.booking_detail_impl`: sertakan `actual_weight_grams` (join receptions) dan — hanya bila caller adalah owner donor — `qr_token_ciphertext`/`qr_token_nonce`/`crypto_key_version` untuk dirender ulang klien; admin workspace mendapat versi tanpa QR. Pasang dekripsi di action `booking_detail` account fn.
**Acceptance criteria:**
- [ ] Owner mendapat opaque QR payload (plaintext hanya hasil dekripsi Edge Function) + actual weight bila sudah accepted
- [ ] Admin workspace tidak menerima QR ciphertext; donor lain mendapat `BOOKING_NOT_FOUND`
- [ ] pgTAP: cross-account detail tetap ditolak
**Verification:**
- [ ] pgTAP baru lulus di CI
- [ ] `deno check` lulus
**Dependencies:** Task 3 (pola owner-check dibagi) — dapat juga paralel dengan kontrak `event_user_json` yang ada
**Files likely touched:** migration baru (replace impl), `supabase/functions/account/index.ts`, `supabase/tests/full_account_contract_test.sql`
**Estimated scope:** Small (3 file)

### Task 5: `admin_recap_v2(event_id?, from?, to?)` lengkap
**Description:** Ganti signature menjadi `admin_recap_v2(p_event_id uuid default null, p_from date default null, p_to date default null, p_days integer default 7)`: daily chart memakai `from/to` bila ada (fallback `p_days`), zero-fill tetap; tambah `recent_donations` (5 reception accepted terbaru: nama User via profil, actual weight, event, waktu) dan `unique_donors` (count distinct `donor_user_id`). Perbarui action `recap` di operations fn.
**Acceptance criteria:**
- [ ] `from`/`to` eksplisit mengalahkan `p_days`; tanpa keduanya perilaku lama (7 hari) tidak berubah
- [ ] `recent_donations` memakai nama profil aktif, bukan snapshot terenkripsi
- [ ] pgTAP: boundary hari/bulan `Asia/Jakarta` + zero-day tetap benar
**Verification:**
- [ ] pgTAP baru lulus di CI
- [ ] `deno check` lulus
**Dependencies:** None
**Files likely touched:** migration baru (drop+recreate `api.admin_recap_v2`), `supabase/functions/operations/index.ts`, `supabase/tests/full_account_contract_test.sql`
**Estimated scope:** Medium (3 file)

## Checkpoint: After Tasks 1–5
- [ ] CI backend hijau penuh (pgTAP + smoke + lint + advisor + drift)
- [ ] Semua endpoint baru menolak JWT invalid / role mismatch (verifikasi smoke lokal atau staging)
- [ ] Review dengan user sebelum lanjut ke hardening

## Phase 2: Hardening kontrak

### Task 6: Tolak direct write bookings/receptions/events via RLS
**Description:** Drop policy `bookings_update_owner`, `receptions_insert_owner`, `receptions_update_owner`, dan `events_update_owner` (pertahankan `events_delete_owner` draft + policy select). Seluruh mutasi hanya via RPC definer; alur guest lama tetap jalan karena Edge Function memakai service role. Tambah pgTAP regression: `authenticated` admin tidak bisa `UPDATE bookings SET status` / `INSERT receptions` / `UPDATE events SET capacity_grams` langsung.
**Acceptance criteria:**
- [ ] Grep membuktikan tidak ada caller `authenticated` yang menulis ketiga tabel (semua via RPC/service)
- [ ] pgTAP: direct write status/reception/capacity ditolak; `booking_status_events` tetap insert-ditolak
- [ ] Jalur guest `create_booking_v1`/`resolve_qr_v1`/`decide_reception_v1` tidak rusak (smoke.sh lulus)
**Verification:**
- [ ] CI backend hijau penuh termasuk `tests/http/smoke.sh`
- [ ] Concurrency runner lulus
**Dependencies:** Checkpoint Phase 1
**Files likely touched:** migration baru, `supabase/tests/full_account_contract_test.sql`
**Estimated scope:** Small (2 file)

### Task 7: Cursor pagination untuk 4 history RPC
**Description:** Tambah `p_limit integer default 50` + `p_cursor text default null` (encoding `(created_at, id)` base64, pola `encode_event_cursor`) pada `user_event_history_v1`, `user_donation_history_v1`, `admin_event_history_v1`, `admin_donation_history_v1`; response memuat `items` + `next_cursor`. Tanpa cursor = perilaku lama (backward compatible). Perbarui actions di account & operations fn untuk meneruskan limit/cursor.
**Acceptance criteria:**
- [ ] Urutan stabil `created_at desc, id desc`; tie-break tidak melompat/menduplikasi baris
- [ ] Cursor lintas account tidak mengembalikan data orang lain
- [ ] Caller tanpa limit/cursor mendapat hasil identik dengan sebelumnya
**Verification:**
- [ ] pgTAP baru lulus di CI (walk 3 halaman, gabungan = tanpa pagination)
- [ ] `deno check` lulus
**Dependencies:** Task 8 memakai parameter yang sama — kerjakan berurutan
**Files likely touched:** migration baru, `supabase/functions/account/index.ts`, `supabase/functions/operations/index.ts`, `supabase/tests/full_account_contract_test.sql`
**Estimated scope:** Medium (4 file)

### Task 8: Pemisahan "Acara Sebelumnya"
**Description:** Tambah parameter filter `p_terminal boolean default null` pada `user_event_history_v1`: `true` → hanya booking `recycled/rejected/expired` ATAU event `completed/cancelled` (Acara Sebelumnya); `false` → aktif; null = semua (default). Cancelled booking tetap tersembunyi.
**Acceptance criteria:**
- [ ] Filter `true` tidak memuat booking `waiting/accepted/processed` pada event aktif
- [ ] Default (null) tidak mengubah perilaku klien lama
- [ ] pgTAP: kategorisasi benar untuk kasus recycled, rejected, expired, event cancelled
**Verification:**
- [ ] pgTAP baru lulus di CI
- [ ] `deno check` lulus
**Dependencies:** Task 7 (signature bersama)
**Files likely touched:** migration baru, `supabase/functions/account/index.ts`, `supabase/tests/full_account_contract_test.sql`
**Estimated scope:** Small (3 file)

## Checkpoint: After Tasks 6–8
- [ ] pgTAP membuktikan direct write ditolak
- [ ] Pagination stabil & backward compatible
- [ ] CI backend hijau penuh

## Phase 3: Storage & rollout

### Task 9: Orphan cleanup avatar/logo
**Description:** Tambah fungsi pembersih objek `profile-avatars` (path yang tidak lagi direferensi `profiles.avatar_object_path`) dan `workspace-logos` (tidak direferensi `workspaces.logo_object_path`), dengan masa tenggang (mis. >7 hari) agar upload in-flight tidak terhapus. Ikuti pola `cleanup-orphan-banners`: Edge Function `cleanup-orphan-profile-media` dengan secret khusus, `verify_jwt = false` + cek secret, plus pembersihan objek lama saat replacement (delete object sebelumnya saat `avatar_object_path`/`logo_object_path` berganti — via RPC edge pada action update profil/workspace).
**Acceptance criteria:**
- [ ] Objek avatar/logo yatim > masa tenggang terhapus; objek terreferensi tidak tersentuh
- [ ] Replacement path menghapus objek lama milik owner sendiri saja
- [ ] Secret tidak bocor di response/log (secret-scan CI lulus)
**Verification:**
- [ ] pgTAP/deno test untuk logika daftar orphan
- [ ] CI backend hijau penuh
**Dependencies:** Checkpoint Phase 2
**Files likely touched:** migration baru (RPC daftar orphan), `supabase/functions/cleanup-orphan-profile-media/index.ts`, `supabase/config.toml`, `supabase/functions/account/index.ts`, `supabase/functions/operations/index.ts`
**Estimated scope:** Medium (5 file)

### Task 10: Push migration ke staging `kumpul-staging` + verifikasi parity
**Description:** Jalankan `supabase db push` (atau proses deploy yang setara sesuai `docs/BACKEND_RUNBOOK.md`) ke staging `kumpul-staging`, lalu verifikasi migration history identik dengan lokal dan uji smoke minimal satu endpoint baru per area (detail, recap, history pagination) memakai akun sintetis.
**Acceptance criteria:**
- [ ] `supabase migration list` staging == lokal, status applied
- [ ] Smoke: event detail + booking detail (QR owner) + recap from/to + history cursor berperilaku benar di staging
- [ ] Tidak ada deployment production (sesuai batasan plan)
**Verification:**
- [ ] Output perintah runbook tercantum di PR/task
- [ ] Health staging tetap `ACTIVE_HEALTHY`
**Dependencies:** Tasks 1–9
**Files likely touched:** tidak ada file kode; hanya artefak deployment
**Estimated scope:** Small (0 file)

## Checkpoint: Complete
- [ ] Semua gap audit #1–#8 tertutup (lihat `tasks/plan.md`)
- [ ] CI backend hijau penuh; staging parity terverifikasi
- [ ] Review dengan user: lanjut fase 5 (integrasi iOS) dan fase 6 (dekomisioning guest/App Clip) PLAN.md
