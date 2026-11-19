#!/usr/bin/env bash
set -euo pipefail
app="$PWD/build/Build/Products/Release-iphoneos/StudyEdition.app"
output="$PWD/dist/StudyEdition-unsigned.ipa"
test -f "$app/StudyEdition"
test -f "$app/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$app/Info.plist")" == iPhoneOS ]]
if codesign -dv "$app" >/dev/null 2>&1; then
  printf '%s\n' 'App unexpectedly signed' >&2
  exit 1
fi
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload" "$(dirname "$output")"
ditto "$app" "$stage/Payload/StudyEdition.app"
(cd "$stage" && ditto -c -k Payload "$stage/new.ipa")
unzip -t "$stage/new.ipa"
unzip -Z -1 "$stage/new.ipa" | grep -Fx 'Payload/StudyEdition.app/StudyEdition'
mv "$stage/new.ipa" "$output"
shasum -a 256 "$output"
