#!/bin/bash
# Compile Eveil.app pour ce Mac. « ./build.sh --install » l'installe dans /Applications.
set -euo pipefail
cd "$(dirname "$0")"

NAME=Eveil
ID=io.github.enzo78360.eveil
APP="build/$NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13" Sources/*.swift -o "$APP/Contents/MacOS/$NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$ID</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Licence MIT</string>
</dict>
</plist>
PLIST

xattr -cr "$APP"
codesign --force --sign - "$APP"
echo "✓ $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x "$NAME" 2>/dev/null || true
  rm -rf "/Applications/$NAME.app"
  cp -R "$APP" /Applications/
  open "/Applications/$NAME.app"
  echo "✓ Installé dans /Applications et lancé"
fi
