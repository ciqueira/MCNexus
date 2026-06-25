#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_ROOT="${MACOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
DISTRIBUTION_ROOT="${DISTRIBUTION_ROOT:-$MACOS_ROOT/Distribution}"

if [ -z "${PROJECT_ROOT:-}" ]; then
    PROJECT_ROOT="$MACOS_ROOT/MCAppsTools"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

SCHEME="${SCHEME:-MCAppsTools}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="${APP_NAME:-MCNexus}"
VERSION_FILE="${VERSION_FILE:-$PROJECT_ROOT/MCAppsTools/VERSION}"
README_FILE="${README_FILE:-$DISTRIBUTION_ROOT/README.txt}"
README_EN_FILE="${README_EN_FILE:-$DISTRIBUTION_ROOT/README-EN.txt}"
LEX_DYLIB="${LEX_DYLIB:-$MACOS_ROOT/Lex/libLexActivator.dylib}"
PRIVATE_XCCONFIG="${PRIVATE_XCCONFIG:-$MACOS_ROOT/PrivateBuild.xcconfig}"
BUILD_ROOT="${BUILD_ROOT:-${TMPDIR:-/tmp}/MCNexus-dmg-build}"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
STAGING_DIR="$BUILD_ROOT/staging"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/dist}"
SWIFT_OPTIMIZATION_LEVEL="${SWIFT_OPTIMIZATION_LEVEL:--Onone}"

if [ ! -d "$PROJECT_ROOT/MCAppsTools.xcodeproj" ]; then
    echo "error: MCAppsTools project was not found at $PROJECT_ROOT/MCAppsTools.xcodeproj" >&2
    echo "Set PROJECT_ROOT to the folder that contains MCAppsTools.xcodeproj." >&2
    exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
    echo "error: VERSION file not found at $VERSION_FILE" >&2
    exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" | sed 's/^v//')"
if [ -z "$VERSION" ]; then
    echo "error: VERSION file is empty" >&2
    exit 1
fi

if [ ! -f "$README_FILE" ]; then
    echo "error: tester README not found at $README_FILE" >&2
    exit 1
fi

if [ ! -f "$README_EN_FILE" ]; then
    echo "error: English tester README not found at $README_EN_FILE" >&2
    exit 1
fi

if [ ! -f "$LEX_DYLIB" ]; then
    echo "error: LexActivator dylib not found at $LEX_DYLIB" >&2
    echo "Install the Cryptlex LexActivator SDK locally or inject it from the private build repo." >&2
    exit 1
fi

XCODEBUILD_ARGS=(
    -project "$PROJECT_ROOT/MCAppsTools.xcodeproj"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "generic/platform=macOS"
    -derivedDataPath "$DERIVED_DATA"
)
XCODEBUILD_SETTINGS=()

if [ -f "$PRIVATE_XCCONFIG" ]; then
    XCODEBUILD_ARGS+=(-xcconfig "$PRIVATE_XCCONFIG")
else
    for required_setting in DEVELOPMENT_TEAM MCNEXUS_LOCAL_BASE_URL MCNEXUS_STAGING_BASE_URL MCNEXUS_PRODUCTION_BASE_URL; do
        if [ -z "${!required_setting:-}" ]; then
            echo "error: missing required build setting $required_setting" >&2
            echo "Set it as an environment variable or create $PRIVATE_XCCONFIG locally." >&2
            exit 1
        fi
        XCODEBUILD_SETTINGS+=("$required_setting=${!required_setting}")
    done
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$STAGING_DIR" "$OUTPUT_DIR"

SRCROOT="$PROJECT_ROOT" PRIVATE_XCCONFIG="$PRIVATE_XCCONFIG" bash "$SCRIPT_DIR/sync-version.sh"

xcodebuild \
    "${XCODEBUILD_ARGS[@]}" \
    -quiet \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGNING_ALLOWED="YES" \
    ONLY_ACTIVE_ARCH="NO" \
    ARCHS="arm64 x86_64" \
    SWIFT_OPTIMIZATION_LEVEL="$SWIFT_OPTIMIZATION_LEVEL" \
    "${XCODEBUILD_SETTINGS[@]}" \
    build

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "error: app not found at $APP_PATH" >&2
    exit 1
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
cp "$README_FILE" "$STAGING_DIR/"
cp "$README_EN_FILE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

codesign --force --deep --sign - "$STAGING_DIR/$APP_NAME.app"
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/$APP_NAME.app"

DMG_BASENAME="${APP_NAME}-${VERSION}"
TMP_DMG="$OUTPUT_DIR/${DMG_BASENAME}.tmp.dmg"
FINAL_DMG="$OUTPUT_DIR/${DMG_BASENAME}.dmg"
FALLBACK_ZIP="$OUTPUT_DIR/${DMG_BASENAME}.zip"

rm -f "$TMP_DMG" "$FINAL_DMG" "$FALLBACK_ZIP"

if hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$FINAL_DMG"; then
    echo "Created $FINAL_DMG"
elif hdiutil makehybrid \
    -hfs \
    -hfs-volume-name "$APP_NAME $VERSION" \
    -o "$FINAL_DMG" \
    "$STAGING_DIR"; then
    echo "Created $FINAL_DMG"
else
    echo "warning: hdiutil could not create a DMG; creating ZIP fallback." >&2
    ditto -c -k --keepParent "$STAGING_DIR" "$FALLBACK_ZIP"
    echo "Created $FALLBACK_ZIP"
fi

echo "Note: this build is ad-hoc signed, not Developer ID signed, and not notarized."
