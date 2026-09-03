# 👨‍👩‍👧‍👦 happyFamily

[![iOS 26.0+](https://img.shields.io/badge/iOS-26.0%2B-blue.svg?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg?style=flat&logo=swift)](https://swift.org)
[![XcodeGen](https://img.shields.io/badge/XcodeGen-spec-brightgreen.svg?style=flat)](https://github.com/yonaskolb/XcodeGen)
[![Fastlane](https://img.shields.io/badge/Fastlane-ready-red.svg?style=flat&logo=fastlane)](https://fastlane.tools)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-integrated-yellow.svg?style=flat)](https://github.com/realm/SwiftLint)

A modern iOS application built with SwiftUI, structured using a clean modular architecture, generated with XcodeGen, and fully configured with Fastlane CI/CD automation.

---

## 📁 Project Structure

```text
happyFamily/
├── App/                # App entry point and root SwiftUI scenes
├── Features/           # Feature-specific modules and UI screens
├── Core/               # Core models, utilities, services, and networking
├── DesignSystem/       # Shared UI components, colors, and design tokens
├── Config/             # Environment xcconfigs (Base, Local, Debug, Staging, Release)
├── Resources/          # Assets, icons, fonts, and localization files
├── Tests/              # Unit test suites
├── UITests/            # UI test suites
├── supabase/           # Versioned database, Edge Functions, seed, and backend tests
├── docs/               # Product requirements and operational runbooks
├── fastlane/           # Fastlane automation pipelines (Fastfile, Appfile)
├── .github/workflows/  # GitHub Actions CI/CD workflows
├── project.yml         # XcodeGen specification
├── .swiftlint.yml      # SwiftLint configuration
├── .swiftformat        # SwiftFormat rules
└── Gemfile             # Ruby dependencies (Fastlane)
```

---

## 🛠️ Prerequisites & Tools

Ensure you have the following installed on your macOS machine:
- **Xcode 26+** with the **iOS 26+ SDK**
- **Homebrew**:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
- **XcodeGen, SwiftLint, SwiftFormat**:
  ```bash
  brew install xcodegen swiftlint swiftformat
  ```
- **Bundler & Fastlane**:
  ```bash
  bundle install
  ```

---

## Getting Started

### 1. Generate Xcode Project
Since this project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen), the `.xcodeproj` file is generated from `project.yml`:
```bash
xcodegen generate
```
Then open the generated project:
```bash
open happyFamily.xcodeproj
```

---

## Build Configurations & Environments

The project provides dedicated build configurations managed through `.xcconfig` files in the `Config/` directory:

| Environment | Configuration | Bundle Identifier | Description |
|---|---|---|---|
| **Personal Team** | `Local` | Set per developer | Local iPhone development without the official App Clip/signing team |
| **Debug** | `Debug` | `com.academy.hendraaaa.happyFamily.debug` | Local development with debug symbols |
| **Staging** | `Staging` | `com.academy.hendraaaa.happyFamily.staging` | Internal QA and TestFlight staging builds |
| **Release** | `Release` | `com.academy.hendraaaa.happyFamily` | Production App Store & TestFlight builds |

### Personal Team setup

Contributors who are not members of the official Apple Developer team can run
the main app on their own iPhone with Xcode's free Personal Team provisioning:

```bash
cp Config/LocalOverrides.xcconfig.example Config/LocalOverrides.xcconfig
open Config/LocalOverrides.xcconfig
xcodegen generate
open happyFamily.xcodeproj
```

Replace both placeholder values in `LocalOverrides.xcconfig`, then select the
`happyFamily Personal` scheme and the contributor's iPhone. If the Personal
Team ID is not known yet, select the Personal Team once under the
`happyFamilyPersonal` target's Signing & Capabilities settings, then copy the
resulting `DEVELOPMENT_TEAM` value into the local override before regenerating.

The Personal Team target intentionally excludes the App Clip and its association
entitlements. Use the official Debug/Staging/Release targets for App Clip,
TestFlight, and release validation. Never commit `LocalOverrides.xcconfig`, a
certificate, provisioning profile, or Apple Account credential.

---

## Code Quality & Linting

Format and validate your Swift code before committing:

```bash
# Check code formatting and linting
bundle exec fastlane lint

# Automatically format and autocorrect violations
bundle exec fastlane format
```

---

## Backend .kumpul

Backend MVP memakai Supabase/PostgreSQL sebagai source of truth, Edge Functions untuk boundary
public/PII, RPC untuk mutation atomik, Storage untuk banner, dan Cron untuk lifecycle/retention.
Main app menambahkan cache event serta antrean Draf offline tenant-scoped di SwiftData; mutation
operasional seperti publish, booking, QR, accept, dan reject tetap online-only.

- Product contract: [`docs/BACKEND_PRD.md`](docs/BACKEND_PRD.md)
- Local setup, deployment, key rotation, monitoring, dan recovery:
  [`docs/BACKEND_RUNBOOK.md`](docs/BACKEND_RUNBOOK.md)
- CI backend: `.github/workflows/backend-ci.yml`

Quick verification setelah local stack dan secret sementara dikonfigurasi:

```bash
supabase db reset
supabase test db --local
bash supabase/tests/http/smoke.sh
bash supabase/tests/load/run.sh
```

---

## Fastlane & CI/CD Pipelines

### Fastlane Lanes
- **Lint & Format**: `bundle exec fastlane lint` / `bundle exec fastlane format`
- **Unit & UI Tests**: `bundle exec fastlane test`
- **Build Simulator App**: `bundle exec fastlane build_debug`
- **Deploy Beta to TestFlight**: `bundle exec fastlane beta`
- **Deploy Staging to TestFlight**: `bundle exec fastlane staging_beta`
- **Release to App Store**: `bundle exec fastlane release`

### GitHub Actions
The repository includes automated CI/CD workflows under `.github/workflows/testflight.yml` for building and deploying directly to TestFlight on push to `main` or manual trigger.
