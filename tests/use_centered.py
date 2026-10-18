#!/usr/bin/env python3
"""Replace the redundant aspect preamble with use of the `centered` parameter.

common.glsl's main() already computes

    centered = uv * 2.0 - 1.0;
    centered.x *= resolution.x / resolution.y;

so a shader that re-derives it from `uv` duplicates a divide and a
multiplication, and duplicates the derivation itself.

Only rewrites when the three lines are contiguous, `p` is not assigned before
them, and `aspect` is not referenced anywhere else in the file.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADERS = ROOT / "shaders"

DRY = not (len(sys.argv) > 1 and sys.argv[1] == "--apply")

PATTERN = re.compile(
    r"^(?P<ind>[ \t]*)vec2 (?P<var>\w+) = uv \* 2\.0 - 1\.0;\n"
    r"[ \t]*float aspect = resolution\.x / resolution\.y;\n"
    r"[ \t]*(?P=var)\.x \*= aspect;\n",
    re.M,
)

changed = []
for frag in sorted(SHADERS.rglob("*.frag")):
    text = frag.read_text()
    if "resolution.x / resolution.y" not in text:
        continue
    # `aspect` must not survive as a real symbol anywhere else
    other_aspect = [l for l in text.splitlines()
                    if "aspect" in l and "float aspect =" not in l
                    and not re.match(r"^\s*\w+\.x \*= aspect;\s*$", l)]
    if other_aspect:
        continue
    m = PATTERN.search(text)
    if not m:
        continue
    var = m.group("var")
    # `var` must not be assigned before this block (we would be shadowing)
    prefix = text[:m.start()]
    if re.search(rf"\b{re.escape(var)}\s*=[^=]", prefix.replace(f"vec2 {var} = uv * 2.0 - 1.0;", "")):
        continue
    repl = f"{m.group('ind')}vec2 {var} = centered;\n"
    new = text[:m.start()] + repl + text[m.end():]
    changed.append((frag, var))
    if not DRY:
        frag.write_text(new)

for path, var in changed:
    print(f"{path.relative_to(ROOT)}: p -> centered (var '{var}')")
print(f"\n{'would rewrite' if DRY else 'rewrote'} {len(changed)} files")
if DRY:
    print("(dry run - pass --apply to write)")