#!/usr/bin/env python3
"""Reads an Arabic screen tour and prints what an Arabic reader would stumble over.

usage: python3 scripts/tour_untranslated.py <tour dir>

The tour (PauselyUITests/ScreenTourTests with TEST_RUNNER_PAUSELY_TOUR_VARIANT=ar) writes each
screen's accessibility tree beside its capture. This prints, per screen:

  english | a text with no Arabic letter in it that is not a name. Names are read from the app's
            own lists (services, mail providers) or are of a known kind: a currency code, an
            address, a version, a symbol's name, a language written in itself, a file format.
  ltr     | an Arabic sentence whose first letter is Latin with no right-to-left mark before it:
            it is laid out left to right and reads scrambled once it wraps.
  digits  | an Arabic sentence with a Latin digit typed into it (what the code formats arrives
            set apart and is not counted): it sits beside Arabic-Indic digits on the same screen.

Nothing printed means nothing found. Exit status 1 when something is.
"""
import glob
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARABIC = re.compile(r"[ؠ-يٱ-ۓ]")   # letters, not digits or marks

# Written the same in every language.
SAME_EVERYWHERE = {
    "Pausely", "Pausely Pro", "Pro", "CSV", "PDF", "JSON", "iPhone", "iPad", "iOS", "Apple",
    "English", "Deutsch", "Español", "Français",
    # What the system's own keyboard and password bar say on a simulator set to an English keyboard.
    "Passwords", "The", "I", "delete", "Delete", "next", "shift", "numbers", "return", "space",
    "Padding-Left", "Padding-Right", "Next keyboard", "Dictate", "emoji",
}


def names_from_sources():
    """Every service and provider name the app can show: `name: "…"` and `displayName: "…"` literals."""
    names = set()
    for path in glob.glob(os.path.join(ROOT, "Pausely", "**", "*.swift"), recursive=True):
        text = open(path, encoding="utf-8").read()
        names.update(re.findall(r'(?:name|displayName|service): "([^"\\]+)"', text))
        names.update(re.findall(r'(?:priced|asked|pure|mixed)\("([^"\\]+)"', text))
        if os.sep + "Mailbox" + os.sep in path:
            names.update(re.findall(r'case \.\w+: return "([^"\\]+)"', text))
    return names


def is_a_name(text, names):
    if text in SAME_EVERYWHERE or text in names:
        return True
    if re.fullmatch(r"[A-Z]{3}", text):                        # a currency code
        return True
    if re.fullmatch(r"[a-z0-9]+(\.[a-z0-9]+)+", text):          # a symbol's name or a domain
        return True
    if re.fullmatch(r"[a-z]+", text):                           # a symbol's name ("questionmark")
        return True
    if "@" in text or text.startswith("http"):                  # an address
        return True
    if re.fullmatch(r"[A-Z]{0,3}[$€£¥]?[0-9.,:\s%+\-–]*", text):  # a number, a time, a version, a price, a currency sign
        return True
    return False


def first_strong(text):
    depth = 0
    for ch in text:
        if ch in "⁦⁧⁨":
            depth += 1
        elif ch == "⁩":
            depth = max(0, depth - 1)
        elif depth == 0 and unicodedata.bidirectional(ch) in ("L", "R", "AL"):
            return unicodedata.bidirectional(ch)
    return None


def texts(path):
    """(kind, text) for each static text, button and field on the screen, skipping the keyboard."""
    keyboard_indent = None
    for line in open(path, encoding="utf-8", errors="replace"):
        indent = len(line) - len(line.lstrip(" "))
        if keyboard_indent is not None:
            if indent > keyboard_indent:
                continue
            keyboard_indent = None
        kind = line.strip().split(",")[0]
        if kind == "Keyboard":
            keyboard_indent = indent
            continue
        for field in ("label", "value", "placeholderValue"):
            match = re.search(field + r": '?(.*?)'?(?:, (?:identifier|label|value|placeholderValue|title|Selected|Disabled|Keyboard Focused)\b|$)", line)
            if match and match.group(1).strip():
                yield kind, match.group(1).strip()


def main():
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        sys.exit(__doc__)
    names = names_from_sources()
    digit_names = sorted((name for name in names if re.search(r"[0-9]", name)), key=len, reverse=True)   # "Microsoft 365"
    found = {}
    for path in sorted(glob.glob(os.path.join(sys.argv[1], "*.txt"))):
        base = os.path.basename(path)
        if base.startswith("audit"):
            continue
        screen = base.split("-")[0]
        for kind, text in texts(path):
            if not ARABIC.search(text):
                # "Netflix، Spotify…" and "Pausely ٢٠٢٦" are names with something between or after them.
                parts = [re.sub(r"[٠-٩\s]+$", "", part).strip("‎‏ ") for part in re.split(r"[،,…·]", text)]
                if any(re.search(r"[A-Za-z]{2,}", part) and not is_a_name(part, names) for part in parts):
                    found.setdefault(("english", text), set()).add(screen)
                continue
            # A row's spoken label joins its parts ("Netflix، kept، …") and is never drawn as one line.
            spoken = "‏،" in text or ", " in text
            if kind == "StaticText" and not spoken and first_strong(text) == "L":
                found.setdefault(("ltr", text), set()).add(screen)
            outside = re.sub(r"[⁦-⁨][^⁩]*⁩", "", text)   # leave out what the code put in
            outside = re.sub(r"\b\d{4}-\d{4}\b", "", outside)                 # the system's "1964-2022" in a currency's name
            for name in digit_names:
                outside = outside.replace(name, "")
            if re.search(r"(?<![A-Za-z$.0-9])[0-9]+(?![A-Za-z.0-9])", outside):
                found.setdefault(("digits", text), set()).add(screen)
    for (kind, text), screens in sorted(found.items(), key=lambda item: (item[0][0], sorted(item[1]), item[0][1])):
        print(f"{kind:8}| {','.join(sorted(screens)):24} | {text[:140]}")
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
