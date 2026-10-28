#!/bin/zsh
# Code bytes (__text, arm64) per Swift module in an archive's dSYM: Scripts/size-modules.sh <App.xcarchive> [count]
# Symbols are attributed by their mangled module name ($s12ComponentKit… → ComponentKit); "other" is C, ObjC and thunks.
dsym=$(find $1/dSYMs -path '*.app.dSYM/Contents/Resources/DWARF/*' -type f | head -1)
xcrun nm -n --defined-only -arch arm64 $dsym | python3 -c '
import collections, re, sys
rows = [l.split(None, 2) for l in sys.stdin]
rows = [(int(r[0], 16), r[1], r[2].strip().lstrip("_")) for r in rows if len(r) == 3]
c = collections.Counter()
for (a, t, n), (b, _, _) in zip(rows, rows[1:]):
    if t not in "tT" or b <= a: continue
    m = re.match(r"\$s(\d+)", n)
    c[n[m.end():m.end() + int(m.group(1))] if m else "other"] += b - a
for k, v in c.most_common(int(sys.argv[1])): print(f"{v:>10}  {k}")' ${2:-15}
