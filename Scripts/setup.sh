#!/usr/bin/env bash
set -euo pipefail

echo "Setting up happyFamily project..."
command -v brew >/dev/null || { echo "Install Homebrew first"; exit 1; }
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
brew list swiftlint >/dev/null 2>&1 || brew install swiftlint
brew list swiftformat >/dev/null 2>&1 || brew install swiftformat
bundle install
xcodegen generate
echo "Setup complete."
