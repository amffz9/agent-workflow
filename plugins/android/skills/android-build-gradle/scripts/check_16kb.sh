#!/usr/bin/env bash
# check_16kb.sh — verify native libraries in an APK (or extracted AAB base) are 16 KB page-size compatible.
# Usage: bash check_16kb.sh <path/to/app.apk | dir with lib/> 
# Checks: (1) ELF LOAD segment alignment >= 0x4000 via readelf/llvm-readelf, (2) zipalign -P 16 if available.
set -u
TARGET="${1:?apk or directory required}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
if [[ -f "$TARGET" ]]; then unzip -q -o "$TARGET" 'lib/*' -d "$TMP" 2>/dev/null || { echo "No lib/ in $TARGET (pure Kotlin/Java app → 16 KB compatible by default)"; exit 0; }; LIBDIR="$TMP/lib"; else LIBDIR="$TARGET"; fi

READELF=$(command -v llvm-readelf || command -v readelf || true)
if [[ -z "$READELF" ]]; then
  for p in "${ANDROID_HOME:-}"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf; do [[ -x "$p" ]] && READELF="$p" && break; done
fi
[[ -z "$READELF" ]] && { echo "readelf/llvm-readelf not found (install binutils or NDK)"; exit 1; }

BAD=0; TOTAL=0
while IFS= read -r so; do
  TOTAL=$((TOTAL+1))
  # max alignment among LOAD segments; need >= 0x4000 (16384)
  ALIGN=$("$READELF" -lW "$so" 2>/dev/null | awk '$1=="LOAD"{print $NF}' | sort -u | head -n1)
  case "$ALIGN" in
    0x4000|0x10000|16384|65536) STATUS="OK ($ALIGN)";;
    "") STATUS="?? (not ELF?)";;
    *) STATUS="NOT ALIGNED ($ALIGN)"; BAD=$((BAD+1));;
  esac
  printf '%-14s %s\n' "$STATUS" "${so#$LIBDIR/}"
done < <(find "$LIBDIR" -name '*.so' | sort)

echo "---"; echo "$TOTAL libs checked, $BAD not 16 KB aligned."
if [[ -f "$TARGET" ]] && command -v zipalign >/dev/null; then
  echo "zipalign -c -P 16 -v 4 (uncompressed .so alignment inside the APK):"
  zipalign -c -P 16 -v 4 "$TARGET" | grep -E "lib/.*\.so" | grep -v "OK" || echo "  all .so entries OK"
fi
if (( BAD > 0 )); then
  echo "Fix: rebuild with NDK r28+ (or add -Wl,-z,max-page-size=16384 to ldflags), update SDKs shipping prebuilt .so, ensure android.packagingOptions.jniLibs.useLegacyPackaging=false."
  exit 2
fi
