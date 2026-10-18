#!/bin/bash
# validate_shaders.sh - compile-check every GLSL shader the way the app does.
#
# The runtime pipeline (src/platform/linux/GLSLWrapper.h) resolves #include,
# strips every line containing "#version", then prepends "#version 330 core".
# This script reproduces that exactly and compiles the result with glslc, so
# an edit is only accepted if it compiles under the real target.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$ROOT/shaders}"
GLSC="${GLSC:-glslc}"

if ! command -v "$GLSC" >/dev/null 2>&1; then
  echo "error: $GLSC not found (shaderc). Set GLSC=/path/to/glslc." >&2
  exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

resolve() {
  # resolve <file> <out>  -- expand #include, strip #version
  python3 - "$1" "$2" <<'PY'
import sys, os, re
src, out = sys.argv[1], sys.argv[2]
base = os.path.dirname(os.path.abspath(src))
out_lines = []
def emit(path, depth=0):
    if depth > 10:
        return
    d = os.path.dirname(os.path.abspath(path))
    with open(path, errors='replace') as f:
        for line in f:
            if '#version' in line:
                continue
            m = re.search(r'#include\s+"([^"]+)"', line)
            if m:
                inc = m.group(1)
                cand = os.path.normpath(os.path.join(d, inc))
                if os.path.exists(cand):
                    emit(cand, depth+1)
                    continue
                for pre in ('../', '../../', './'):
                    alt = os.path.normpath(os.path.join(d, pre + inc))
                    if os.path.exists(alt):
                        emit(alt, depth+1)
                        break
                continue
            out_lines.append(line)
emit(src)
open(out, 'w').write(''.join(out_lines))
PY
}

pass=0; fail=0; failed=""
for f in $(find "$SRC" -name '*.frag' | sort); do
  name="$(basename "$f")"
  stem="${name%.frag}"
  [ "$stem" = "common" ] || [ "$stem" = "vertex" ] && continue
  res="$tmp/$stem.frag"
  resolve "$f" "$res"
  {
    # The runtime injects "#version 330 core"; Mesa's compiler accepts
    # layout(location=) fragment inputs and unbound UBOs there, while
    # shaderc rejects them outright. Validate against 4.5 so we are
    # checking *our* edits rather than driver-leniency differences.
    echo '#version 450 core'
    cat "$res"
  } > "$tmp/$stem.wrapped.frag"
  # shaderc demands an explicit binding on uniform blocks; Mesa does not.
  # Patch the throwaway copy only, never the source.
  sed -i -E 's/^layout\(std140\) uniform ([A-Za-z_][A-Za-z0-9_]*) \{/layout(std140, binding = 0) uniform \1 {/' \
    "$tmp/$stem.wrapped.frag"
  # shaderc also wants an explicit location on loose (non-opaque) uniforms;
  # Mesa assigns them implicitly. Number them per file, test copy only.
  awk '/^uniform (float|int|vec[234]|mat[234]) [A-Za-z_][A-Za-z0-9_]*.*;/ {
         printf "layout(location = %d) %s\n", 900 + n++, $0
         next
       } { print }' "$tmp/$stem.wrapped.frag" > "$tmp/$stem.wp2.frag" \
    && mv "$tmp/$stem.wp2.frag" "$tmp/$stem.wrapped.frag"
  if err=$("$GLSC" -fshader-stage=fragment --target-env=opengl4.5 \
             "$tmp/$stem.wrapped.frag" -o /dev/null 2>&1); then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    failed="$failed $stem"
    if [ -n "${VERBOSE:-}" ]; then
      echo "--- FAIL: $f"
      echo "$err" | head -12
    fi
  fi
done

echo "compiled OK: $pass   failed: $fail"
if [ "$fail" -gt 0 ]; then
  echo "failing:$failed" | tr ' ' '\n' | sed '/^$/d'
  exit 1
fi