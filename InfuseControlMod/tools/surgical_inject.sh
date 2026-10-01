#!/usr/bin/env bash
# Surgically add InfuseControlMod.dylib to an IPA that ALREADY has InfusePlus,
# without re-processing (and corrupting) InfusePlus's existing dylibs.
#
# Steps:
#   1. unzip the IPA
#   2. drop our dylib next to the app executable
#   3. fix our dylib's install id and its Substrate dependency to the bundled copy
#   4. add one load command to the main executable (via LIEF)
#   5. re-zip to an output IPA (the sideloader re-signs everything on install)
#
# Usage: surgical_inject.sh <input.ipa> <controlmod.dylib> <output.ipa>
set -euo pipefail

IN_IPA="$1"; DYLIB="$2"; OUT_IPA="$3"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK="$(mktemp -d)"
echo "Workdir: $WORK"
cp "$IN_IPA" "$WORK/in.ipa"
cp "$DYLIB" "$WORK/InfuseControlMod.dylib"

cd "$WORK"
mkdir extracted && cd extracted
unzip -q "$WORK/in.ipa"

APP="$(ls -d Payload/*.app | head -1)"
[ -n "$APP" ] || { echo "::error::No .app found in IPA"; exit 1; }
EXE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
echo "App bundle : $APP"
echo "Executable : $EXE"

# 2. place our dylib next to the executable
cp "$WORK/InfuseControlMod.dylib" "$APP/InfuseControlMod.dylib"
chmod 0644 "$APP/InfuseControlMod.dylib"

# 3. fix our dylib's own id + repoint its Substrate dependency to the bundled one
install_name_tool -id "@executable_path/InfuseControlMod.dylib" "$APP/InfuseControlMod.dylib"
SUB="$(otool -L "$APP/InfuseControlMod.dylib" | awk 'tolower($1) ~ /substrate/ {print $1; exit}')"
if [ -n "${SUB:-}" ] && [ "$SUB" != "@executable_path/libsubstrate.dylib" ]; then
  echo "Repointing Substrate dependency: $SUB -> @executable_path/libsubstrate.dylib"
  install_name_tool -change "$SUB" "@executable_path/libsubstrate.dylib" "$APP/InfuseControlMod.dylib"
else
  echo "Substrate dependency: ${SUB:-none found} (left as-is)"
fi
echo "Our dylib's final deps:"; otool -L "$APP/InfuseControlMod.dylib" || true

# 4. add one load command to the main executable
python3 "$HERE/add_load_command.py" "$APP/$EXE" "@executable_path/InfuseControlMod.dylib"
echo "Confirming load command:"; otool -l "$APP/$EXE" | grep -A2 InfuseControlMod || {
  echo "::error::Load command for InfuseControlMod not found after edit"; exit 1; }

# 5. re-zip (preserve symlinks inside .framework bundles with -y)
rm -f "$OUT_IPA"
zip -qr -y "$OUT_IPA" Payload
echo "Wrote $OUT_IPA"
