# Implementation Plan: Penutupan Gap Backend vs PLAN.md

## Overview

Audit backend (20 migration + Edge Functions + config + test) menyimpulkan ±80–85% kontrak PLAN.md sudah terimplementasi. Rencana ini menutup gap yang tersisa **sebelum cutover fase 6**, semuanya additive dan di dalam scope backend `supabase/`:

1. Kontrak read/detail yang hilang: `event_detail_v2`, `my_profile_v1`, `workspace_profile_v1` (read), `my_bookings_v1`, QR payload + actual weight di `booking_detail_v2`, dan signature `admin_recap_v2(event_id?, from?, to?)` lengkap dengan Donasi Terbaru + unique donor.
2. Hardening: direct-write rejection pada bookings.status / receptions / events capacity (RLS), cursor pagination history, pemisahan "Acara Sebelumnya".
3. Storage: orphan cleanup avatar/logo.
4. Rollout ke hosted staging `kumpul-staging`.

Scope **tidak** termasuk: integrasi iOS (fase 5 plan) dan dekomisioning guest/App Clip (fase 6, ditahan sampai staging E2E lulus sesuai plan).

## Architecture Decisions

- **Satu migration additive per task**, mengikuti pola yang sudah ada: `private.*_impl` (security definer, `set search_path = ''`) + wrapper `api.*_v{n}`, `revoke ... from public, anon`, `grant ... to authenticated, service_role`. Nomor migration monoton naik setelah `20260909031725`.
- **Semua akses donor tetap via RPC security definer** — donor tidak punya policy SELECT pada `events`/`bookings`, jadi endpoint read baru harus RPC, bukan policy RLS tambahan.
- **Edge Function tetap HTTP adapter**: RPC baru dipasang sebagai action baru di `functions/account/index.ts` (donor) dan `functions/operations/index.ts` (admin), `verify_jwt = true`. Tidak ada service key di klien.
- **Direct-write rejection via DROP POLICY, bukan revoke kolom**: aliran guest legacy (`create_booking_v1`, `resolve_qr_v1`, `decide_reception_v1`) berjalan dengan `adminClient()` (service role, bypass RLS) sehingga pencabutan policy `authenticated` tidak memengaruhi jalur lama maupun RPC definer. Draft delete admin dipertahankan (`events_delete_owner` status draft).
- **QR payload di booking detail hanya untuk owner** (`donor_user_id = auth.uid()`), dikembalikan sebagai ciphertext + nonce dan didekrip di Edge Function — konsisten dengan `resolve_account_qr_v2`, PII/QR tidak pernah plaintext di SQL atau klien.
- **Recap**: `p_days` dipertahankan sebagai default (7 hari) saat `p_from`/`p_to` null, supaya caller lama tidak rusak; `p_event_id` opsional memfilter aggregate.
- **Pagination history**: parameter `p_limit` + `p_cursor` (encoding `(created_at, id)` base64, pola `encode_event_cursor` yang sudah ada), default tanpa cursor = perilaku lama; klien iOS migrasi bertahap.
- **Test**: setiap task menambah kasus di `supabase/tests/full_account_contract_test.sql` (pgTAP, dijalankan CI Linux via `supabase test db --local`). Sesuai plan, **tidak** menjalankan Docker Supabase lokal di Mac — verifikasi lokal = `deno fmt/lint/check/test` + CI.

## Task List

### Phase 1: Kontrak read/detail yang hilang
- [ ] Task 1: `event_detail_v2` — RPC event detail untuk donor + action `account`
- [ ] Task 2: `my_profile_v1` + `workspace_profile_v1` read RPC + actions
- [ ] Task 3: `my_bookings_v1` — daftar booking milik donor
- [ ] Task 4: QR payload + actual weight di `booking_detail_v2`
- [ ] Task 5: `admin_recap_v2(event_id?, from?, to?)` + recent donations + unique donor

### Checkpoint: Phase 1
- [ ] CI backend hijau (`supabase db reset`, pgTAP, deno check, smoke)
- [ ] Semua endpoint baru menolak JWT invalid / role mismatch

### Phase 2: Hardening kontrak
- [ ] Task 6: Tolak direct write bookings/receptions/events capacity via RLS
- [ ] Task 7: Cursor pagination untuk 4 history RPC
- [ ] Task 8: Pemisahan "Acara Sebelumnya" (riwayat event terminal donor)

### Checkpoint: Phase 2
- [ ] pgTAP membuktikan admin JWT tidak bisa ubah status/reservasi langsung
- [ ] Paginasi stabil (tie-break `created_at, id`)

### Phase 3: Storage & rollout
- [ ] Task 9: Orphan cleanup avatar/logo
- [ ] Task 10: Push migration ke staging `kumpul-staging` + verifikasi parity

### Checkpoint: Complete
- [ ] Audit gap #1–#8 dari laporan audit tertutup semua
- [ ] Migration history staging == lokal
- [ ] Siap masuk fase 5 (integrasi iOS) / fase 6 (dekomisioning) PLAN.md

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Drop policy `bookings_update_owner`/`receptions_insert_owner` mematahkan alur yang belum teridentifikasi | High | Grep seluruh caller sebelum drop; semua Edge Function memakai service role/definer RPC; pgTAP regression di task yang sama |
| `booking_detail_v2` membocorkan QR ke non-owner | High | Cek `donor_user_id = auth.uid()` sebelum sertakan ciphertext; admin hanya dapat versi tanpa QR; uji throws_ok untuk cross-account |
| Pagination history = breaking change kontrak iOS | Medium | Default tanpa cursor = perilaku lama; action lama dipertahankan sampai fase 5 selesai |
| Recap `from/to` vs `p_days` ambigu | Low | `p_days` tetap default; `from/to` eksplisit menang bila keduanya ada |
| Migration nomor bentrok saat paralel | Medium | Buat migration saat mulai task (bukan sekaligus), jalankan task Phase 1 berurutan |

## Open Questions

- Apakah `my_bookings_v1` perlu memuat `qr_token_ciphertext` juga (agar QR label bisa dire-render dari riwayat), atau cukup di detail? — ikuti teks plan: QR payload wajib di **booking detail**, list tidak.
- Untuk "Acara Sebelumnya": apakah cukup filter `status in ('recycled','rejected','expired')` + event terminal pada `user_event_history_v1`, atau perlu endpoint terpisah? Rencana memakai parameter filter agar kontrak iOS tetap satu endpoint.
- Cleanup avatar/logo: pakai pola `cleanup-orphan-banners` (Edge Function + secret) atau tambah langkah pada lifecycle job DB? Rencana: Edge Function + secret (konsisten dengan pola existing).
