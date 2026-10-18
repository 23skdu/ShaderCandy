#!/usr/bin/env python3
"""Summarise gcov output for ShaderCandy project sources.

Runs against the .gcov files produced in the current directory (typically by
tests/coverage.sh). Reports line coverage for src/, tests/ and tools/, and
lists the uncovered line numbers so gaps can be closed deliberately.

Usage:
    tests/summarize_coverage.py [directory]
"""

import os
import re
import sys

LINE_RE = re.compile(r"^\s*(#####|-|\d+\*|\*|\d+):\s*(\d+):(.*)$")
SOURCE_RE = re.compile(r"Source:(\S+)")
PROJECT_MARKERS = ("/src/", "/tests/", "/tools/")


def parse(path):
    """Return (executable, covered, uncovered_lines, real_source_path)."""
    executable = covered = 0
    uncovered = []
    source = None
    with open(path, errors="replace") as handle:
        for line in handle:
            match = SOURCE_RE.search(line)
            if match and source is None:
                source = match.group(1)
                continue
            hit = LINE_RE.match(line)
            if not hit:
                continue
            count, lineno = hit.group(1), int(hit.group(2))
            if count == "-":  # non-executable (comment, declaration)
                continue
            executable += 1
            if count == "#####":
                uncovered.append(lineno)
            else:
                covered += 1
    if source is None:
        source = path[: -len(".gcov")] if path.endswith(".gcov") else path
    return executable, covered, uncovered, source


def is_project(source):
    return any(marker in source for marker in PROJECT_MARKERS)


def main():
    directory = sys.argv[1] if len(sys.argv) > 1 else "."
    os.chdir(directory)

    rows = []
    foreign = 0
    for name in sorted(os.listdir(".")):
        if not name.endswith(".gcov"):
            continue
        executable, covered, uncovered, source = parse(name)
        if not is_project(source):
            foreign += 1
            continue
        if executable == 0:
            continue
        rows.append((covered, executable, source, uncovered))

    if not rows:
        print("No project .gcov files found. Run tests/coverage.sh first.")
        return 1

    rows.sort(key=lambda r: r[0] / r[1])

    print("%7s  %7s  %-46s %s" % ("PCT", "COV/EXE", "UNCOVERED", "FILE"))
    print("-" * 96)
    for covered, executable, source, uncovered in rows:
        pct = 100.0 * covered / executable
        flag = "ok " if pct >= 99.9 else "GAP"
        span = ",".join(map(str, uncovered))[:46]
        print("%7s %6.1f%%  %6d/%-6d %-46s %s"
              % (flag, pct, covered, executable, span, source))

    total_cov = sum(r[0] for r in rows)
    total_exe = sum(r[1] for r in rows)
    at_100 = sum(1 for r in rows if r[0] == r[1])
    print("-" * 96)
    print("TOTAL %d/%d = %.2f%%   files=%d   at 100%%=%d"
          % (total_cov, total_exe, 100.0 * total_cov / total_exe, len(rows), at_100))
    print("(ignored %d non-project .gcov files: system headers)" % foreign)
    return 0


if __name__ == "__main__":
    sys.exit(main())