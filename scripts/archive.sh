#!/bin/bash
# NotesQuick - Archive & distribute both targets
# Usage: ./scripts/archive.sh [--upload]
# Add --upload to automatically submit to TestFlight after archiving

set -e

PROJECT="NotesQuick.xcodeproj"
UPLOAD=false

# App Store Connect API credentials.
# Set these in your environment (e.g. in ~/.zshrc) — do not commit real values:
#   export ASC_API_KEY="XXXXXXXXXX"
#   export ASC_API_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
API_KEY="${ASC_API_KEY:?Set ASC_API_KEY to your App Store Connect Key ID}"
API_ISSUER="${ASC_API_ISSUER:?Set ASC_API_ISSUER to your App Store Connect Issuer ID}"
API_KEY_PATH="${ASC_API_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY}.p8}"

if [[ "$1" == "--upload" ]]; then
    UPLOAD=true
fi

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Regenerate project if xcodegen is available
if command -v xcodegen &> /dev/null; then
    echo "==> Regenerating Xcode project..."
    xcodegen generate
fi

# Increment build number (shared across both targets)
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: \"$CURRENT_BUILD\"/CURRENT_PROJECT_VERSION: \"$NEW_BUILD\"/g" project.yml
echo "==> Build number: $CURRENT_BUILD → $NEW_BUILD"

# Regenerate after version bump
if command -v xcodegen &> /dev/null; then
    xcodegen generate
fi

ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
mkdir -p "$ARCHIVE_DIR"

# Archive Mac
echo ""
echo "==> Archiving NotesQuickMac..."
xcodebuild -project "$PROJECT" \
    -scheme NotesQuickMac \
    -configuration Release \
    -archivePath "$ARCHIVE_DIR/NotesQuickMac-$NEW_BUILD.xcarchive" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$API_KEY_PATH" \
    -authenticationKeyID "$API_KEY" \
    -authenticationKeyIssuerID "$API_ISSUER" \
    archive

echo "==> Mac archive complete"

# Archive iOS
echo ""
echo "==> Archiving NotesQuickiOS..."
xcodebuild -project "$PROJECT" \
    -scheme NotesQuickiOS \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_DIR/NotesQuickiOS-$NEW_BUILD.xcarchive" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$API_KEY_PATH" \
    -authenticationKeyID "$API_KEY" \
    -authenticationKeyIssuerID "$API_ISSUER" \
    archive

echo "==> iOS archive complete"

# Upload to TestFlight if requested
if $UPLOAD; then
    EXPORT_DIR="$ARCHIVE_DIR/Export"
    mkdir -p "$EXPORT_DIR"

    echo ""
    echo "==> Exporting Mac..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_DIR/NotesQuickMac-$NEW_BUILD.xcarchive" \
        -exportOptionsPlist scripts/ExportOptions-Mac.plist \
        -exportPath "$EXPORT_DIR/Mac" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$API_KEY_PATH" \
        -authenticationKeyID "$API_KEY" \
        -authenticationKeyIssuerID "$API_ISSUER"

    echo ""
    echo "==> Exporting iOS..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_DIR/NotesQuickiOS-$NEW_BUILD.xcarchive" \
        -exportOptionsPlist scripts/ExportOptions-iOS.plist \
        -exportPath "$EXPORT_DIR/iOS" \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$API_KEY_PATH" \
        -authenticationKeyID "$API_KEY" \
        -authenticationKeyIssuerID "$API_ISSUER"

    echo ""
    echo "==> Uploading Mac to TestFlight..."
    xcrun altool --upload-app \
        -f "$EXPORT_DIR/Mac/NotesQuick.pkg" \
        -t macos \
        --apiKey "$API_KEY" \
        --apiIssuer "$API_ISSUER"

    echo ""
    echo "==> Uploading iOS to TestFlight..."
    xcrun altool --upload-app \
        -f "$EXPORT_DIR/iOS/NotesQuick.ipa" \
        -t ios \
        --apiKey "$API_KEY" \
        --apiIssuer "$API_ISSUER"

    echo ""
    echo "==> Both apps uploaded to TestFlight!"
fi

echo ""
echo "============================================"
echo "  Archives complete (build $NEW_BUILD)"
echo "  Mac:  $ARCHIVE_DIR/NotesQuickMac-$NEW_BUILD.xcarchive"
echo "  iOS:  $ARCHIVE_DIR/NotesQuickiOS-$NEW_BUILD.xcarchive"
echo ""
if $UPLOAD; then
    echo "  Uploaded to TestFlight! Check App Store Connect."
else
    echo "  To distribute manually, open Xcode > Window > Organizer"
fi
echo "============================================"
