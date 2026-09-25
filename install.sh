#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

TEAM_ID="73MS2PM6D7"
DOWNLOAD_URL="https://github.com/jeremy4971/sumb_public/releases/download/v1.1.1/SUMB-1.1.1.pkg"

# Create a temporary directory for the download
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT # Clean up even if we bail out early

PKG_PATH="$TMP_DIR/$(basename "$DOWNLOAD_URL")"

echo "Downloading $DOWNLOAD_URL..."
# -f makes curl fail on HTTP errors (404, 403...) instead of saving the error page
if ! curl -fL --retry 5 --retry-delay 30 -o "$PKG_PATH" "$DOWNLOAD_URL"; then
    echo "Error: Could not download $DOWNLOAD_URL"
    echo "Please check your internet connection or that the release still exists."
    exit 1
fi

echo "Verifying the package signature..."

# pkgutil exits non-zero if the package is unsigned or the signature is broken
if ! SIGNATURE=$(pkgutil --check-signature "$PKG_PATH" 2>&1); then
    echo "Error: the package is not signed, or its signature could not be read."
    echo "$SIGNATURE"
    exit 1
fi

# Check if the signature is the correct one
if ! echo "$SIGNATURE" | grep -q "Developer ID Installer:.*($TEAM_ID)"; then
    echo "Error: the package is not signed by the expected Developer ID ($TEAM_ID)."
    echo "Aborting install."
    echo "$SIGNATURE"
    exit 1
fi

echo "Signature OK: signed by Developer ID $TEAM_ID"

echo "Installing SUMB..."
sudo installer -pkg "$PKG_PATH" -target /

echo "SUMB has been successfully installed."
