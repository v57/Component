#!/bin/zsh
# Builds ComponentKit (and the catalog) on v57/SwiftUI's AppKit backend, the way ../SwiftUI/Ports/Component does,
# from a checkout of this repo instead of the port's snapshot.
#
#   Scripts/swiftui-check.sh [-c <Component checkout>] [-k]
#     -c  the checkout to build (default: this script's)
#     -k  ComponentKit only, not the catalog
#
# The package is written to ~/Developer/Builds/size/swiftui-check/<checkout key> (sources linked, not copied) and builds
# into a build-lease.py swiftpm instance of ../SwiftUI/Ports/Component of its own (cached per checkout).
set -u
here=${0:A:h}
component=${here:h}
product=Component
while getopts c:k opt; do
  case $opt in
    c) component=${OPTARG:A} ;;
    k) product=ComponentKit ;;
    *) exit 64 ;;
  esac
done
swiftui=$HOME/Developer/v57/SwiftUI
port=$swiftui/Ports/Component
pkg=$HOME/Developer/Builds/size/swiftui-check/${${component:h}//\//-}
mkdir -p $pkg/src
ln -sfn $component/Sources $pkg/src/Sources
ln -sfn $component/Component $pkg/src/Component
ln -sfn $port/Tests $pkg/Tests
sed "s|path: \"../..\"|path: \"$swiftui\"|" $port/Package.swift > $pkg/Package.swift
[[ -f $port/Package.resolved ]] && cp $port/Package.resolved $pkg/
cache=$HOME/Developer/Builds/size/.swiftpm-${${component:h}//\//-}
if [[ -f $cache && -d $(<$cache) ]]; then scratch=$(<$cache)
else scratch=$(cd $port && ~/.claude/hooks/build-lease.py path swiftpm $port --another) || exit 1; print $scratch > $cache; fi
cd $pkg
target=(--product $product)
[[ $product == ComponentKit ]] && target=(--target ComponentKit)
# QRScan imports ScreenCaptureKit on the Mac, whose SwiftUI cross-import overlay doesn't build against this SwiftUI.
BUILD_LEASE_OFF=1 swift build --scratch-path $scratch $target -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays 2>&1 | tee $pkg/build.log | grep -E 'error:|Compiling|Build complete' | grep -v Compiling
exit ${pipestatus[1]}
