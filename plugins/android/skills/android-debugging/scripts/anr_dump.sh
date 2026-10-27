#!/usr/bin/env bash
# anr_dump.sh — collect ANR traces for <pkg>: tries /data/anr (debuggable/rooted), else pulls a bugreport.
# Usage: bash anr_dump.sh <package> [outdir=build/agent/anr-<pkg>] [serial]
set -u
PKG="${1:?package name required}"; OUTDIR="${2:-build/agent/anr-${PKG}}"; SERIAL="${3:-}"
ADB=(adb); [[ -n "$SERIAL" ]] && ADB=(adb -s "$SERIAL")
mkdir -p "$OUTDIR"

echo "== Recent ANR lines in logcat =="
"${ADB[@]}" logcat -d -v threadtime | grep -E "ANR in|Reason:|Input dispatching timed out|Broadcast of Intent|executing service" | tail -n 20

if "${ADB[@]}" shell ls /data/anr/ >/dev/null 2>&1; then
  echo "== Pulling /data/anr =="
  "${ADB[@]}" pull /data/anr/ "$OUTDIR/" >/dev/null 2>&1 && ls -la "$OUTDIR"
else
  echo "== /data/anr not readable; capturing bugreport (takes ~1 min) =="
  "${ADB[@]}" bugreport "$OUTDIR/bugreport.zip" >/dev/null && unzip -q -o "$OUTDIR/bugreport.zip" -d "$OUTDIR/br"
  ls "$OUTDIR/br/FS/data/anr/" 2>/dev/null && cp "$OUTDIR"/br/FS/data/anr/* "$OUTDIR/" 2>/dev/null
  grep -n -E "ANR in $PKG|VM TRACES AT LAST ANR" "$OUTDIR"/br/bugreport-*.txt 2>/dev/null | head
fi

echo "== Main thread stack from the newest trace (if any) =="
LATEST=$(ls -t "$OUTDIR"/anr_* "$OUTDIR"/traces* 2>/dev/null | head -n1)
if [[ -n "${LATEST:-}" ]]; then
  awk -v pkg="$PKG" '$0 ~ "Cmd line: "pkg {f=1} f && /^"main"/ {m=1} m {print} m && /^$/ {exit}' "$LATEST" | head -n 60
  echo "(full file: $LATEST) — look for: waiting to lock, held by thread, Binder, FileInputStream, SQLite, Object.wait, park"
else
  echo "No trace files found. Reproduce with StrictMode penaltyLog and record a Perfetto trace during the freeze."
fi
