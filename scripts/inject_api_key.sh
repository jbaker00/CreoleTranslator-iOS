#!/bin/bash
# inject_api_key.sh - Copies Secrets.plist to app bundle at build time

# Always succeed even if there are issues
set +e

# Debug: Show environment
echo "🔧 Running inject_api_key.sh"
echo "   SRCROOT: ${SRCROOT}"
echo "   BUILT_PRODUCTS_DIR: ${BUILT_PRODUCTS_DIR}"
echo "   PRODUCT_NAME: ${PRODUCT_NAME}"

# Source file (in your local project directory, gitignored)
SOURCE_FILE="${SRCROOT}/Secrets.plist"

# Output directly to the built app bundle
OUTPUT_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
OUTPUT_FILE="${OUTPUT_DIR}/Secrets.plist"

echo "   Source: ${SOURCE_FILE}"
echo "   Output: ${OUTPUT_FILE}"

# Make sure output directory exists
if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "⚠️  Output directory doesn't exist yet: ${OUTPUT_DIR}"
    echo "   Waiting for app bundle to be created..."
    exit 0
fi

# Priority 1: Copy local Secrets.plist if it exists
if [ -f "${SOURCE_FILE}" ]; then
    cp "${SOURCE_FILE}" "${OUTPUT_FILE}"
    echo "✅ Copied Secrets.plist from project to app bundle"
    exit 0
fi

# Priority 2: Generate from GROQ_API_KEY environment variable if set
if [ -n "${GROQ_API_KEY}" ]; then
    cat > "${OUTPUT_FILE}" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GROQ_API_KEY</key>
    <string>${GROQ_API_KEY}</string>
</dict>
</plist>
PLIST_EOF
    echo "✅ Generated Secrets.plist from GROQ_API_KEY environment variable"
    exit 0
fi

# No source available
echo "⚠️  Neither Secrets.plist file nor GROQ_API_KEY environment variable found"
echo "   The app will fail unless you add the API key to Info.plist"
exit 0
