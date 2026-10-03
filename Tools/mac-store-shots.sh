#!/bin/bash
# Mac store screenshots without launching NotesQuick: compiles the Mac views into a windowless
# renderer and snapshots them off screen. Usage: Tools/mac-store-shots.sh <demo-folder> <lang: it|en> <note-title> <out-dir>
set -e
cd "$(dirname "$0")/.."
DEMO="$1"; LANG_="$2"; NOTE="$3"; OUT="$4"
W="${TMPDIR:-/tmp}/notesquick-macshots"; B="$W/Shots.app/Contents"
rm -rf "$W"; mkdir -p "$B/MacOS" "$B/Resources" "$W/home/Documents" "$OUT"
cp Tools/MacStoreShots.swift "$W/main.swift"   # top-level code must live in main.swift
xcrun swiftc -O -D DEBUG -swift-version 5 -target arm64-apple-macos14.0 -o "$B/MacOS/Shots" \
    $(find NotesQuick NotesQuickMac/Views -name '*.swift') "$W/main.swift"
xcrun actool NotesQuickMac/Resources/Assets.xcassets --compile "$B/Resources" --platform macosx \
    --minimum-deployment-target 14.0 --accent-color AccentColor --output-format human-readable-text >/dev/null
xcrun xcstringstool compile NotesQuick/Resources/Localizable.xcstrings --output-directory "$B/Resources"
cat > "$B/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.notesquick.storeshots</string>
<key>CFBundleExecutable</key><string>Shots</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>NSAccentColorName</key><string>AccentColor</string>
</dict></plist>
P
# A private home: the renderer never touches the real preferences or Documents.
cp -Rp "$DEMO" "$W/home/Documents/NotesQuick"
LOC=it_IT; [[ "$LANG_" == en ]] && LOC=en_US
CFFIXED_USER_HOME="$W/home" "$B/MacOS/Shots" "$OUT" "$NOTE" -screenshotMode YES -AppleLanguages "($LANG_)" -AppleLocale "$LOC"
