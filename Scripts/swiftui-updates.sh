#!/bin/bash
# SwiftUI updates of a running app while perf.sh drives it: which bodies ran and how often, from the SwiftUI
# instrument. Counts don't depend on the Mac's load the way frame times do, so a fix that stops views from building
# again shows as a number that drops to zero.
#
#   Scripts/swiftui-updates.sh <pid> <scroll view> [pattern]   # records while scrolling 6000 pt down and back
#
# Prints the total and the updates (count, time) grouped by description, filtered by the pattern (a regex, e.g.
# 'ViewBodyAccessor<SidebarRow>'). Move the window out of the pointer's reach first (perf.sh <pid> place off).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
pid=$1; sv=$2; pattern=${3:-.}
work=$(mktemp -d -t swiftui-updates)
trap 'rm -rf "$work"' EXIT
( sleep 4; "$here/perf.sh" "$pid" scroll "$sv" 20 300 >/dev/null; sleep 1; "$here/perf.sh" "$pid" scroll "$sv" -20 300 >/dev/null ) &
xcrun xctrace record --template SwiftUI --attach "$pid" --time-limit 13s --output "$work/run.trace" >/dev/null 2>&1
wait
xcrun xctrace export --input "$work/run.trace" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="swiftui-updates"]' > "$work/updates.xml" 2>/dev/null
python3 "$here/PerfProbe/swiftui-updates.py" "$work/updates.xml" | grep -E "^total|$pattern" | head -${COUNT:-20}
