#!/bin/bash
# inject_api_key.sh - Generates Secrets.plist at build time from environment variable

set -e

# Output directly to the built app bundle
OUTPUT_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
OUTPUT_FILE="${OUTPUT_DIR}/Secrets.plist"

# Only generate if GROQ_API_KEY is set
if [ -z "${GROQ_API_KEY}" ]; then
    echo "⚠️  GROQ_API_KEY not set - Secrets.plist will not be generated"
    echo "   For TestFlight/Archive builds, set this in Xcode Cloud environment variables"
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

echo "✅ Generated Secrets.plist in app bundle"
