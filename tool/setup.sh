#!/usr/bin/env bash
# One-time setup: generates the parts of the Flutter project that `flutter create`
# owns (Gradle files, Xcode project, launcher icons), without overwriting Mari's
# own files, then fetches packages and generates the Drift database code.
#
#   ./tool/setup.sh            # Android + iOS
#   ./tool/setup.sh android    # Android only (e.g. on Linux/Windows)
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORMS="${1:-android,ios}"

echo "→ Generating platform scaffolding ($PLATFORMS). Existing files are kept."
flutter create --org zw.mari --project-name mari --platforms "$PLATFORMS" .

if [[ "$PLATFORMS" == *ios* ]]; then
  PLIST="ios/Runner/Info.plist"
  if [[ -f "$PLIST" ]] && command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
    echo "→ Registering the mari:// URL scheme for iOS Shortcuts capture"
    PB=/usr/libexec/PlistBuddy
    $PB -c "Delete :CFBundleURLTypes" "$PLIST" 2>/dev/null || true
    $PB -c "Add :CFBundleURLTypes array" "$PLIST"
    $PB -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
    $PB -c "Add :CFBundleURLTypes:0:CFBundleURLName string zw.mari.capture" "$PLIST"
    $PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
    $PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string mari" "$PLIST"
    # app_links handles the link; Flutter's built-in deep-link routing must be off.
    $PB -c "Delete :FlutterDeepLinkingEnabled" "$PLIST" 2>/dev/null || true
    $PB -c "Add :FlutterDeepLinkingEnabled bool false" "$PLIST"
    $PB -c "Set :CFBundleDisplayName Mari" "$PLIST" 2>/dev/null || true
  elif [[ -f "$PLIST" ]]; then
    echo "!  PlistBuddy not found (not on macOS). Add the mari URL scheme to $PLIST by hand — see docs/CAPTURE.md."
  fi
fi

echo "→ Fetching packages"
flutter pub get

echo "→ Generating Drift database code"
dart run build_runner build --delete-conflicting-outputs

echo "→ Generating app icons from assets/icon (the month tree on Kariba teal)"
if [[ -d ios ]]; then
  dart run flutter_launcher_icons
else
  dart run flutter_launcher_icons -f tool/icons_android.yaml
fi

echo
echo "Done. Run the app with:  flutter run"
