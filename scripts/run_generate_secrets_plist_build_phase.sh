#!/usr/bin/env bash
set -euo pipefail

# run_generate_secrets_plist_build_phase.sh
# Safe wrapper intended to be called from an Xcode Run Script build phase.
# It generates Secrets.plist from the GROQ_API_KEY environment variable
# and avoids printing the secret to the build log.

SCRIPTS_DIR="${SRCROOT}/scripts"
GEN_SCRIPT="${SCRIPTS_DIR}/generate_secrets_plist.sh"
OUT_FILE="${SRCROOT}/Secrets.plist"

# If GROQ_API_KEY isn't set, skip quietly (developer may use scheme env var instead)
if [ -z "${GROQ_API_KEY:-}" ]; then
  echo "🔒 GROQ_API_KEY not set — skipping Secrets.plist generation"
  exit 0
fi

# Ensure generator exists
if [ ! -x "$GEN_SCRIPT" ]; then
  if [ -f "$GEN_SCRIPT" ]; then
    chmod +x "$GEN_SCRIPT" || true
  else
    echo "⚠️ Generator script not found at $GEN_SCRIPT"
    exit 0
  fi
fi

# Run the generator script which writes Secrets.plist into ${SRCROOT}
# The generator itself will fail if GROQ_API_KEY isn't present.
# We run it but avoid echoing any sensitive output.
/bin/bash "$GEN_SCRIPT"

# Tighten permissions on the generated file
if [ -f "$OUT_FILE" ]; then
  chmod 600 "$OUT_FILE" || true
  echo "🔒 Secrets.plist generated"
else
  echo "⚠️ Expected $OUT_FILE but it was not created"
fi
