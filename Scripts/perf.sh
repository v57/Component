#!/bin/bash
# Frame times of any v57 Mac app through PerfProbe (Scripts/PerfProbe/PerfProbe.m), a dylib injected at launch: no
# code in the app, no clicks. The build must run without the hardened runtime (Debug, or ENABLE_HARDENED_RUNTIME=NO);
# for frame times build optimized: SWIFT_OPTIMIZATION_LEVEL=-O SWIFT_COMPILATION_MODE=wholemodule (≈ Release).
#
#   Scripts/perf.sh build                          # the dylib and the poster (~/Developer/Builds/tools/perfprobe)
#   Scripts/perf.sh launch <App.app> [args…]       # open -g -n with the probe; prints the pid
#   Scripts/perf.sh <pid> list                     # windows, scroll views (indexes), tables
#   Scripts/perf.sh <pid> walk <sv|main> <pt/tick>             # to the end and back at 120 Hz
#   Scripts/perf.sh <pid> scroll <sv|main> <pt/tick> <ticks>   # steady
#   Scripts/perf.sh <pid> fling <sv|main> <start pt/tick> <n>  # n decaying flings down and up (~3 s each)
#   Scripts/perf.sh <pid> stop                     # ends a running scroll, walk or fling
#   Scripts/perf.sh <pid> insert <text> | delete   # types into the main window's first responder
#   Scripts/perf.sh <pid> idle <seconds>           # CPU and main-thread wakeups
#   Scripts/perf.sh <pid> layout                   # one forced layout + display of each window
#   Scripts/perf.sh <pid> views                    # NSViews by class (SwiftUI hosts one per platform view)
#   Scripts/perf.sh <pid> reset | mark <name> | threshold <ms> | report   # stalls of anything in between
#   Scripts/perf.sh <pid> select <table> <row> | size <w>x<h>
#   Scripts/perf.sh <pid> place off|<x>,<y>       # moves the window; off: past the screens, where the pointer's hover
#                                                  # can't change a run (rows under a resting pointer update as they move)
#   Scripts/perf.sh <pid> pace link|timer          # on screen: step runs on the window's display link
#   Scripts/perf.sh <pid> front                    # activates the app (on-screen runs only: takes the user's focus)
#   Scripts/perf.sh post <notification name> <object>   # an app's own debug hook (dev.v57.code.debug …)
#
# A run's report: iterations of the main run loop while it ran (each one a frame's work: the scroll, SwiftUI's update,
# layout, the commit), p50/p95/p99/max and how many went over 8.3 ms (a 120 Hz frame); and a `display` line: the
# window's display-link callbacks and missed vsyncs, the real frame rate when the window is on screen. Off-screen windows (another
# Space) still lay out, so the numbers hold there; a locked screen or a sleeping display may not.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out=${PERFPROBE_BUILD:-$HOME/Developer/Builds/tools/perfprobe}
dylib=$out/PerfProbe.dylib
poster=$out/perfprobe-post

build() {
  mkdir -p "$out"
  if [[ ! -f $dylib || $here/PerfProbe/PerfProbe.m -nt $dylib ]]; then
    clang -dynamiclib -fobjc-arc -O2 -framework AppKit -framework QuartzCore -o "$dylib" "$here/PerfProbe/PerfProbe.m"
  fi
  if [[ ! -f $poster || $here/PerfProbe/post.m -nt $poster ]]; then
    clang -fobjc-arc -O2 -framework Foundation -o "$poster" "$here/PerfProbe/post.m"
  fi
}

[[ $# -ge 1 ]] || { sed -n 2,20p "$0"; exit 2; }
build
case $1 in
  build) exit 0 ;;
  post) shift; exec "$poster" --name "$@" ;;
  launch)
    app=$2; shift 2
    exe="$app/Contents/MacOS/$(defaults read "$app/Contents/Info.plist" CFBundleExecutable)"
    before=$(pgrep -f "^$exe" | sort || true)
    open -g -n --env DYLD_INSERT_LIBRARIES="$dylib" "$app" --args -ApplePersistenceIgnoreState YES "$@"
    for _ in $(seq 1 100); do
      pid=$(comm -13 <(echo "$before") <(pgrep -f "^$exe" | sort || true) | head -1 || true)
      [[ -n $pid ]] && break
      sleep 0.1
    done
    [[ -n ${pid:-} ]] || { echo "the app didn't start" >&2; exit 1; }
    echo "$pid"
    exit 0 ;;
esac

pid=$1; shift
verb=$1; shift
result=$(mktemp -t perfprobe).txt
rm -f "$result"
case $verb in
  list|report|layout|views) command="$verb:$result" ;;
  walk|idle) command="$verb:$(IFS=:; echo "$*"):$result" ;;
  scroll|fling) command="$verb:$(IFS=:; echo "$*"):$result" ;;
  reset|stop|front) command=$verb ;;
  mark|threshold|size|mode|insert|place|pace) command="$verb:$*" ;;
  delete) command=delete ;;
  select) command="select:$1:$2" ;;
  *) echo "unknown command $verb" >&2; exit 2 ;;
esac
"$poster" "$pid" "$command"
case $verb in reset|stop|mark|threshold|size|select|mode|insert|delete|place|pace|front) exit 0 ;; esac

# A sandboxed app writes to its own temporary folder instead.
fallback() {
  local exe; exe=$(ps -o comm= -p "$pid" 2>/dev/null || true)
  local id; id=$(defaults read "${exe%/Contents/MacOS/*}/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || true)
  [[ -n $id ]] && echo "$HOME/Library/Containers/$id/Data/tmp/$(basename "$result")"
}
alt=$(fallback)
for _ in $(seq 1 ${PERFPROBE_TIMEOUT:-1800}); do
  for f in "$result" ${alt:+"$alt"}; do
    if [[ -f $f ]] && grep -qx DONE "$f"; then grep -vx DONE "$f" || true; rm -f "$f"; exit 0; fi
  done
  kill -0 "$pid" 2>/dev/null || { echo "the app quit" >&2; exit 1; }
  sleep 0.1
done
echo "timed out" >&2; exit 1
