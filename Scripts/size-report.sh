#!/bin/zsh
# Release-size report of the apps that use ComponentKit (macOS, arm64).
#
#   Scripts/size-report.sh [-c <Component checkout>] [-o <out dir>] [-n] <App>...
#     Apps: Code Shell Git Player Get Database Hub Markdown Dev (all: every one of them)
#     -c  the ComponentKit checkout the apps build against (default: this script's checkout). Its folder must be
#         named Component: Xcode overrides a package by the folder's name.
#     -o  where archives, logs and size.tsv go (default: ~/Developer/Builds/size/<checkout name>/<time>)
#     -n  plain Release archive, without the release scripts' size settings (LTO + ld-archive-prelink)
#     -s  signed as Xcode signs the app (automatic signing, its entitlements), so it runs with its keychain and
#         app group; by default archives are unsigned
#
#   SIZE_SWIFT_FLAGS="…"  appended to OTHER_SWIFT_FLAGS of every target (packages too)
#   SIZE_LDFLAGS="…"      appended to OTHER_LDFLAGS (the final link: LTO code generation, e.g. -Wl,-mllvm,<llvm option>)
#   SIZE_SETTINGS="A=1 B=2" more build settings on the xcodebuild line
#   SIZE_LINKER=<path>    another ld-archive-prelink (default: Dev's canonical copy)
#   SIZE_SLOTS=<n>        archives that may run at once on this Mac, across sessions (default 2)
#
# Each app archives through a copy of its <App>-Local.xcworkspace with absolute paths (and ../Component swapped
# for -c), into its own DerivedData under ~/Developer/Builds (leased with build-lease.py --another, cached in
# ~/Developer/Builds/size/.dd-<checkout key>-<App>, SourcePackages cloned from instance 1). It prints, per app: the
# arm64 executable, its __TEXT and __DATA* segments, and the bytes of __text whose symbol (in the dSYM) belongs to
# ComponentKit ($s12ComponentKit…; specialisations of the kit's generics made in the app are named after the app).
set -u
here=${0:A:h}
component=${here:h}
out=
plain=0
signed=0
while getopts c:o:ns opt; do
  case $opt in
    c) component=${OPTARG:A} ;;
    o) out=$OPTARG ;;
    n) plain=1 ;;
    s) signed=1 ;;
    *) exit 64 ;;
  esac
