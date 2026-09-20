# Skeleton Loading Native SwiftUI — `DesignSystem/Components/Skeleton/`

## Ringkasan

Implementasi reusable skeleton loading 100% native SwiftUI (Swift 6 / iOS 26+, tanpa dependency) dengan API tunggal `.skeleton(isLoading:)`, plus integrasi nyata ke 2 layar donor yang saat ini masih memakai `ProgressView("Memuat acara…")`.

Basis workspace: proyek `happyFamily` (XcodeGen `project.yml`, sources auto-glob dari `DesignSystem/`, iOS 26.0, test framework Swift Testing).

## Keputusan Desain

1. **Folder** — `DesignSystem/Components/Skeleton/` (struktur pilihan pertama spec; `DesignSystem/` sudah ada di repo, sudah terdaftar di `project.yml` sehingga cukup `xcodegen generate`).
2. **Tanpa `SkeletonShape.swift`** — bentuk native (`RoundedRectangle`, `Circle`, `Capsule` + `.fill(Color.secondary.opacity(…))`) sudah cukup; `.redacted` otomatis menangani Image/SF-Symbol menjadi blok abu. Abstraksi tambahan = overengineering (dilarang spec).
3. **Tanpa `ForYouCardSkeleton.swift` / `DonationCardSkeleton.swift`** — layout loading identik dengan layout loaded, jadi dipakai **komponen yang sama** (`ForYouCard`) + `.skeleton(isLoading:)`. Menghindari duplicate UI code, layout mismatch, dan layout shift.
4. **2 file** sesuai struktur yang diminta spec (`SkeletonModifier.swift` + `ShimmerModifier.swift`); tidak digabung karena spec meminta keduanya eksplisit, dan masing-masing masih clean.
5. **Shimmer** — satu band highlight `LinearGradient` (clear → highlight → clear) bergerak kiri→kanan via `offset`, `repeatForever(autoreverses: false)`, durasi 1.4s (dalam rentang 1.2–1.6s). Band di-`overlay` dan di-`mask` ke bentuk konten sehingga highlight hanya menyapu placeholder, bukan area transparan/spacing.
6. **Reduce Motion** — dicek via `@Environment(\.accessibilityReduceMotion)` saat shimmer start; jika aktif → skeleton statis (redacted saja, tanpa animasi).

## Files

### 1. NEW `DesignSystem/Components/Skeleton/SkeletonModifier.swift`

- `extension View { func skeleton(isLoading: Bool) -> some View }` — satu-satunya API yang dipakai feature.
- `private struct SkeletonModifier: ViewModifier` (private file-scope — extension ada di file yang sama, jadi tidak bocor keluar file).
- Body (`@ViewBuilder` branch):
  - `isLoading == true`: `content` → `.redacted(reason: .placeholder)` → `.modifier(ShimmerModifier())` → `.allowsHitTesting(false)` → `.accessibilityElement(children: .ignore)` + `.accessibilityLabel("Memuat konten")` (String literal → LocalizedStringKey, kompatibel String Catalog repo).
  - `isLoading == false`: `content` polos — shimmer, state, dan a11y treatment terlepas sepenuhnya ("berhenti sepenuhnya").
- Layout placeholder = layout asli (redacted mempertahankan ukuran/font Text → ramah Dynamic Type, tidak ada layout shift).
- `#Preview`: contoh card spec (rect gambar tinggi 180 + 3 Text) dalam 4 varian — loading terang, loading gelap (`.preferredColorScheme(.dark)`), loading + `.environment(\.accessibilityReduceMotion, true)`, dan loaded (toggle state).
- Catatan doc-comment: pola image placeholder untuk view tanpa image view: `RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.2)).frame(height: 180).skeleton(isLoading:)`.

### 2. NEW `DesignSystem/Components/Skeleton/ShimmerModifier.swift`

- `struct ShimmerModifier: ViewModifier` — **internal** (dipakai lintas file oleh `SkeletonModifier.swift`; satu-satunya simbol cross-file), doc-comment jelas "implementation detail — gunakan `View.skeleton(isLoading:)`".
- Members `private`: `@Environment(\.accessibilityReduceMotion)`, `@State private var phase: CGFloat = 0`, konstanta `duration = 1.4`, `bandWidthRatio = 0.6`, `highlightOpacity` (~0.4, `Color.white` — hanya untuk *highlight*, bukan warna dasar skeleton; dasar tetap dari `.redacted` yang adaptif light/dark).
- Body:
  ```swift
  content
      .overlay {
          GeometryReader { proxy in
              let bandWidth = proxy.size.width * Self.bandWidthRatio
              LinearGradient(
                  stops: [
                      .init(color: .clear, location: 0),
                      .init(color: Self.highlight, location: 0.5),
                      .init(color: .clear, location: 1)
                  ],
                  startPoint: .leading, endPoint: .trailing
              )
              .frame(width: bandWidth)
              .offset(x: -bandWidth + phase * (proxy.size.width + bandWidth))
          }
          .mask { content }   // highlight terkurung ke bentuk placeholder
      }
      .onAppear { startIfNeeded() }
  ```
  `phase` 0 → 1: band mulai sepenuhnya di kiri luar view, berakhir sepenuhnya di kanan luar; ujung gradient `.clear` membuat loop `repeatForever` tidak terlihat jumpy.
