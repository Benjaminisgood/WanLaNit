#!/bin/bash
# Each App/*.swift file is compiled on its own. An import in a sibling file
# does not cover it. Fail if a file names a public ThaiLearnCore type and
# does not import ThaiLearnCore itself.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - << 'PY'
import pathlib
import re
import sys

root = pathlib.Path(".").resolve()
core = root / "Sources" / "ThaiLearnCore"
app = root / "App"
decl = re.compile(r"^public (?:struct|enum|class|actor|protocol|typealias|func) ([A-Za-z_][A-Za-z0-9_]*)", re.M)
symbols = set()
for path in core.glob("*.swift"):
    symbols.update(decl.findall(path.read_text(encoding="utf-8")))
if not symbols:
    sys.exit("no public ThaiLearnCore symbols found")

def code_only(source: str) -> str:
    out = []
    i = 0
    n = len(source)
    while i < n:
        if source.startswith("//", i):
            i = source.find("\n", i)
            if i < 0:
                break
            continue
        if source.startswith("/*", i):
            end = source.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        if source.startswith('"""', i):
            end = source.find('"""', i + 3)
            i = n if end < 0 else end + 3
            continue
        if source[i] == '"':
            i += 1
            while i < n:
                if source[i] == "\\":
                    i += 2
                    continue
                if source[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        out.append(source[i])
        i += 1
    return "".join(out)

problems = []
for path in sorted(app.glob("*.swift")):
    source = path.read_text(encoding="utf-8")
    code = code_only(source)
    used = sorted(name for name in symbols if re.search(r"\b" + re.escape(name) + r"\b", code))
    imported = any(re.match(r"import ThaiLearnCore\b", line) for line in source.splitlines())
    if used and not imported:
        problems.append(f"{path.name} uses {', '.join(used)} without import ThaiLearnCore")

if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"checked {len(list(app.glob('*.swift')))} app files against {len(symbols)} core symbols")
PY
