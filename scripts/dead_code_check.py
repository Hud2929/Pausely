#!/usr/bin/env python3
"""Lists Swift declarations in the app and widget that nothing else in the app or widget refers to.

A name counts as used only when it appears somewhere other than its own declaration, in app or widget
code. Tests don't count: code that only tests call is dead (CLAUDE.md). It is a word-level check, so it
can miss dead code that shares a name with live code, and it never deletes anything; it lists.

    python3 scripts/dead_code_check.py            # prints the candidates, exits 1 if there are any
    python3 scripts/dead_code_check.py --count    # prints only the number

Names that are reached in ways a word search can't see (the system calls them, or they are part of a
protocol) go in scripts/dead_code_allow.txt, one per line, with a reason after '#'.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = ["Pausely", "PauselyWidget"]
ALLOW_FILE = os.path.join(ROOT, "scripts", "dead_code_allow.txt")

# Names the language, SwiftUI or the system call for us.
BUILTIN = {
    "body", "init", "deinit", "main", "id", "hash", "description", "debugDescription", "errorDescription", "encode",
    "makeUIViewController", "updateUIViewController", "makeUIView", "updateUIView", "makeCoordinator", "previews",
    "placeholder", "snapshot", "getSnapshot", "getTimeline", "timeline", "perform", "title", "openAppWhenRun",
    "appShortcuts", "typeDisplayRepresentation", "displayRepresentation", "defaultQuery", "suggestedEntities", "entities",
    "application", "userNotificationCenter", "scene", "sceneDidBecomeActive", "rawValue", "allCases", "CodingKeys",
    "recoverySuggestion", "failureReason", "callAsFunction", "subscript", "path", "makeBody", "resolve", "value",
    "authorizationController", "presentationAnchor", "paymentQueue", "contentAttributes", "contentState", "caseDisplayRepresentations",
}

DECL = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|private|fileprivate|internal|open|static|final|override|mutating|nonisolated|lazy|indirect|class|convenience)\s+)*"
    r"(struct|class|enum|protocol|actor|typealias|func|var|let|case)\s+`?([A-Za-z_][A-Za-z0-9_]*)")


def swift_files():
    for source in SOURCES:
        for directory, _, files in os.walk(os.path.join(ROOT, source)):
            for name in files:
                if name.endswith(".swift"):
                    yield os.path.join(directory, name)


def strip_comments_and_strings(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    # Interpolations keep their code; the rest of a string literal is not a reference.
    def literal(match):
        inner = match.group(0)
        return " " + " ".join(re.findall(r"\\\(([^()]*(?:\([^()]*\)[^()]*)*)\)", inner)) + " "
    return re.sub(r'"(?:[^"\\\n]|\\.)*"', literal, text)


def main():
    allow = set()
    if os.path.exists(ALLOW_FILE):
        for line in open(ALLOW_FILE, encoding="utf-8"):
            name = line.split("#", 1)[0].strip()
            if name:
                allow.add(name)

    texts = {}
    for path in swift_files():
        texts[path] = strip_comments_and_strings(open(path, encoding="utf-8").read())
    words = {}
    for path, text in texts.items():
        for word in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text):
            words[word] = words.get(word, 0) + 1

    candidates = []
    for path, text in sorted(texts.items()):
        override_next = False
        for number, line in enumerate(text.split("\n"), 1):
            match = DECL.match(line)
            if not match:
                continue
            kind, name = match.group(1), match.group(2)
            if "override " in line or name in BUILTIN or name in allow or name.startswith("_"):
                continue
            if kind in ("var", "let") and not re.match(r"^\s{0,4}(?:@\w+\s+)*(?:(?:public|private|fileprivate|internal|static|final|lazy|nonisolated)\s+)*(?:var|let)\s", line):
                continue  # locals inside functions are the compiler's job
            if kind == "case" and ("(" not in line and "," in line or line.strip().endswith(":")):
                continue  # switch cases, and multi-case lines (checked by name below would be noisy)
            if kind == "case" and not re.match(r"^\s{4}case\s+[a-z]", line):
                continue
            if words.get(name, 0) <= 1:
                candidates.append((os.path.relpath(path, ROOT), number, kind, name))

    if "--count" in sys.argv:
        print(len(candidates))
    else:
        for path, number, kind, name in candidates:
            print("%s:%d  %s %s" % (path, number, kind, name))
        print("%d declarations nothing refers to" % len(candidates))
    return 1 if candidates else 0


if __name__ == "__main__":
    sys.exit(main())
