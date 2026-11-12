#!/usr/bin/env python3
"""Compares the app's string catalog with the strings the last build extracted from the sources.

  python3 scripts/string_usage.py            prints one line per problem; nothing when all is well

A key in the catalog that no source line uses is dead weight (and has carried old, untrue sentences in
six languages). A key a source line uses that the catalog lacks is shown in English to everyone. The
build writes what it extracted to .stringsdata files; this reads them from the derived data folder
(PAUSELY_DERIVED, default /tmp/PauselyBuild). Build first: with no build to read, that is the one
line printed.
"""
import glob, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
derived = os.environ.get("PAUSELY_DERIVED", "/tmp/PauselyBuild")
# A Debug build: it compiles file by file (one .stringsdata per source) and includes DEBUG-only screens.
files = glob.glob(os.path.join(derived, "Build/Intermediates.noindex/Pausely.build/Debug-*/Pausely.build/Objects-normal/*/*.stringsdata"))
if not files:
    print(f"no build to read string usage from in {derived}: build the app first")
    sys.exit(0)

# The build leaves the files of sources that have since been deleted or renamed. Only the ones that
# belong to a source file that exists count, and for each the newest.
sources = {os.path.splitext(os.path.basename(path))[0]
           for folder in ("Pausely", "Shared")
           for path in glob.glob(os.path.join(ROOT, folder, "**", "*.swift"), recursive=True)}
newest = {}
for path in files:
    name = os.path.splitext(os.path.basename(path))[0]
    if name in sources and (name not in newest or os.path.getmtime(path) > os.path.getmtime(newest[name])):
        newest[name] = path

used = set()
for path in newest.values():
    for item in json.load(open(path)).get("tables", {}).get("Localizable", []):
        used.add(item["key"])
catalog = set(json.load(open(os.path.join(ROOT, "Pausely/Localizable.xcstrings"), encoding="utf-8"))["strings"])

# "%@" alone is a value passed straight through, not a sentence.
for key in sorted(catalog - used):
    print(f"in the catalog, used by nothing: {key[:120]}")
for key in sorted(used - catalog - {"%@"}):
    print(f"used, and not in the catalog: {key[:120]}")
