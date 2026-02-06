#!/bin/bash
# Pre-build script to inject API key into Secrets.swift before compilation
# This modifies the source file temporarily - it should revert after build

set -e

echo "🔐 Pre-build: Injecting API key into Secrets.swift"

SECRETS_FILE="${SRCROOT}/Secrets.swift"

# Backup original if it doesn't exist
BACKUP_FILE="${SECRETS_FILE}.original"
if [ ! -f "${BACKUP_FILE}" ]; then
    cp "${SECRETS_FILE}" "${BACKUP_FILE}"
    echo "   Created backup: ${BACKUP_FILE}"
fi

# Determine API key source
if [ -n "${GROQ_API_KEY}" ]; then
    # Use environment variable (Xcode Cloud)
    API_KEY="${GROQ_API_KEY}"
    echo "   Using GROQ_API_KEY from environment"
elif [ -f "${SRCROOT}/Secrets.plist" ]; then
    # Use local Secrets.plist
    API_KEY=$(grep -A1 "GROQ_API_KEY" "${SRCROOT}/Secrets.plist" | tail -1 | sed 's/.*<string>//;s/<\/string>.*//' | tr -d '[:space:]')
    echo "   Using API key from Secrets.plist"
else
    echo "   ⚠️  No API key source found - leaving placeholder"
    exit 0
fi

# Validate key
if [ -z "${API_KEY}" ] || [ "${API_KEY}" = "YOUR_API_KEY_HERE" ]; then
    echo "   ⚠️  Invalid API key - leaving placeholder"
    exit 0
fi

# Replace placeholder in Secrets.swift
sed -i '' "s/YOUR_API_KEY_HERE/${API_KEY}/g" "${SECRETS_FILE}"

echo "   ✅ API key injected into Secrets.swift"
echo "   Note: File will be restored after build"
