#!/usr/bin/env python3
"""Rewrites CurrencyRates.fallback with today's rates for every currency the picker offers.

Source: https://api.exchangerate-api.com/v4/latest/USD (the same API the app uses live).
Run from anywhere in the repository, then run check_money.sh.
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=os.path.dirname(__file__), text=True).strip()
rates_file = os.path.join(root, "Pausely/Core/Money/CurrencyRates.swift")
picker_file = os.path.join(root, "Pausely/Services/SupabaseManager.swift")

with urllib.request.urlopen("https://api.exchangerate-api.com/v4/latest/USD", timeout=20) as response:
    data = json.load(response)
rates, date = data["rates"], data.get("date", "")

codes = []
for code in re.findall(r'Currency\(code: "([A-Z]{3})"', open(picker_file).read()):
    if code not in codes:
        codes.append(code)
missing = [c for c in codes if c not in rates]
if missing:
    sys.exit(f"The API has no rate for {missing}. Remove them from the picker or find a source.")


def text(rate):
    return ("%.6g" % rate) if rate < 100 else ("%.2f" % rate).rstrip("0").rstrip(".")


entries = [f'"{c}": "{text(rates[c])}"' for c in codes]
rows = ["        " + ", ".join(entries[i:i + 6]) + "," for i in range(0, len(entries), 6)]

source = open(rates_file).read()
source = re.sub(r'(private static let fallbackTable: \[String: String\] = \[\n).*?(\n    \])',
                lambda m: m.group(1) + "\n".join(rows) + m.group(2), source, flags=re.S)
source = re.sub(r'static let fallbackDate = "[^"]*"', f'static let fallbackDate = "{date}"', source)
source = re.sub(r'/// Rates on [0-9-]+ \(exchangerate-api\.com\)', f'/// Rates on {date} (exchangerate-api.com)', source)
open(rates_file, "w").write(source)
print(f"Updated {len(codes)} rates to {date} in {os.path.relpath(rates_file, root)}")
