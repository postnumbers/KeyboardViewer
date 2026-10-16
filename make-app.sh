#!/bin/bash
# Builds KeyboardViewer.app (menu bar only, no Dock icon) next to this script.
#
# Running from a proper .app matters for permissions: macOS grants
# Accessibility to the app bundle rather than to Terminal, as `swift run` would.
# The app is ad-hoc signed, so after each rebuild you may need to remove and
# re-add it under System Settings › Privacy & Security › Accessibility.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="KeyboardViewer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/KeyboardViewer" "$APP/Contents/MacOS/KeyboardViewer"

# App icon. Icon/AppIcon.icns is prebuilt; if it's missing, build it from
# Icon/AppIcon.png with the macOS tools.
if [ ! -f Icon/AppIcon.icns ] && [ -f Icon/AppIcon.png ]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z $s $s Icon/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        sips -z $((s * 2)) $((s * 2)) Icon/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o Icon/AppIcon.icns
fi
cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>KeyboardViewer</string>
    <key>CFBundleIdentifier</key>          <string>local.marco.KeyboardViewer</string>
    <key>CFBundleExecutable</key>          <string>KeyboardViewer</string>
    <key>CFBundleIconFile</key>            <string>AppIcon</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>0.1</string>
    <key>CFBundleVersion</key>             <string>1</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <key>LSUIElement</key>                 <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
# Nudge Finder to pick up the new icon instead of a cached one.
touch "$APP"
echo "Built $(pwd)/$APP"
