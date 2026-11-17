#!/usr/bin/env python3
"""Does every page of a screen tour reach its end?

    python3 scripts/tour_page_ends.py <tour folder> [<a later folder> ...]

The tour (PauselyUITests/ScreenTourTests) saves the element tree beside each capture. For every
screen and state this reads the tree of its LAST capture and lists what the page still holds below
the bottom of the screen: content no capture of that tour shows. It prints nothing but a count
when every page was followed to its end, and exits 1 when one was not. A state captured again
in a later folder is read from there, so a whole tour and the re-captures after it are one check.

Written 2026-11-17, after the whole tour at the largest text size turned out to stop one swipe
down: 97 of its 160 states ended before their page did, and the scorecard said every state had
been seen whole at that size.

Only the page on top is read: the last scrolling container in the tree that is at least half the
screen tall. What lies under a sheet, and the keys of the keyboard, are not a page's content.

Left out, each for its reason:
  - lists of one kind of row that the tour samples on purpose (`sampledLists` in the tour);
  - states the tour holds still because a swipe would put them away: a dialog, a menu, the
    keyboard over a search (`still: true` in the tour);
  - the few named below.
"""
import collections, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOUR = os.path.join(HERE, "..", "PauselyUITests", "ScreenTourTests.swift")

# Captures that are of something other than a page followed to its end.
OTHER = {
    "splash": "the launch mark, held over the first tab",
    "home-notice": "a notice over Home, which takes the swipe; Home is followed in its own states",
    "firstrun-tally": "one step of the first-launch walk; the grid is followed in firstrun-tally-end",
    "firstrun-account": "one step of the first-launch walk; the form is followed in signup",
    "firstrun-guess": "one step of the first-launch walk",
    "firstrun-reveal": "one step of the first-launch walk; the reveal is followed in reveal-good",
}

def tour_exceptions():
    try:
        source = open(TOUR, encoding="utf-8").read()
    except OSError:
        return {}, set()
    sampled = {}
    block = re.search(r"sampledLists: \[String: Int\] = \[(.*?)\]", source, re.S)
    if block:
        sampled = {name: int(n) for name, n in re.findall(r'"([^"]+)": (\d+)', block.group(1))}
    still = set(re.findall(r'state\("([^"]+)",[^\n]*still: true', source))
    return sampled, still

FRAME = re.compile(r"\{\{(-?[\d.]+), (-?[\d.]+)\}, \{([\d.]+), ([\d.]+)\}\}")
SCROLLS = ("ScrollView", "CollectionView", "Table")
CONTENT = ("StaticText", "Button", "TextField", "SecureTextField", "Switch", "Slider", "Image")

def below_the_screen(path):
    lines = open(path, errors="replace").read().split("\n")
    height = None
    rows = []                                   # (indent, kind, frame, text)
    for line in lines:
        found = FRAME.search(line)
        if not found:
            continue
        x, y, w, h = map(float, found.groups())
        stripped = line.lstrip(" →")
        indent = len(line) - len(stripped)
        kind = stripped.split(",")[0].split(" ")[0]
        if height is None and kind == "Window":
            height = h
        said = re.search(r"label: '(.*)'", line) or re.search(r"identifier: '([^']*)'", line)
        rows.append((indent, kind, (x, y, w, h), said.group(1) if said else kind))
    if not height:
        return []
    # The page on top: the last scrolling container at least half the screen tall.
    top = None
    for index, (indent, kind, frame, _) in enumerate(rows):
        if kind in SCROLLS and frame[3] >= height / 2:
            top = index
    if top is None:
        return []
    under = []
    for indent, kind, (x, y, w, h), text in rows[top + 1:]:
        if indent <= rows[top][0]:
            break
        if kind in CONTENT and w > 0 and h > 0 and y >= height - 1:
            under.append((y, text[:48]))
    return sorted(under)

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    folders = sys.argv[1:]
    sampled, still = tour_exceptions()
    # state -> the captures of it in the last folder that holds it
    states = {}
    for folder in folders:
        here = collections.defaultdict(list)
        for name in sorted(os.listdir(folder)):
            found = re.match(r"[a-z]+-(\d+)-(.+?)(?:-scroll(\d+))?\.txt$", name)
            if found:
                here[found.group(2)].append((int(found.group(3) or 0), int(found.group(1)), os.path.join(folder, name)))
        states.update(here)
    short, left_out = [], collections.Counter()
    for state, captures in sorted(states.items()):
        if state in sampled:
            left_out["sampled lists"] += 1
            continue
        if state in still:
            left_out["held still"] += 1
            continue
        if state in OTHER:
            left_out["not a page followed"] += 1
            continue
        under = below_the_screen(max(captures)[2])
        if under:
            short.append((under[-1][0], state, len(captures), under, os.path.dirname(max(captures)[2])))
    print(f"{' + '.join(folders)}: {len(states)} screens and states; {len(short)} end before their page does"
          f" ({', '.join(f'{n} {what}' for what, n in sorted(left_out.items()))} left out)")
    for _, state, count, under, folder in sorted(short, reverse=True):
        print(f"  {state} ({os.path.basename(folder)}): {count} capture{'s' if count != 1 else ''}; {len(under)} below the last one, "
              f"from \"{under[0][1]}\" to \"{under[-1][1]}\"")
    return 1 if short else 0

if __name__ == "__main__":
    sys.exit(main())
