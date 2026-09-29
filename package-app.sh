#!/bin/zsh
# Build a self-contained, locally signed macOS app. No installer or login item.
set -eu
cd "$(dirname "$0")"
./build.sh
app="dist/DesktopFly.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/data"
cp DesktopFly "$app/Contents/MacOS/DesktopFly"
cp data/*.json data/*.md "$app/Contents/Resources/data/"
cp LICENSE "$app/Contents/Resources/LICENSE"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>DesktopFly</string>
  <key>CFBundleDisplayName</key><string>DesktopFly</string>
  <key>CFBundleIdentifier</key><string>local.desktopfly.pet</string>
  <key>CFBundleExecutable</key><string>DesktopFly</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.2.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "Ready: $PWD/$app"
