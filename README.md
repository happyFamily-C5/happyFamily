# 👨‍👩‍👧‍👦 happyFamily

[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue.svg?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg?style=flat&logo=swift)](https://swift.org)
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
├── Config/             # Environment xcconfigs (Base, Debug, Staging, Release)
├── Resources/          # Assets, icons, fonts, and localization files
├── Tests/              # Unit test suites
├── UITests/            # UI test suites
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
- **macOS Sonoma / Sequoia** with **Xcode 15+** (iOS 17+ SDK)
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
| **Debug** | `Debug` | `com.academy.hendraaaa.happyFamily.debug` | Local development with debug symbols |
| **Staging** | `Staging` | `com.academy.hendraaaa.happyFamily.staging` | Internal QA and TestFlight staging builds |
| **Release** | `Release` | `com.academy.hendraaaa.happyFamily` | Production App Store & TestFlight builds |

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
