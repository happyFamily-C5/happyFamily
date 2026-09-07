# Build happyFamily on a Developer's Own iPhone

This guide is for developers who use their own Apple Developer account and need to run the main happyFamily app on their own physical device.

The repository uses XcodeGen. The committed `project.yml` is the source of truth; `happyFamily.xcodeproj` is generated. Each developer keeps their signing identity and bundle identifier in a local ignored file, so those values do not enter Git.

## What this setup builds

Use the `happyFamily Personal` scheme with the `Local` configuration. This builds the `happyFamilyPersonal` target, which contains the main application source and `Core`, but does not depend on the official App Clip target or the official team's App Clip association entitlements.

This path is for local development on a contributor-owned device. Use the official `happyFamily` scheme with `Debug`, `Staging`, or `Release` for App Clip, TestFlight, and production signing. Those configurations use the project's official bundle identifiers and signing setup.

## Prerequisites

Install and confirm the following before opening the project:

- macOS and Xcode compatible with the repository's current toolchain.
- XcodeGen available on the command line (`xcodegen --version`).
- An Apple Account added under **Xcode > Settings > Accounts**.
- A trusted iPhone connected to the Mac, with Developer Mode enabled.
- Access to this repository and its required local backend configuration.

An App Store Connect invitation does not make a developer a member of another Apple Developer team. Each developer must sign this local target with their own Team ID and a bundle identifier belonging to that team.

## Configure the local signing identity

From the repository root, copy the tracked example into the ignored local override file:

```bash
cp Config/LocalOverrides.xcconfig.example Config/LocalOverrides.xcconfig
open Config/LocalOverrides.xcconfig
```

Replace the placeholders with the developer's own values:

```xcconfig
HAPPYFAMILY_LOCAL_DEVELOPMENT_TEAM = ABC1234567
HAPPYFAMILY_LOCAL_BUNDLE_IDENTIFIER = com.example.happyfamily.local
```

`HAPPYFAMILY_LOCAL_DEVELOPMENT_TEAM` is the Team ID shown by Xcode for the Apple Account that will sign the app. `HAPPYFAMILY_LOCAL_BUNDLE_IDENTIFIER` must be unique for this developer and must not reuse any official identifier, such as:

```text
com.academy.hendraaaa.happyFamily
com.academy.hendraaaa.happyFamily.debug
com.academy.hendraaaa.happyFamily.staging
```

Give every developer a different reverse-DNS identifier, for example:

```text
com.alice.happyfamily.local
com.budi.happyfamily.local
com.citra.happyfamily.local
```

Do not commit `Config/LocalOverrides.xcconfig`. It is ignored by Git and must remain local to the developer's machine. Never put Apple passwords, verification codes, certificates, or provisioning profiles in this file.

## Generate and open the project

Run XcodeGen after creating or changing the override file:

```bash
xcodegen generate
open happyFamily.xcodeproj
```

Do not edit `happyFamily.xcodeproj/project.pbxproj` to make this configuration permanent. XcodeGen can regenerate that file at any time from `project.yml`.

## Select the device and scheme

In Xcode:

1. Select the connected iPhone as the run destination.
2. Select the **`happyFamily Personal`** scheme.
3. Confirm the **Local** configuration is used for Run.
4. In the target's **Signing & Capabilities**, select the developer's own Team if Xcode asks for it.
5. Press **Run**.

The generated Personal scheme uses `Local` for Run, Test, and Analyze. The local target has no App Clip dependency and no official App Clip entitlement, which is required for developers whose Apple Account is not part of the official signing team.

The first installation on a device may require the developer to trust the developer app under the iPhone's device management settings. Follow the on-device prompt shown by iOS.

## Verify the configuration from Terminal

These commands confirm that the local values are reaching the generated target without printing credentials:

```bash
xcodebuild -project happyFamily.xcodeproj \
  -target happyFamilyPersonal \
  -configuration Local \
  -showBuildSettings | rg 'DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_ENTITLEMENTS'
```

For a simulator or unsigned compile check:

```bash
xcodebuild -project happyFamily.xcodeproj \
  -scheme 'happyFamily Personal' \
  -configuration Local \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

The expected local values are the developer's Team ID, their unique bundle identifier, and an empty `CODE_SIGN_ENTITLEMENTS` value for the Personal target.

## Troubleshooting

### “Signing requires a development team”

Check that:

1. The Apple Account is present in Xcode Settings.
2. `HAPPYFAMILY_LOCAL_DEVELOPMENT_TEAM` contains the correct Team ID, not an email address.
3. `Config/LocalOverrides.xcconfig` exists at the repository root.
4. You ran `xcodegen generate` after changing the file.
5. The selected scheme is `happyFamily Personal`, not `happyFamily`.

### “The application identifier cannot be registered”

The local bundle identifier is already used or is not valid for the selected team. Change it to a unique reverse-DNS identifier owned by that developer, regenerate the project, and try again.

### The app builds but a capability is unavailable

The Personal target deliberately omits official App Clip association entitlements. App Clip, Associated Domains, push notification, and other team-owned capabilities must be tested with the official team configuration or through the team's TestFlight build. A successful Personal build does not prove that those production capabilities work.

### `Core` types cannot be found

Regenerate the project from the current `project.yml`. The Personal target includes `App`, `Features`, `DesignSystem`, `Resources`, and `Core`; an old generated project may not contain the current target membership.

### Local settings disappeared after a clean checkout

The override file is intentionally ignored. Recreate it from the example and run XcodeGen again. Each developer must keep their own local override file.

## Team rules

- Commit changes to `project.yml`, source code, and the example override only.
- Do not commit `Config/LocalOverrides.xcconfig`.
- Do not share Apple passwords, verification codes, signing certificates, or provisioning profiles through Git or chat.
- Do not change the official bundle identifiers to make a Personal build work.
- Use the Personal scheme for local device development and the official scheme for App Clip, staging distribution, and release validation.
- Before opening a pull request, verify that `git status` does not show the local override file and that `xcodegen generate` does not introduce unexpected project changes.
