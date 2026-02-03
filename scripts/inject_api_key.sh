#!/bin/bash
# inject_api_key.sh - Generates Secrets.plist at build time from environment variable

# Don't fail the build if this script has issues
set +e

# Output directly to the built app bundle
OUTPUT_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
OUTPUT_FILE="${OUTPUT_DIR}/Secrets.plist"

echo "🔧 Running inject_api_key.sh"
echo "   Output will be: ${OUTPUT_FILE}"

# Only generate if GROQ_API_KEY is set
if [ -z "${GROQ_API_KEY}" ]; then
    echo "⚠️  GROQ_API_KEY not set - Secrets.plist will not be generated"
    echo "   The app will try to read from Info.plist or local Secrets.plist fallback"
    exit 0
fi

# Make sure output directory exists
if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "⚠️  Output directory doesn't exist yet: ${OUTPUT_DIR}"
    echo "   Secrets.plist will be created in a later build phase if needed"
    exit 0
fi

# Create the plist file
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

if [ -f "${OUTPUT_FILE}" ]; then
    echo "✅ Generated Secrets.plist in app bundle"
else
    echo "⚠️  Failed to create Secrets.plist"
fi

exit 0
