#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "${SRCROOT:-}" ]; then
    PROJECT_ROOT="${PROJECT_ROOT:-$DEFAULT_PROJECT_ROOT}"
else
    PROJECT_ROOT="$SRCROOT"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

VERSION_FILE="$PROJECT_ROOT/MCAppsTools/VERSION"
XCCONFIG_FILE="$PROJECT_ROOT/Generated.xcconfig"

if [ ! -f "$VERSION_FILE" ]; then
    echo "error: VERSION file not found at $VERSION_FILE" >&2
    exit 1
fi

VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]' | sed 's/^v//')

if [ -z "$VERSION" ]; then
    echo "error: VERSION file is empty" >&2
    exit 1
fi

{
    echo '#include? "../PrivateBuild.xcconfig"'
    echo
    echo "MARKETING_VERSION = ${VERSION}"
} > "$XCCONFIG_FILE"
echo "Synced version ${VERSION} -> Generated.xcconfig"
