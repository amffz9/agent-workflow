#!/usr/bin/env bash
# capture_crash.sh — clear logcat, wait for a crash/ANR of <pkg>, save crash + app logs.
# Usage: bash capture_crash.sh <package> [timeout_seconds=120] [outfile=build/agent/crash-<pkg>.txt] [serial]
set -u
PKG="${1:?package name required}"; TIMEOUT="${2:-120}"; OUT="${3:-build/agent/crash-${PKG}.txt}"; SERIAL="${4:-}"
mkdir -p "$(dirname "$OUT")"
ADB=(adb); [[ -n "$SERIAL" ]] && ADB=(adb -s "$SERIAL")

"${ADB[@]}" logcat -c
echo "Logcat cleared. Reproduce the crash/ANR in $PKG now (waiting up to ${TIMEOUT}s)…"
START=$(date +%s)
while :; do
  if "${ADB[@]}" logcat -d -b crash -v threadtime 2>/dev/null | grep -q -E "FATAL EXCEPTION|Fatal signal|ANR in" ; then break; fi
  if "${ADB[@]}" logcat -d -b main -v threadtime 2>/dev/null | grep -q -E "ANR in $PKG|Process $PKG .* has died"; then break; fi
  (( $(date +%s) - START >= TIMEOUT )) && { echo "No crash detected within ${TIMEOUT}s."; exit 2; }
  sleep 1
done

{
  echo "===== CRASH BUFFER ====="
  "${ADB[@]}" logcat -d -b crash -v threadtime
  echo; echo "===== APP LOGS (last 400 lines for $PKG) ====="
  PID=$("${ADB[@]}" shell pidof -s "$PKG" 2>/dev/null | tr -d '\r')
  if [[ -n "$PID" ]]; then "${ADB[@]}" logcat -d -v threadtime --pid="$PID" | tail -n 400
  else "${ADB[@]}" logcat -d -v threadtime | grep -E "$PKG|AndroidRuntime|ActivityManager" | tail -n 400; fi
  echo; echo "===== EXIT INFO ====="
  "${ADB[@]}" shell dumpsys activity exit-info "$PKG" 2>/dev/null | head -n 60
} > "$OUT"
echo "Saved to $OUT"
echo "--- root cause candidates ---"
grep -n -E "FATAL EXCEPTION|Caused by:|Fatal signal|ANR in|MemoryLimiter" "$OUT" | head -n 20
echo "--- first frames in your package ---"
grep -n -E "^\s*at ${PKG%%.*}\." "$OUT" | head -n 10
