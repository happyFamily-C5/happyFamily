fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios lint

```sh
[bundle exec] fastlane ios lint
```

Run SwiftFormat and SwiftLint checks

### ios format

```sh
[bundle exec] fastlane ios format
```

Automatically format and autocorrect code with SwiftFormat and SwiftLint

### ios test

```sh
[bundle exec] fastlane ios test
```

Run Unit and UI tests

### ios build_debug

```sh
[bundle exec] fastlane ios build_debug
```

Build Debug app for simulator

### ios build_staging

```sh
[bundle exec] fastlane ios build_staging
```

Build Staging archive (.ipa)

### ios build_release

```sh
[bundle exec] fastlane ios build_release
```

Build Release archive (.ipa) for App Store / TestFlight

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload Beta build to TestFlight

### ios staging_beta

```sh
[bundle exec] fastlane ios staging_beta
```

Build and upload Staging build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and deploy a new version to the App Store

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
