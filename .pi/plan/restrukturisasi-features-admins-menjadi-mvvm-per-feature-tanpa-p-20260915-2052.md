# Restrukturisasi `Features/Admins/` → MVVM per Feature (tanpa perubahan behaviour)

## Ringkasan

Memindahkan ~70 file Swift di dalam `Features/Admins/` menjadi struktur **MVVM per feature** (pola yang sudah dipakai `Features/Doners/` dan sudah diterapkan sebagian di fitur `Login`), tanpa mengubah behaviour, tipe, nama, access level, maupun logika apa pun.

**Satu-satunya perubahan isi file**: memindahkan (cut-paste identik) `struct AdminEvent` yang tertanam di `DashboardView.swift` ke file model tersendiri. Semua file lain hanya **dipindahkan** (`git mv`) dan **2 file di-rename namanya** karena typo (`FormHeaderViewswift.swift` → `FormHeaderView.swift`, `EmptyStateViewDasboard.swift` → `EmptyStateViewDashboard.swift`) — nama file tidak berpengaruh ke kompilasi Swift.

## Struktur Target

```
Features/Admins/
├── Dashboard/                          ← dari AdminViews/DashBoard/ (normalisasi nama folder)
│   ├── ViewModels/
│   │   ├── QRScannerViewModel.swift    ← dari DashboardComponents/
│   │   └── CameraManager.swift         ← dari DashboardComponents/
│   └── Views/
│       ├── DashboardView.swift         ← tanpa struct AdminEvent (dipindah ke Shared/Models/)
│       ├── DashBoard.swift             ← mock legacy statis, dari View/DashBoard.swift (TIDAK dihapus)
│       ├── QRScannerView.swift
│       ├── ScanResultView.swift
│       ├── AcceptDonationView.swift
│       ├── RejectedDonationView.swift
│       └── Components/                 ← SectionHeader, RecapCard, QRScannerPreview, OngoingEventCard,
│                                         HeaderNavigation, FloatingSearchBar, EventCard,
│                                         EmptyStateViewDashboard, DashboardTitle, AcceptedEventView
├── CreatingEvent/
│   └── Views/
│       ├── CreatingView.swift
│       ├── EventSuccessView.swift
│       └── Components/                 ← 12 file dari CreatingEventComponents/ (FormHeaderView direname)
├── EditEvent/
│   └── Views/
│       ├── EditEventView.swift
│       ├── EditEventPreview.swift
│       └── Components/                 ← 11 file dari EditEventComponents/
├── EventDetail/
│   └── Views/
│       ├── EventDetail.swift
│       └── Components/                 ← 5 file dari EventDetailComponents/
├── Login/                              ← naik dari AdminViews/Login/ (struktur MVVM sudah ada)
│   ├── Models/AppleSignInSupport.swift
│   ├── ViewModels/AppCoordinatorViewModel.swift
│   └── Views/ (+ Views/Components/ — 4 file)
├── RecapDonation/
│   └── Views/
│       ├── RecapDonation.swift
│       └── Components/                 ← StatisticCardView, DonationRowView, DonationBarChartView
└── Shared/                             ← komponen & model lintas-fitur admin
    ├── Models/
    │   ├── AdminEvent.swift            ← BARU: struct AdminEvent diekstrak dari DashboardView.swift
    │   └── AdminEventMapping.swift     ← dari AdminViews/DashBoard/ (dipakai 4 fitur + Tests)
    └── Components/
        ├── PrimaryButton.swift         ← lintas-fitur: Login, Dashboard, EventDetail, EditEvent, CreatingEvent
        ├── DonationTagChip.swift       ← lintas-fitur: CreatingEvent, EventDetail, EditEvent
        ├── AdminFlowLayout.swift       ← lintas-fitur: CreatingEvent, EditEvent
        ├── ShareSheet.swift            ← dari EventDetail/, dipakai DashboardView
        ├── IconButton.swift, Profile.swift, AdminSegmentedControl.swift   ← dari AdminComponents/
        ├── Badges/ (Badge, ClosingBadge)
        ├── Cards/ (HistoryCard, ProgressBarCard, DraftCard, ActiveCard)
        └── EventCards/ (UpcomingEvent, ActiveEvent)
```

