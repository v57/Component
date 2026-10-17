#!/bin/bash
# Scroll-hitch test of the catalog: builds Release with the DEBUG launch arguments, runs the app once with
# `--hitch-test`, which opens every page, scrolls every scroll view on it to its end and back, and writes the hitches
# per page; then prints the report.
#
#   Scripts/hitch-test.sh ios <simulator UDID> [page,page,…]
#   Scripts/hitch-test.sh mac [page,page,…]
#
# Environment: HITCH_SPEED (pt/s, 1500), HITCH_SETTLE (s, 1.0), HITCH_TIMEOUT (s, 900),
# HITCH_OUT (where the report is copied, .build-hitch/hitch-<platform>.txt), HITCH_NO_BUILD=1 (reuse the last build),
# HITCH_EXTRA (more launch arguments, e.g. --hitch-direct).
set -euo pipefail
cd "$(dirname "$0")/.."

platform=${1:-}
derived=.build-hitch
bundle=dev.v57.component
timeout=${HITCH_TIMEOUT:-900}

usage() {
  echo "usage: $0 ios <simulator UDID> [pages] | $0 mac [pages]" >&2
  exit 2
}

case $platform in
  ios) udid=${2:-}; pages=${3:-}; [[ -n $udid ]] || usage; destination="id=$udid" ;;
  mac) pages=${2:-}; destination="platform=macOS,arch=$(uname -m)" ;;
  *) usage ;;
esac
out=${HITCH_OUT:-$derived/hitch-$platform.txt}

arguments=()
[[ -n $pages ]] && arguments+=(--hitch-pages "$pages")
[[ -n ${HITCH_EXTRA:-} ]] && arguments+=($HITCH_EXTRA)
[[ -n ${HITCH_SPEED:-} ]] && arguments+=(--hitch-speed "$HITCH_SPEED")
[[ -n ${HITCH_SETTLE:-} ]] && arguments+=(--hitch-settle "$HITCH_SETTLE")

if [[ $platform == ios ]]; then
  xcrun simctl boot "$udid" 2>/dev/null || true
fi

if [[ -z ${HITCH_NO_BUILD:-} ]]; then
  echo "Building Release (DEBUG launch arguments) for $platform…" >&2
  xcodebuild -project Component.xcodeproj -scheme Component -configuration Release -destination "$destination" \
    -derivedDataPath "$derived" SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG build -quiet >&2
fi

# Waits for the report's DONE line, while the app runs (`alive`) and for at most HITCH_TIMEOUT seconds.
wait_for_report() {
  local report=$1 started=$SECONDS
  until [[ -f $report ]] && grep -qx DONE "$report"; do
    if (( SECONDS - started > timeout )); then
      echo "Timed out after ${timeout}s; partial report:" >&2
      return 1
    fi
    if ! alive; then
      echo "The app quit before finishing; partial report:" >&2
      return 1
    fi
    sleep 2
  done
}

status=0
if [[ $platform == ios ]]; then
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
  xcrun simctl install "$udid" "$derived/Build/Products/Release-iphonesimulator/Component.app"
  report="$(xcrun simctl get_app_container "$udid" "$bundle" data)/tmp/hitch-report.txt"
  rm -f "$report"
  alive() { xcrun simctl spawn "$udid" launchctl list 2>/dev/null | grep "$bundle" >/dev/null; }
  xcrun simctl launch "$udid" "$bundle" --hitch-test "$report" ${arguments[@]+"${arguments[@]}"} >/dev/null
  wait_for_report "$report" || status=1
  xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
else
  app="$PWD/$derived/Build/Products/Release/Component.app"
  report="$PWD/$derived/hitch-report-mac.txt"
  rm -f "$report"
  # The window must show (macOS throttles an occluded window's display link): take turns with other captures.
  until mkdir /tmp/v57-screenshot-capture.lock 2>/dev/null; do sleep 10; done
  cleanup() {
    pkill -f "$app/Contents/MacOS/Component" 2>/dev/null || true
    rmdir /tmp/v57-screenshot-capture.lock 2>/dev/null || true
  }
  trap cleanup EXIT
  alive() { pgrep -f "$app/Contents/MacOS/Component" >/dev/null; }
  open -n "$app" --args --hitch-test "$report" ${arguments[@]+"${arguments[@]}"}
  sleep 3
  wait_for_report "$report" || status=1
fi

mkdir -p "$(dirname "$out")"
[[ -f $report ]] && cp "$report" "$out" && cat "$out"
echo "Report: $out" >&2
exit $status
