#!/bin/bash
# Frame times of a v57 app in the iOS Simulator through PerfProbeIOS (Scripts/PerfProbe/PerfProbeIOS.m), a dylib
# injected at launch: no code in the app, no taps, nothing on the Mac's screen. Lease the simulator first
# (~/.claude/hooks/sim-lease.py) and pass its UDID. Build the app optimized for frame times
# (SWIFT_OPTIMIZATION_LEVEL=-O SWIFT_COMPILATION_MODE=wholemodule).
#
#   Scripts/perf-ios.sh launch <udid> <App.app> [args…]   # installs, launches with the probe; prints the pid
#   Scripts/perf-ios.sh <udid> <pid> list                 # windows and scroll views (indexes)
#   Scripts/perf-ios.sh <udid> <pid> scroll <sv|main> <pt/tick> <ticks>   # steady, at 120 Hz
#   Scripts/perf-ios.sh <udid> <pid> walk <sv|main> <pt/tick>             # to the end and back
#   Scripts/perf-ios.sh <udid> <pid> idle <seconds>       # CPU and main-thread wakeups
#
# The simulator runs on the Mac's CPU, so its times are lower than a phone's; compare runs with each other.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out=${PERFPROBE_BUILD:-$HOME/Developer/Builds/tools/perfprobe}
dylib=$out/PerfProbeIOS.dylib
build() {
  mkdir -p "$out" /tmp/perfprobe-ios
  if [[ ! -f $dylib || $here/PerfProbe/PerfProbeIOS.m -nt $dylib ]]; then
    xcrun --sdk iphonesimulator clang -dynamiclib -fobjc-arc -O2 -target arm64-apple-ios17.0-simulator \
      -framework UIKit -framework QuartzCore -o "$dylib" "$here/PerfProbe/PerfProbeIOS.m"
  fi
}
[[ $# -ge 1 ]] || { sed -n 2,14p "$0"; exit 2; }
build
if [[ $1 == launch ]]; then
  udid=$2; app=$3; shift 3
  id=$(defaults read "$app/Info.plist" CFBundleIdentifier)
  xcrun simctl install "$udid" "$app"
  xcrun simctl terminate "$udid" "$id" 2>/dev/null || true
  SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$dylib" xcrun simctl launch "$udid" "$id" "$@" | awk '{ print $NF }'
  exit 0
fi
udid=$1; pid=$2; verb=$3; shift 3
result=/tmp/perfprobe-ios/$pid-$verb-$$.txt
rm -f "$result"
case $verb in
  list) command="list:$result" ;;
  scroll) command="scroll:$1:$2:$3:$result" ;;
  walk) command="walk:$1:$2:$result" ;;
  idle) command="idle:$1:$result" ;;
  *) echo "unknown command $verb" >&2; exit 2 ;;
esac
echo "$command" > /tmp/perfprobe-ios/$pid.cmd
xcrun simctl spawn "$udid" notifyutil -p dev.v57.perfprobe
for _ in $(seq 1 ${PERFPROBE_TIMEOUT:-1800}); do
  if [[ -f $result ]] && grep -qx DONE "$result"; then grep -vx DONE "$result" || true; rm -f "$result"; exit 0; fi
  kill -0 "$pid" 2>/dev/null || { echo "the app quit" >&2; exit 1; }
  sleep 0.1
done
echo "timed out" >&2; exit 1
