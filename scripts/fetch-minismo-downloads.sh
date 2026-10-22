#!/usr/bin/env bash
# Downloads the installers of the newest Kaldrivon MiniSMO releases (not drafts, not pre-releases) into
#   <out>/<version>/Kaldrivon-MiniSMO-<version>-Setup.exe and .sha256
# checks each against its published SHA-256, and writes <out>/latest.json. A release without both files is skipped.
set -euo pipefail
OUT="${1:?output folder}"
REPO="yoroyarell/KaldrivonMiniSMO"
KEEP="${KEEP:-5}"
mkdir -p "$OUT"
tags=$(gh api "repos/$REPO/releases?per_page=30" \
  --jq '[.[] | select(.draft == false and .prerelease == false)] | .[].tag_name' | head -n "$KEEP")
latest=""
for tag in $tags; do
  ver="${tag#v}"
  exe="Kaldrivon-MiniSMO-$ver-Setup.exe"
  dir="$OUT/$ver"
  mkdir -p "$dir"
  if ! gh release download "$tag" --repo "$REPO" --dir "$dir" --pattern "$exe" --pattern "$exe.sha256" --clobber; then
    echo "skipping $tag: installer or .sha256 missing"; rm -rf "$dir"; continue
  fi
  if [ ! -f "$dir/$exe" ] || [ ! -f "$dir/$exe.sha256" ]; then
    echo "skipping $tag: installer or .sha256 missing"; rm -rf "$dir"; continue
  fi
  want=$(grep -oE '[0-9a-fA-F]{64}' "$dir/$exe.sha256" | head -n1 | tr 'A-F' 'a-f')
  have=$(sha256sum "$dir/$exe" | cut -d' ' -f1)
  if [ "$want" != "$have" ]; then
    echo "::error::$exe does not match its .sha256"; exit 1
  fi
  echo "$ver: $(du -h "$dir/$exe" | cut -f1) $have"
  if [ -z "$latest" ]; then
    latest="$ver"
    printf '{"version":"%s","installer":"https://kaldrivon.com/downloads/minismo/%s/%s","sha256":"%s"}\n' \
      "$ver" "$ver" "$exe" "$have" > "$OUT/latest.json"
  fi
done
[ -n "$latest" ] || { echo "::warning::no MiniSMO release with an installer found"; }