Folder kosong sisa pemindahan (`AdminViews/`, `View/`, `AdminComponents/`) dihapus.

## Langkah Implementasi

1. **Buat direktori target** dan lakukan `git mv` untuk semua file sesuai mapping di atas (rename tercatat di index git, konsisten dengan rename Login yang sudah staged).
2. **Ekstraksi `AdminEvent`** (satu-satunya edit konten):
   - `DashboardView.swift`: hapus blok `// MARK: - Model Pendukung...` + `struct AdminEvent { ... }` (baris 335–475). View dan `#Preview` tidak disentuh; `import CoreLocation` dibiarkan.
   - Buat `Shared/Models/AdminEvent.swift` berisi kode struct yang **persis identik** + header `import CoreLocation` / `import SwiftUI`. Tidak ada perubahan satu karakter pun pada badan struct.
   - `private extension AdminEvent.preview` di `EventDetail.swift` dibiarkan (file-scoped, murni preview).
3. **Rename 2 file typo** (isi file tidak berubah): `FormHeaderViewswift.swift` → `FormHeaderView.swift`, `EmptyStateViewDasboard.swift` → `EmptyStateViewDashboard.swift`.
4. **Regenerasi proyek**: `xcodegen generate` (`.xcodeproj` gitignored; `project.yml` memasukkan seluruh `Features` sebagai source, jadi **tidak ada perubahan project.yml**).
5. **Tidak ada commit** — perubahan dibiarkan staged di atas state git saat ini (rename Login yang sudah staged ikut ter-update).

## Jaminan Behaviour Tidak Berubah

- Semua file tetap berada di target `happyFamily` (source `Features` di `project.yml`) → **modul dan namespace sama**, semua referensi tipe tetap resolve tanpa mengubah kode pemanggil.
- Tidak ada tipe/function yang di-rename, dihapus, atau diubah access level-nya; tidak ada logika yang ditulis ulang.
- `Tests/` dan `UITests/` tidak perlu diubah (`@testable import happyFamily`, tipe tidak berpindah modul) — termasuk `AdminEventMappingTests`, `AuthViewModelTests`, `AdminHistoryModelTests`.
- Script `Scripts/check_legacy_gate.sh` hanya mencocokkan identifier, bukan path → tidak terdampak.
- Tidak ada file yang dihapus; mock legacy `DashBoard.swift` beserta kit `AdminComponents` (Badges/Cards/EventCards) dipertahankan di `Shared/`.

## Di Luar Scope (sengaja tidak diubah)

- `DashboardModel`, `RecapModel`, `AuthViewModel`, `BackendAdminEvent`, dll. **tetap di `Core/Backend/Domain/`** — berada di luar `Features/Admins/` dan dipakai lintas layer/test; memindahnya adalah keputusan arsitektur terpisah.
- **Tidak mengekstrak `@State` dari `CreatingView`/`EditEventView`/`EventDetailView` menjadi ViewModel baru** — itu berisiko mengubah behaviour (dilarang oleh permintaan). Fitur tanpa ViewModel tetap hanya punya folder `Views/`.
- Tidak mengubah `project.yml`, `.swiftlint.yml` (tidak ada exclusion berbasis path), dan dokumen (tidak ada yang mereferensikan subpath `AdminViews/`/`AdminComponents/`).

## Validasi

1. `xcodegen generate` — sukses tanpa error.
2. Build: `xcodebuild -project happyFamily.xcodeproj -scheme happyFamily -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build` (RTK-filtered untuk error saja) — membuktikan semua tipe resolve & tidak ada simbol duplikat.
3. Unit test: `xcodebuild test ... -only-testing:happyFamilyTests` — memvalidasi mapping/model tidak berubah perilaku.
4. `bash Scripts/check_legacy_gate.sh` — gate statis lolos.
5. `rtk git status` + `git diff --stat` — memastikan hasil = murni rename (R), dengan hanya `DashboardView.swift` termodifikasi + `Shared/Models/AdminEvent.swift` baru.