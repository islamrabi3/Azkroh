#!/usr/bin/env bash
# Full Shorebird release for Android + iOS (same version from pubspec.yaml).
# Usage: ./scripts/release.sh
# Run it only when nothing else is building (no flutter run / Xcode build).
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER_VERSION="3.41.6"
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

echo "==> Releasing Azkroh $VERSION (Flutter $FLUTTER_VERSION)"
read -r -p "Continue? [y/N] " ok
[[ "$ok" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 1; }

rm -rf .dart_tool/flutter_build
shorebird release android --flutter-version="$FLUTTER_VERSION"

rm -rf .dart_tool/flutter_build
shorebird release ios --flutter-version="$FLUTTER_VERSION"

echo
echo "✅ Released $VERSION"
echo "Google Play: build/app/outputs/bundle/release/app-release.aab"
echo "App Store:   open build/ios/archive/Runner.xcarchive  → Distribute App"
