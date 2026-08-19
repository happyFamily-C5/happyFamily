#!/usr/bin/env bash
set -e

echo "Setting up happyFamily project..."
brew install xcodegen swiftlint swiftformat 2>/dev/null || true
bundle install
xcodegen generate
echo "Setup complete! Open happyFamily.xcodeproj to start development."
