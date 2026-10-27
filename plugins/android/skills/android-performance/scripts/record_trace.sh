#!/usr/bin/env bash
# record_trace.sh — record a Perfetto system trace for an app and pull it to the host.
# Usage: bash record_trace.sh <package> [seconds=10] [output=build/agent/trace-<pkg>-<ts>.pftrace] [serial]
# Then open the file at https://ui.perfetto.dev or Android Studio Profiler → "Load from file".
set -euo pipefail
PKG="${1:?package name required}"
SECS="${2:-10}"
OUT="${3:-build/agent/trace-${PKG}-$(date +%Y%m%d-%H%M%S).pftrace}"
mkdir -p "$(dirname "$OUT")"
SERIAL="${4:-}"
ADB=(adb); [[ -n "$SERIAL" ]] && ADB=(adb -s "$SERIAL")

API=$("${ADB[@]}" shell getprop ro.build.version.sdk | tr -d '\r')
if (( API < 29 )); then echo "Perfetto needs API 29+ (device is $API). Use: adb shell atrace / systrace." >&2; exit 1; fi
# Perfetto is enabled by default on API 29+; on 28 you'd need persist.traced.enable=1

REMOTE="/data/misc/perfetto-traces/trace-$$.pftrace"
echo "Recording ${SECS}s trace for $PKG → $OUT"
echo "Reproduce the scenario on the device now…"
"${ADB[@]}" shell perfetto -o "$REMOTE" -t "${SECS}s" \
  sched freq idle am wm gfx view binder_driver hal dalvik input res memory \
  --app "$PKG" >/dev/null
"${ADB[@]}" pull "$REMOTE" "$OUT" >/dev/null
"${ADB[@]}" shell rm -f "$REMOTE"
SIZE=$(du -h "$OUT" | cut -f1)
echo "Saved $OUT ($SIZE)."
echo "Next: open in https://ui.perfetto.dev (drag & drop). Inspect main thread of $PKG, Choreographer#doFrame, Compose:* slices, GC, binder."
