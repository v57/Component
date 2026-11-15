#!/usr/bin/env python3
"""swiftui-updates.py <swiftui-updates.xml> [from s] [to s]: SwiftUI updates (xctrace SwiftUI template, swiftui-updates table)
between two times, totalled by view name + description: count and duration."""
import sys, collections, xml.etree.ElementTree as ET
path = sys.argv[1]; t0 = float(sys.argv[2]) * 1e9 if len(sys.argv) > 2 else 0; t1 = float(sys.argv[3]) * 1e9 if len(sys.argv) > 3 else 1e30
vals = {}
def value(e):
    r = e.get('ref')
    if r is not None: return vals.get(r, '')
    v = e.get('fmt') if e.text is None else e.text
    if e.get('id') is not None: vals[e.get('id')] = v
    for c in e:  # register nested ids
        value(c)
    return v if v is not None else ''
cols = ['start','duration','id','update-type','allocations','description','category','view-hierarchy','module','view-name']
agg = collections.defaultdict(lambda: [0, 0.0]); total = 0.0
for ev, e in ET.iterparse(path, events=('end',)):
    if e.tag != 'row': continue
    ch = list(e); row = {}
    for i, c in enumerate(ch[:len(cols)]):
        row[cols[i]] = value(c)
    for c in ch[len(cols):]: value(c)
    e.clear()
    try: start = float(row['start']); dur = float(row['duration'])
    except: continue
    if not (t0 <= start <= t1): continue
    key = (row.get('view-name') or '?')[:70] + ' | ' + (row.get('description') or '')[:70] + ' | ' + (row.get('update-type') or '')
    agg[key][0] += 1; agg[key][1] += dur / 1e6; total += dur / 1e6
print(f"total {total:.0f} ms")
for k, (n, ms) in sorted(agg.items(), key=lambda kv: -kv[1][1])[:40]: print(f"{ms:8.1f} ms {n:7}  {k}")
