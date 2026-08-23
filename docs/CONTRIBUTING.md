# Contributing to happyFamily

Panduan ini menjelaskan alur kerja (workflow) pengembangan untuk semua contributor di repository `happyFamily-C5/happyFamily`.

## Daftar Isi

- [Branch Model](#branch-model)
- [Setup Awal](#setup-awal)
- [Aturan Branch](#aturan-branch)
- [Conventional Commits](#conventional-commits)
- [Alur Kerja Developer](#alur-kerja-developer)
- [Alur Release (staging → main)](#alur-release-staging--main)
- [Workflow Otomatis di GitHub](#workflow-otomatis-di-github)
- [Review & Merge PR](#review--merge-pr)
- [Catatan Penting](#catatan-penting)

---

## Branch Model

Repository ini menggunakan model **trunk-based dengan dua cabang utama**:

```text
feature/* | fix/* | chore/* | bugfix/* | refactor/*
        │
        │  Pull Request
        ▼
     staging  ─────────────►  main
     (development)          (production / release)
```

| Branch | Peran |
|---|---|
| `main` | **Default branch.** Hanya berisi kode yang siap rilis. Hanya menerima PR `staging → main`. |
| `staging` | **Target semua PR development.** Tempat integrasi `feature/*`, `fix/*`, `chore/*`, dst. |
| `feature/*` | Perubahan fungsionalitas baru. |
| `fix/*` | Perbaikan bug. |
| `chore/*` | Tugas rutin / non-fungsional (docs, tooling, CI). |
| `bugfix/*`, `refactor/*` | Variasi lain yang juga valid. |

> **Golden rule:** developer **tidak pernah** membuat PR langsung ke `main`. Semua perubahan masuk ke `staging` terlebih dahulu, lalu dipromosikan ke `main` melalui Release PR.

---

## Setup Awal

### 1. Prasyarat

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — project `.xcodeproj` **tidak di-commit** (gitignored), wajib di-generate lokal.
- Xcode 15+ (deployment target **iOS 17.0**).
- [GitHub CLI `gh`](https://cli.github.com/) (opsional, memudahkan buat PR).

### 2. Clone & generate project

```bash
git clone git@github.com:happyFamily-C5/happyFamily.git
cd happyFamily

# Generate .xcodeproj (WAJIB setelah setiap git pull yang mengubah project.yml)
xcodegen generate
```

> ⚠️ Setiap kali `project.yml` berubah (ada commit terkait), kamu **harus** menjalankan `xcodegen generate` ulang sebelum build di Xcode, karena `.xcodeproj` tidak ikut di-commit.

---

## Aturan Branch

- ❌ **Jangan pernah** `git push` langsung ke `main` atau `staging`.
- ✅ Selalu buat branch kerja dari `staging` (atau `main` jika membutuhkan base terbaru).
- ✅ Nama branch harus diawali prefix: `feature/`, `fix/`, `chore/`, `bugfix/`, `refactor/`.

```bash
# contoh
feature/login-page
fix/appclip-crash
chore/add-contributing-doc
```

---

## Conventional Commits

Semua commit **wajib** mengikuti [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <deskripsi>
```

| Type | Kegunaan | Contoh |
|---|---|---|
| `feat` | Fitur baru | `feat(login): add email login screen` |
| `fix` | Perbaikan bug | `fix(appclip): prevent crash on cold start` |
| `chore` | Tugas rutin | `chore(ci): bump action versions` |
| `docs` | Dokumentasi | `docs: add contributing guide` |
| `refactor` | Refactor tanpa ubah perilaku | `refactor(auth): extract session manager` |
| `build` | Build system / dependencies | `build(project): register App Clip target` |
| `ci` | Workflow CI | `ci: auto-retarget development PRs to staging` |
| `test` | Test | `test(auth): add unit tests` |

**Scope** (opsional tapi disarankan): area yang diubah, misal `app`, `appclip`, `project`, `ci`, `scripts`.

```bash
# contoh baik
git commit -m "feat(login): add email login screen"

# contoh buruk
git commit -m "update stuff"
```

---

## Alur Kerja Developer

### 1. Pastikan base terbaru

```bash
git checkout staging
git pull origin staging
```

### 2. Buat branch kerja

```bash
git checkout -b feature/login-page
```

### 3. Coding & commit (kecil-kecil, sering)

```bash
git add .
git commit -m "feat(login): add email input field"
git commit -m "feat(login): add password validation"
```

### 4. Push & buka PR

```bash
git push -u origin feature/login-page

# buka PR menuju staging
gh pr create --title "feat(login): add email login screen" --base staging
```

Atau buat PR lewat UI GitHub (base: `staging`).

### 5. Update branch saat menunggu review

```bash
git checkout staging
git pull origin staging
git checkout feature/login-page
git merge staging
git push
```

---

## Alur Release (staging → main)

Saat kumpulan fitur di `staging` sudah siap rilis:

### 1. Buka Release PR

```bash
gh pr create --base main --head staging \
  --title "Release: vX.Y.Z" \
  --body "Changelog:\n- feat(login): ...\n- fix(appclip): ..."
```

### 2. Review & merge

- Pastikan hanya perubahan yang diinginkan yang masuk.
- Merge PR `staging → main`.

### 3. ⚠️ Sinkronkan ulang staging setelah merge

Merge `staging → main` menghasilkan merge-commit baru di `main` yang **tidak ada** di `staging`. Untuk menjaga staging tetap sinkron (agar PR dev berikutnya bebas konflik):

```bash
git checkout staging
git pull origin main
git push origin staging
```

> Ini **wajib dilakukan setiap kali** Release PR di-merge. Lupa melakukannya membuat `staging` ketinggalan dari `main`.

---

## Workflow Otomatis di GitHub

### PR Default to Staging (`.github/workflows/pr-default-to-staging.yml`)

Workflow ini berjalan saat PR **dibuka** (`opened`) atau **dibuka ulang** (`reopened`), dan secara otomatis mengubah base PR ke `staging` jika:

```text
base == main  DAN  head != staging
```

Artinya:

| PR yang dibuat | Base otomatis menjadi | Keterangan |
|---|---|---|
| `feature/login → main` | `staging` | Retarget otomatis |
| `fix/appclip → main` | `staging` | Retarget otomatis |
| `chore/x → main` | `staging` | Retarget otomatis |
| `staging → main` | `main` | **Tidak disentuh** (Release PR) |
| `feature/login → staging` | `staging` | Tidak dimodifikasi |

**Apa artinya untukmu?**
- Jika kamu lupa memilih base `staging`, sistem akan memperbaikinya otomatis. **Tapi tetap disiplin** memilih base `staging` saat membuat PR.
- PR `staging → main` aman dan tidak akan di-retarget.

---

## Review & Merge PR

### Checklist review

- [ ] Commit mengikuti Conventional Commits
- [ ] Perubahan sesuai scope branch (`feature/`, `fix/`, dst.)
- [ ] Tidak ada perubahan tidak terkait di dalam PR
- [ ] Kode build: `xcodegen generate && xcodebuild build` lulus
- [ ] (Jika ada) Test yang relevan dijalankan

### Merge ke staging

- PR development di-merge ke `staging` (gunakan "Merge" biasa / squash sesuai preferensi tim).

---

## Catatan Penting

1. **Branch protection belum aktif.** Repo ini private dengan plan free — GitHub memblokir fitur branch protection/rulesets (error `403 Upgrade to GitHub Pro`). Secara teknis, tidak ada yang mencegah direct push ke `main`/`staging`. Perlindungan saat ini bergantung pada **workflow retarget + disiplin tim**. Jika ingin proteksi teknis, upgrade ke GitHub Pro dan aktifkan branch protection manual (Settings → Branches).

2. **CI TestFlight sedang gagal di `main`.** Workflow `.github/workflows/testflight.yml` (deploy ke TestFlight) mengalami kegagalan pada environment/secrets Fastlane. Ini **tidak terkait** alur development; sedang diperbaiki terpisah. Jangan jadikan check ini wajib di main sampai hijau.

3. **`.xcodeproj` gitignored.** Selalu jalankan `xcodegen generate` setelah `git pull` yang menyentuh `project.yml`.

4. **App Clip target.** Repo berisi dua target: `happyFamily` (app utama) dan `HappyFamilyAppClips` (App Clip). Perubahan pada App Clip mengikuti alur yang sama (`fix/appclip`, dll.).

---

## Ringkasan Singkat (TL;DR)

```bash
# 1. dari staging yang terbaru
git checkout staging && git pull origin staging

# 2. branch kerja
git checkout -b feature/xyz

# 3. commit
git commit -m "feat(xyz): description"

# 4. push + PR ke staging
git push -u origin feature/xyz
gh pr create --base staging --title "feat(xyz): description"

# 5. saat release
gh pr create --base main --head staging --title "Release: vX.Y.Z"

# 6. setelah release di-merge, sync ulang
git checkout staging && git pull origin main && git push origin staging
```
