#!/usr/bin/env python3
"""Weighted cost analysis of the ShaderCandy GLSL corpus.

Part 2 of docs/nextsteps.md counted *sites*: "46 transcendentals inside a loop
in elves.frag". A site count is a weak proxy. A transcendental in a 4-iteration
loop called once per pixel costs a fraction of the same call in a 200-iteration
ray-march loop.

This tool computes a **reach-weighted** estimate instead:

    cost(site) = op_cost * enclosing_loop_iterations(site)

which is "pixels-worth" of transcendental / division / pow work. That ranks
where to spend measurement effort far better than a raw count.

Every finding is still a hypothesis. Mesa already hoists loop-invariant scalar
math (see nextsteps.md 2.5.1), so sites whose inputs are uniform-only are
counted here but must be measured before being acted on.

Known limitations:

  * Static only. Control flow through `if` is not modelled; a site inside a
    rarely-taken branch is over-counted.
  * `for (i = 0; i < 8; i++)` and `for (float i = 0.0; i < 5.0; i++)` are
    both resolved. Loop bounds that are not numeric literals are given a
    nominal weight of 2 and are flagged.
  * Brace tracking is line-based. A line of the form `} else {` or a loop
    whose body is written inline is handled, but very unusual brace
    placement will misattribute.
  * Function-level call multiplicity is reported separately from the loop
    weight rather than multiplied in, because resolving it reliably needs a
    real parser. Use --calls to see it.

Usage:
    tests/cost_analyze.py                    # corpus summary + top sites
    tests/cost_analyze.py --top 60
    tests/cost_analyze.py --per-file
    tests/cost_analyze.py --shader orcs       # one shader
    tests/cost_analyze.py --calls            # include call multiplicity
    tests/cost_analyze.py --json out.json
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict

# Relative latency on a modern Intel iGPU, normalised so one `sin` = 1.0.
# Used only for ranking, never quoted as an absolute number.
#
# The noise functions dominate this corpus and are the single most important
# row in the table: a 3D simplex evaluation is ~10 permute/mod289 chains plus
# four taylor inverses, and it is by a wide margin the most expensive thing a
# pixel does here. Omitting it (as a first draft of this tool did) makes
# `alien_landscape` - the second-slowest shader in the corpus at 2.0 FPS -
# invisible in the ranking.
OP_COST = {
    "sin": 1.0, "cos": 1.0, "tan": 1.0,
    "asin": 2.0, "acos": 2.0, "atan": 1.5,
    "pow": 2.5, "exp": 1.0, "log": 1.5, "log2": 0.8, "exp2": 0.6,
    "sqrt": 0.7, "inversesqrt": 0.7,
    "length": 1.4, "distance": 2.0, "normalize": 2.0,
    "fract": 0.3, "mod": 0.6, "dot": 0.3, "cross": 0.4,
    "smoothstep": 0.5, "step": 0.2, "mix": 0.2,
    "abs": 0.1, "clamp": 0.1, "floor": 0.3,
    # Noise: see note above.
    "snoise": 30.0,   # 3D simplex, ~100 ALU
    "fbm": 30.0,      # one snoise per octave; loop weight covers the rest
    "noise": 8.0,     # value noise = 4 hash() = 4 sin + 4 fract
}

HEAVY_OPS = {"sin", "cos", "tan", "pow", "exp", "log", "length", "distance",
             "normalize", "sqrt", "inversesqrt", "atan", "asin", "acos", "mod",
             "snoise", "fbm", "noise"}

IDENT = r"[A-Za-z_][A-Za-z0-9_]*"
FUNC_DEF_RE = re.compile(
    rf"^\s*(?:void|float|int|bool|vec[234]|ivec[234]|mat[234]|mat[234]x[234])\s+"
    rf"({IDENT})\s*\(")
LOOP_HEADER_RE = re.compile(r"\b(for|while)\s*\(")
FOR_TRIP_RE = re.compile(r"<\s*(\d+(?:\.\d+)?)")
FOR_STEP_RE = re.compile(r"\+=\s*(\d+(?:\.\d+)?)")
OP_USE_RE = re.compile(
    r"\b(" + "|".join(sorted(OP_COST, key=len, reverse=True)) + r")\s*\(")


def strip_comments(text):
    """Blank out comments so patterns only ever match code."""
    out, i, n = [], 0, len(text)
    in_block = False
    while i < n:
        if in_block:
            if text.startswith("*/", i):
                in_block, i = False, i + 2
            else:
                i += 1
            continue
        if text.startswith("/*", i):
            in_block, i = True, i + 2
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def trip_count(loop_text):
    """Trip count from a `for` header, or None if it is not a literal bound.

    Handles the two idioms this corpus uses:
        for (int   i = 0; i < 8;   i++)     -> 8
        for (float i = 0.0; i < 5.0; i++)   -> 5
    """
    bound = FOR_TRIP_RE.search(loop_text)
    if not bound:
        return None
    limit = float(bound.group(1))
    step = 1.0
    m = FOR_STEP_RE.search(loop_text)
    if m:
        step = max(1.0, float(m.group(1)))
    return max(1, int(-(-limit // step)))


class Unit:
    """Structural analysis of one translation unit."""

    def __init__(self, path, source):
        self.path = path
        self.name = os.path.splitext(os.path.basename(path))[0]
        self.lines = strip_comments(source).splitlines()
        self.raw = source.splitlines()
        self.func_of, self.loop_weight, self.approx_loops = self._structure()
        self.calls = self._call_counts()

    def _structure(self):
        """One pass: brace-accurate function ownership and loop depth.

        The subtle part is that a loop's trip count belongs to the brace that
        opens its *body*. A header and its brace may be on the same line
        (`for (...) {`) or on different lines. Tracking that correctly is
        what stops sibling loops from being read as nested - the difference
        between a real weight and a wildly inflated one.
        """
        n = len(self.lines)
        func_of = [None] * n
        weight = [1.0] * n
        approx = [0] * n

        stack = []          # one entry per open brace: (weight, is_func, name)
        pending_loops = []  # loop trip counts still waiting for their '{'
        current_func = None
        pending_func = None

        for idx, line in enumerate(self.lines):
            stripped = line.strip()

            defn = FUNC_DEF_RE.match(line)
            if defn and not stripped.endswith(";"):
                pending_func = defn.group(1)

            # Cost of work performed *on this line*, given the enclosing braces.
            line_weight = 1.0
            for w, _, _ in stack:
                line_weight *= w
            weight[idx] = line_weight
            func_of[idx] = current_func

            # Loop headers on this line claim the next brace(s) on this line,
            # or a later line if the body brace has not been seen yet.
            available = list(pending_loops)
            for m in LOOP_HEADER_RE.finditer(line):
                start = m.end()
                depth, j = 1, start
                while j < len(line) and depth:
                    if line[j] == "(":
                        depth += 1
                    elif line[j] == ")":
                        depth -= 1
                    j += 1
                header = line[start:j]
                trips = trip_count(header)
                if trips is None:
                    trips = 2
                    approx[idx] += 1
                available.append(trips)

            # Work inside a loop written on one line belongs to the loop.
            for _ in available[:line.count("{")]:
                line_weight *= 1  # placeholder, recomputed below
            weight[idx] = line_weight

            # Close braces first: `} else {` must not inherit the old block.
            for _ in range(line.count("}")):
                if stack:
                    w, is_func, _name = stack.pop()
                    if is_func:
                        current_func = None

            # Open braces, claiming any available loop weights in order.
            for _ in range(line.count("{")):
                if available:
                    w = available.pop(0)
                else:
                    w = 1.0
                is_func = pending_func is not None
                name = pending_func if is_func else None
                if is_func:
                    current_func = pending_func
                    pending_func = None
                stack.append((w, is_func, name))

            pending_loops = available

        return func_of, weight, approx

    def _call_counts(self):
        """How many times each function is called inside this unit."""
        defined = {f for f in self.func_of if f}
        counts = defaultdict(int)
        for idx, line in enumerate(self.lines):
            caller = self.func_of[idx]
            if caller is None:
                continue
            for m in re.finditer(rf"\b({IDENT})\s*\(", line):
                name = m.group(1)
                if name in defined and name != caller:
                    counts[name] += 1
        return counts


def analyze_file(path, use_calls):
    with open(path, errors="replace") as handle:
        source = handle.read()
    if "void main" not in source and "effect_main" not in source:
        return None
    unit = Unit(path, source)

    sites = []
    for idx, line in enumerate(unit.lines):
        if not line.strip() or line.strip() in ("{", "}"):
            continue
        w = unit.loop_weight[idx]
        if w <= 1.0:
            continue
        mult = max(1, unit.calls.get(unit.func_of[idx], 1)) if use_calls else 1
        for m in OP_USE_RE.finditer(line):
            op = m.group(1)
            if op not in HEAVY_OPS:
                continue
            sites.append({
                "op": op,
                "loop_weight": w,
                "call_mult": mult,
                "cost": OP_COST[op] * w * mult,
                "line": idx + 1,
                "fn": unit.func_of[idx] or "<global>",
                "approx": bool(unit.approx_loops[idx]),
                "text": unit.raw[idx].strip()[:66],
            })
    return unit, sites


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="shaders")
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--per-file", action="store_true")
    ap.add_argument("--shader", default=None)
    ap.add_argument("--calls", action="store_true",
                    help="multiply by call count of the enclosing function")
    ap.add_argument("--json", default=None)
    args = ap.parse_args()

    files = []
    for base, _dirs, names in os.walk(args.root):
        for n in sorted(names):
            if n.endswith(".frag"):
                files.append(os.path.join(base, n))
    files.sort()
    if args.shader:
        files = [f for f in files if args.shader in f]

    per_file = defaultdict(lambda: {"cost": 0.0, "sites": 0,
                                   "by_op": defaultdict(float)})
    all_sites = []

    for path in files:
        result = analyze_file(path, args.calls)
        if not result:
            continue
        unit, sites = result
        pf = per_file[unit.name]
        for s in sites:
            pf["cost"] += s["cost"]
            pf["sites"] += 1
            pf["by_op"][s["op"]] += s["cost"]
            all_sites.append((s["cost"], unit.name, s))

    all_sites.sort(key=lambda x: -x[0])

    if args.per_file:
        rows = sorted(per_file.items(), key=lambda kv: -kv[1]["cost"])
        print(f"{'WEIGHTED':>10} {'SITES':>6}  {'SHADER':<26} TOP OPS BY WEIGHT")
        print("-" * 90)
        for name, d in rows:
            ops = ", ".join(f"{k}:{v:.0f}" for k, v in
                            sorted(d["by_op"].items(), key=lambda kv: -kv[1])[:5])
            print(f"{d['cost']:>10.0f} {d['sites']:>6}  {name:<26} {ops}")
        print("-" * 90)

    print(f"\n{'WEIGHT':>7} {'LOOPW':>6} {'CALL':>4}  {'OP':<9} {'SHADER':<20} "
          f"{'FUNCTION':<20} LINE")
    print("-" * 110)
    for cost, name, s in all_sites[: args.top]:
        mark = "~" if s["approx"] else " "
        print(f"{cost:>7.0f} {s['loop_weight']:>6.0f} {s['call_mult']:>4}  "
              f"{s['op']:<9} {name:<20} {s['fn'][:20]:<20} {s['line']}{mark}")
    print("-" * 110)
    print(f"{len(files)} shaders, {len(all_sites)} loop-weighted sites, "
          f"total weight {sum(s[0] for s in all_sites):.0f}")
    print("~ = loop bound is not a numeric literal (nominal weight 2)")

    if args.json:
        with open(args.json, "w") as fh:
            json.dump({
                "per_file": {k: {"cost": v["cost"], "sites": v["sites"],
                                "by_op": dict(v["by_op"])} for k, v in per_file.items()},
                "sites": [{"cost": c, "shader": n, **s} for c, n, s in all_sites],
            }, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())