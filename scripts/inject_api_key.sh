#!/bin/bash
# inject_api_key.sh - Copies Secrets.plist to app bundle at build time

echo "========================================="
echo "🔧 Running inject_api_key.sh"
echo "========================================="
echo "   SRCROOT: ${SRCROOT}"
echo "   BUILT_PRODUCTS_DIR: ${BUILT_PRODUCTS_DIR}"
echo "   PRODUCT_NAME: ${PRODUCT_NAME}"
echo "   TARGET_BUILD_DIR: ${TARGET_BUILD_DIR}"
echo "   CONFIGURATION: ${CONFIGURATION}"

# Source file (in your local project directory, gitignored)
SOURCE_FILE="${SRCROOT}/Secrets.plist"

echo "   Source file: ${SOURCE_FILE}"

# Check if source exists
if [ ! -f "${SOURCE_FILE}" ]; then
    echo "❌ ERROR: Secrets.plist not found at: ${SOURCE_FILE}"
    ls -la "${SRCROOT}/" | grep -i secret || echo "   No Secrets files found in SRCROOT"
    exit 1
fi

echo "   ✅ Source file exists"

# Try multiple possible output locations
if [ -n "${TARGET_BUILD_DIR}" ] && [ -n "${EXECUTABLE_FOLDER_PATH}" ]; then
    OUTPUT_DIR="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}"
    echo "   Using TARGET_BUILD_DIR method"
elif [ -n "${BUILT_PRODUCTS_DIR}" ] && [ -n "${PRODUCT_NAME}" ]; then
    OUTPUT_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
    echo "   Using BUILT_PRODUCTS_DIR method"
else
    echo "❌ Cannot determine output directory"
    echo "   Both TARGET_BUILD_DIR and BUILT_PRODUCTS_DIR are not set properly"
    exit 1
fi

OUTPUT_FILE="${OUTPUT_DIR}/Secrets.plist"

echo "   Output directory: ${OUTPUT_DIR}"
echo "   Output file: ${OUTPUT_FILE}"

# Make sure output directory exists
if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "⚠️  Output directory doesn't exist yet: ${OUTPUT_DIR}"
    # Create it if needed
    mkdir -p "${OUTPUT_DIR}" || {
        echo "❌ Failed to create output directory"
        exit 1
    }
    echo "✅ Created output directory"
fi

# Priority 1: Copy local Secrets.plist if it exists
if [ -f "${SOURCE_FILE}" ]; then
    cp -v "${SOURCE_FILE}" "${OUTPUT_FILE}" || {
        echo "❌ Failed to copy Secrets.plist"
        exit 1
    }
    
    # Verify it was copied
    if [ -f "${OUTPUT_FILE}" ]; then
        echo "✅ Copied Secrets.plist from project to app bundle"
        echo "   File size: $(ls -lh "${OUTPUT_FILE}" | awk '{print $5}')"
        exit 0
    else
        echo "❌ Secrets.plist not found after copy!"
        exit 1
    fi
fi

# Priority 2: Generate from GROQ_API_KEY environment variable if set
if [ -n "${GROQ_API_KEY}" ]; then
    cat > "${OUTPUT_FILE}" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GROQ_API_KEY</key>
    <string>GROQ_API_KEY_PLACEHOLDER</string>
</dict>
</plist>
PLIST_EOF
    
    # Replace placeholder with actual key
    sed -i '' "s/GROQ_API_KEY_PLACEHOLDER/${GROQ_API_KEY}/" "${OUTPUT_FILE}"
    
    if [ -f "${OUTPUT_FILE}" ]; then
        echo "✅ Generated Secrets.plist from GROQ_API_KEY environment variable"
        exit 0
    else
        echo "❌ Failed to generate Secrets.plist"
        exit 1
    fi
fi

# No source available
echo "❌ ERROR: Neither Secrets.plist file nor GROQ_API_KEY environment variable found!"
echo "   Source file checked: ${SOURCE_FILE}"
echo "   The app WILL FAIL without an API key"
exit 1
