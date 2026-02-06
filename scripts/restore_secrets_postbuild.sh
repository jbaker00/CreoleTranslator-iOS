#!/bin/bash
# Post-build script to restore Secrets.swift to original state
# This ensures the API key doesn't stay in the source file

set -e

echo "🔓 Post-build: Restoring Secrets.swift"

SECRETS_FILE="${SRCROOT}/Secrets.swift"
BACKUP_FILE="${SECRETS_FILE}.original"

if [ -f "${BACKUP_FILE}" ]; then
    cp "${BACKUP_FILE}" "${SECRETS_FILE}"
    echo "   ✅ Secrets.swift restored to placeholder"
else
    echo "   ⚠️  No backup found - skipping restore"
fi
