#!/usr/bin/env bash
# generate_secrets_plist.sh
# Writes a Secrets.plist file into the current directory using the GROQ_API_KEY env var.
# The output file is safe to add to the app bundle for local testing but must remain gitignored.

set -euo pipefail

OUT_FILE="Secrets.plist"
KEY_NAME="GROQ_API_KEY"

if [[ -z "${GROQ_API_KEY:-}" ]]; then
  echo "Error: environment variable ${KEY_NAME} is not set."
  echo "Set it first, e.g. export ${KEY_NAME}=your_key_here, or set it in your CI/Xcode scheme."
  exit 2
fi

cat > "$OUT_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>${KEY_NAME}</key>
	<string>${GROQ_API_KEY}</string>
</dict>
</plist>
EOF

chmod 600 "$OUT_FILE"

echo "Wrote $OUT_FILE (permissions 600).\nMake sure $OUT_FILE is in your .gitignore so it isn't committed."