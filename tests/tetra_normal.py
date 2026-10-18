#!/usr/bin/env python3
"""Rewrite 6-tap central-difference normals to the 4-tap tetrahedral form.

The 6-tap form evaluates the distance field six times per normal; the
tetrahedral form uses four samples on the vertices of a tetrahedron and
recovers the same gradient, for a 33% reduction in the most expensive
per-hit-pixel work of a ray-marcher.

Only rewrites when the body matches the canonical shape exactly, so a
hand-tuned normal is left alone. Dry-run by default.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADERS = ROOT / "shaders"

DRY = not (len(sys.argv) > 1 and sys.argv[1] == "--apply")

# fn(p + e.xyy, ARGS) - fn(p - e.xyy, ARGS),  ... 3 axis pairs
BODY = re.compile(
    r"(?P<ind>[ \t]*)vec2 e = vec2\((?P<eps>[0-9.]+), 0\.0\);\n"
    r"[ \t]*return normalize\(vec3\(\n"
    r"[ \t]*(?P<fn>\w+)\(p \+ e\.xyy, (?P<a>[^)]*)\) - (?P=fn)\(p - e\.xyy, (?P=a)\),\n"
    r"[ \t]*(?P=fn)\(p \+ e\.yxy, (?P=a)\) - (?P=fn)\(p - e\.yxy, (?P=a)\),\n"
    r"[ \t]*(?P=fn)\(p \+ e\.yyx, (?P=a)\) - (?P=fn)\(p - e\.yyx, (?P=a)\)\n"
    r"[ \t]*\)\);"
)

changed = []
for frag in sorted(SHADERS.rglob("*.frag")):
    text = frag.read_text()
    m = BODY.search(text)
    if not m:
        continue
    fn, args, eps, ind = m.group("fn"), m.group("a"), m.group("eps"), m.group("ind")
    repl = (
        f"{ind}vec2 e = vec2({eps}, 0.0);\n"
        f"{ind}// 4-tap tetrahedral normal: 4 field evaluations instead of the\n"
        f"{ind}// 6 that central differencing needs.\n"
        f"{ind}const vec2 k = vec2(1.0, -1.0);\n"
        f"{ind}return normalize(\n"
        f"{ind}    k.xyy * {fn}(p + k.xyy * e.x, {args}) +\n"
        f"{ind}    k.yyx * {fn}(p + k.yyx * e.x, {args}) +\n"
        f"{ind}    k.yxy * {fn}(p + k.yxy * e.x, {args}) +\n"
        f"{ind}    k.xxx * {fn}(p + k.xxx * e.x, {args}));"
    )
    if not DRY:
        frag.write_text(text[:m.start()] + repl + text[m.end():])
    changed.append((frag, fn))

for path, fn in changed:
    print(f"{path.relative_to(ROOT)}: {fn} -> 4-tap tetrahedral")
print(f"\n{'would rewrite' if DRY else 'rewrote'} {len(changed)} files")
if DRY:
    print("(dry run - pass --apply to write)")