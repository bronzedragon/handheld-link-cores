#!/usr/bin/env bash
# Build the patched GB/GBC Gambatte link core for x86_64 Linux.
# Run on an x86_64 Linux development host, NOT on Batocera.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="$REPO_ROOT/cores/gb-gambatte-link/patches"
UPSTREAM_URL="https://github.com/libretro/gambatte-libretro.git"
UPSTREAM_COMMIT="4041d5a6c474d2d01b4cb1e81324b06b51d0147b"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/build/x86_64/gb-gambatte-link}"
SOURCE_DIR="$WORK_DIR/gambatte-libretro"
OUT_DIR="$WORK_DIR/dist"
JOBS="${JOBS:-2}"

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "ERROR: This script requires an x86_64 Linux build host." >&2
  exit 1
fi

for tool in git gcc g++ make file readelf ldd sha256sum; do
  command -v "$tool" >/dev/null || { echo "ERROR: Missing required tool: $tool" >&2; exit 1; }
done

if [[ -e "$SOURCE_DIR" ]]; then
  echo "ERROR: Source directory exists: $SOURCE_DIR" >&2
  echo "Use an empty WORK_DIR to ensure a reproducible clean build." >&2
  exit 1
fi
mkdir -p "$WORK_DIR" "$OUT_DIR"

echo "===== Clone pinned Gambatte upstream ====="
git clone "$UPSTREAM_URL" "$SOURCE_DIR"
git -C "$SOURCE_DIR" checkout --detach "$UPSTREAM_COMMIT"
[[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" == "$UPSTREAM_COMMIT" ]]

echo "===== Apply patches in specified order ====="
while IFS= read -r patch_name || [[ -n "$patch_name" ]]; do
  [[ -z "$patch_name" || "$patch_name" == \#* ]] && continue
  git -C "$SOURCE_DIR" apply --check "$PATCH_DIR/$patch_name"
  git -C "$SOURCE_DIR" apply "$PATCH_DIR/$patch_name"
  printf 'Applied: %s\n' "$patch_name"
done < "$PATCH_DIR/series"

echo "===== Compile Linux/x86_64 libretro core ====="
make -C "$SOURCE_DIR" -B -j"$JOBS" platform=unix CC=gcc CXX=g++ 'GIT_VERSION="-4041d5a-hb-v5irh3"'

LIBRARY="$SOURCE_DIR/gambatte_libretro.so"
[[ -s "$LIBRARY" ]] || { echo "ERROR: Core was not produced." >&2; exit 1; }
cp "$LIBRARY" "$OUT_DIR/gambatte_link_libretro.so"

echo "===== Binary validation ====="
file "$OUT_DIR/gambatte_link_libretro.so"
readelf -h "$OUT_DIR/gambatte_link_libretro.so" | grep -E 'Class:|Machine:'
ldd "$OUT_DIR/gambatte_link_libretro.so"
sha256sum "$OUT_DIR/gambatte_link_libretro.so"
echo "Output: $OUT_DIR/gambatte_link_libretro.so"
echo "NOTE: Not yet validated under Batocera or across two netplay peers."
