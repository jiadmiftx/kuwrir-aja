#!/usr/bin/env bash
# Build signed release AAB for customer_app, driver_app, and/or merchant_app.
#
# Usage:
#   ./deploy_android.sh customer_app
#   ./deploy_android.sh driver_app merchant_app
#   ./deploy_android.sh all
#
# Requires kuwrir-release.keystore in the repo root (gitignored, never commit it).

set -euo pipefail
cd "$(dirname "$0")"

KEYSTORE_PATH="$(pwd)/kuwrir-release.keystore"
export KEYSTORE_PATH
export KEYSTORE_PASSWORD="cocourir"
export KEY_ALIAS="kuwrir"
export KEY_PASSWORD="cocourir"

ALL_APPS=(customer_app driver_app merchant_app)

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <customer_app|driver_app|merchant_app|all> [...]" >&2
  exit 1
fi

if [[ ! -f "$KEYSTORE_PATH" ]]; then
  echo "Keystore not found at $KEYSTORE_PATH" >&2
  exit 1
fi

if [[ "$1" == "all" ]]; then
  APPS=("${ALL_APPS[@]}")
else
  APPS=("$@")
fi

bump_version_code() {
  local pubspec="$1/pubspec.yaml"
  python3 - "$pubspec" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", text, re.MULTILINE)
if not m:
    sys.exit(f"could not find version line in {path}")
name, code = m.group(1), int(m.group(2)) + 1
new_line = f"version: {name}+{code}"
text = text[:m.start()] + new_line + text[m.end():]
open(path, "w").write(text)
print(f"{path}: bumped to {name}+{code}")
PY
}

for app in "${APPS[@]}"; do
  if [[ ! -d "$app" ]]; then
    echo "Unknown app: $app" >&2
    exit 1
  fi
  bump_version_code "$app"
  echo "=== Building $app (appbundle, release) ==="
  (cd "$app" && flutter build appbundle --release)
  AAB="$app/build/app/outputs/bundle/release/app-release.aab"
  echo "-> $AAB"
  jarsigner -verify -verbose:summary "$AAB" | grep -E "jar verified|CN="
  echo
done

echo "Done. AAB files:"
for app in "${APPS[@]}"; do
  echo "  $app/build/app/outputs/bundle/release/app-release.aab"
done