- `startIfNeeded()`: `guard !reduceMotion` lalu `withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 }`.
- Tanpa `Timer`, tanpa Combine, tanpa `Task`, tanpa `DispatchQueue`, tanpa manager/singleton — hanya mekanisme animasi SwiftUI.

### 3. EDIT `Features/Doners/Home/Views/ForYouView.swift`

Ganti branch loading (`ProgressView("Memuat acara…")` + Spacer) dengan struktur **identik** ke branch loaded (ScrollView → VStack(spacing: 32) → 3× `ForYouCard` + padding `.horizontal 20 / .top 18 / .bottom 32`), lalu:

```swift
.skeleton(isLoading: true)   // di level VStack → 1 elemen VoiceOver, 1 sapuan shimmer
```

`ForYouCard` diberi data perwakilan (panjang teks mirip data asli: judul/2 tanggal/lokasi, `bannerURL: nil`) — redacted mengubah Text & Image placeholder menjadi blok abu sesuai ukuran aslinya. Hasil: nol layout shift saat data selesai dimuat.

### 4. EDIT `Features/Doners/Home/Views/TrendingView.swift`

Edit yang sama persis (struktur file identik dengan `ForYouView`, card yang sama).

### 5. REGEN `happyFamily.xcodeproj/project.pbxproj`

Jalankan `xcodegen generate` (file pbxproj hasil generate — tidak di-edit manual). File baru di `DesignSystem/` ikut target otomatis.

## Yang TIDAK dilakukan (dan alasannya)

- **`SkeletonShape.swift`** — native shapes cukup; contoh pemakaian ada di `#Preview` SkeletonModifier.
- **`DonationCard.swift` hipotetis baru** — akan jadi dead code; contoh nyata memakai `ForYouCard` + `DonorHomeModel.isLoading` yang sudah ada (memenuhi poin "Example Card" & "ViewModel integration" spec dengan kode production sungguhan).
- **HomeView / DonorHistoryView / BannerEvent** — pola loading-nya beda (rail, pagination); follow-up mudah setelah pola ini disetujui.
- **Unit test baru** — murni view-layer (animasi/redacted), tidak layak di-unit-test tanpa snapshot framework; validasi via build + test suite existing + preview.

## Access Levels (poin spec #11)

- `View.skeleton(isLoading:)` — internal (satu-satunya permukaan API untuk feature).
- `SkeletonModifier` — `private` (file-scope; extension di file yang sama).
- `ShimmerModifier` — internal + doc "implementation detail" (wajib internal karena dipakai lintas file; alternatif `private` = gabung 2 file — trade-off ini dijelaskan di pesan akhir).
- Semua property/state/konstanta di dalam kedua struct — `private`.
- Tidak ada `public` (app target tunggal, tidak perlu ekspor modul).

## Validation

1. `xcodegen generate` → file baru terdaftar di kedua app target.
2. Build simulator: `xcodebuild -project happyFamily.xcodeproj -scheme happyFamily -destination 'platform=iOS Simulator,name=iPhone 17' build` → sukses tanpa error/warning Swift 6 strict concurrency (tidak ada Task/queue/global state, jadi aman secara struktural).
3. Test suite existing tetap hijau: `xcodebuild test … -only-testing:happyFamilyTests` (skip UI tests).
4. Visual manual: `#Preview` di `SkeletonModifier.swift` (light/dark/reduce-motion/loaded-toggle) + jalankan app → tab donor "Untuk Kamu" / "Sedang Tren" menampilkan skeleton lalu konten tanpa shift.

## Pesan akhir akan menjelaskan (sesuai daftar output spec #1, #9, #10, #11)

- Alasan folder structure & penempatan shared vs feature.
- Kenapa performant: animasi hanya `offset` (render-level, tidak memicu layout invalidation per frame), tanpa timer/task, state minimal per-view, aman dipakai banyak skeleton sekaligus di ScrollView/LazyVStack.
- Cara VoiceOver (1 elemen "Memuat konten", konten asli disembunyikan) & Reduce Motion (shimmer tidak dijalankan, placeholder statis) ditangani; catatan edge-case: toggle Reduce Motion saat shimmer sedang berjalan tidak membatalkan animasi yang sudah start (perilaku yang sama dengan app sistem).
- Trade-off access level dua-file vs satu-file.