done
shift $((OPTIND - 1))
(( $# )) || { sed -n 2,20p $0; exit 64 }
[[ ${component:t} == Component ]] || { print -u2 "the checkout's folder must be named Component: $component"; exit 64 }

v57=$HOME/Developer/v57
typeset -A dirs=(Code $v57/Code Shell $v57/Shell Git $v57/Git Player $v57/Player Get $v57/Get Database $v57/Database
  Markdown $v57/Markdown Dev $v57/Dev Hub $HOME/Developer/Hub/Apps/hub-app)
apps=($@)
[[ $apps == all ]] && apps=(Code Shell Git Player Get Database Hub)

key=${${component:h}//\//-}
out=${out:-$HOME/Developer/Builds/size/${component:h:t}/$(date +%m%d-%H%M%S)}
mkdir -p $out
linker=${SIZE_LINKER:-$v57/Dev/Dev/Release/ld-archive-prelink}
slots=${SIZE_SLOTS:-2}
lockroot=/tmp/v57-size-report.slots
mkdir -p $lockroot

take_slot() {
  while true; do
    for (( s = 1; s <= slots; s++ )); do
      if mkdir $lockroot/$s 2>/dev/null; then print $$ > $lockroot/$s/pid; slot=$s; return; fi
      local p=$(<$lockroot/$s/pid 2>/dev/null)
      [[ -n $p ]] && ! kill -0 $p 2>/dev/null && rm -rf $lockroot/$s
    done
    sleep 5
  done
}
free_slot() { rm -rf $lockroot/$slot }

workspace() {  # app dir, app → a workspace with absolute paths
  local src=$1/$2-Local.xcworkspace/contents.xcworkspacedata ws=$out/ws/$2.xcworkspace
  mkdir -p $ws
  local line rel abs
  while IFS= read -r line; do
    if [[ $line =~ 'location = "group:([^"]*)"' ]]; then
      rel=$match[1]; abs=${${:-$1/$rel}:A}
      [[ ${abs:t} == Component && ${rel} == */* ]] && abs=$component
      line=${line/group:$rel/absolute:$abs}
    fi
    print -r -- $line
  done < $src > $ws/contents.xcworkspacedata
  print $ws
}

derived() {  # app dir, app → this checkout's DerivedData for the app
  local cache=$HOME/Developer/Builds/size/.dd-$key-$2 dd
  [[ -f $cache ]] && dd=$(<$cache) && [[ -d $dd ]] && { print $dd; return }
  dd=$(cd $1 && ~/.claude/hooks/build-lease.py path xcode $1 --another) || return 1
  local first=${dd:h}/1
  [[ ! -d $dd/SourcePackages && -d $first/SourcePackages && $first != $dd ]] && cp -c -R $first/SourcePackages $dd/
  mkdir -p ${cache:h}; print $dd > $cache; print $dd
}

measure() {  # app, archive
  local app=$1 archive=$2
  local exe=$(find $archive/Products -path '*.app/Contents/MacOS/*' -type f -perm +111 | grep -v '/Frameworks/\|/PlugIns/\|/Library/' | head -1)
  local dsym=$(find $archive/dSYMs -path "*${exe:t}.app.dSYM/Contents/Resources/DWARF/*" -type f | head -1)
  [[ -f $exe ]] || { print -P "$app\tFAILED"; return }
  local thin=$out/$app.arm64; lipo -thin arm64 $exe -output $thin 2>/dev/null || cp $exe $thin
  local file=$(stat -f %z $thin)
  local segs=$(size -m $thin | awk '/^Segment __TEXT:/{t=$3} /^Segment __DATA/{d+=$3} END{print t"\t"d}')
  local kit=0
  [[ -f $dsym ]] && kit=$(xcrun nm -n --defined-only -arch arm64 $dsym 2>/dev/null | python3 -c '
import re, sys
rows = [l.split(None, 2) for l in sys.stdin]
rows = [(int(r[0], 16), r[1], r[2].strip().lstrip("_")) for r in rows if len(r) == 3]
total = 0
for (a, t, n), (b, _, _) in zip(rows, rows[1:]):
    m = re.match(r"\$s(\d+)", n)
    if t in "tT" and b > a and m and n[m.end():m.end() + int(m.group(1))] == "ComponentKit": total += b - a
print(total)')
  local app_size=$(du -sk ${exe:h:h:h} | cut -f1)
  print -P "$app\t$file\t$segs\t$kit\t$(( app_size * 1024 ))"
}

[[ -f $out/size.tsv ]] || print "app\texecutable\t__TEXT\t__DATA*\tkit_text\tapp_bundle" > $out/size.tsv
for app in $apps; do
  dir=${dirs[$app]:-}
  [[ -n $dir ]] || { print -u2 "unknown app $app"; continue }
  ws=$(workspace $dir $app)
  dd=$(derived $dir $app) || { print -u2 "no DerivedData for $app"; continue }
  settings=(-configuration Release -destination generic/platform=macOS ARCHS=arm64 COMPILER_INDEX_STORE_ENABLE=NO)
  (( signed )) || settings+=(CODE_SIGNING_ALLOWED=NO)
  flags='$(inherited)'
  (( plain )) || { settings+=(SWIFT_LTO=YES ALTERNATE_LINKER_PATH=$linker)
    flags+=' -Xfrontend -internalize-at-link -Xfrontend -conditional-runtime-records' }
  flags+=" ${SIZE_SWIFT_FLAGS:-}"
  settings+=("OTHER_SWIFT_FLAGS=$flags" ${=SIZE_SETTINGS:-})
  [[ -n ${SIZE_LDFLAGS:-} ]] && settings+=("OTHER_LDFLAGS=\$(inherited) $SIZE_LDFLAGS")
  take_slot
  print -u2 "$(date +%T) $app: archiving (slot $slot, $dd)"
  start=$SECONDS
  rm -rf $out/$app.xcarchive
  BUILD_LEASE_OFF=1 xcodebuild -workspace $ws -scheme $app -derivedDataPath $dd -archivePath $out/$app.xcarchive \
    $settings archive > $out/$app.log 2>&1
  rc=$?
  free_slot
  print -u2 "$(date +%T) $app: exit $rc after $(( SECONDS - start )) s"
  (( rc )) && { grep -E 'error:' $out/$app.log | head -5 >&2; print "$app\tFAILED" >> $out/size.tsv; continue }
  measure $app $out/$app.xcarchive >> $out/size.tsv
done
column -t -s $'\t' $out/size.tsv
print -u2 "report: $out/size.tsv"
