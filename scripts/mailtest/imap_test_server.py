#!/usr/bin/env python3
"""A small read-only IMAP4rev1 server for Pausely's end-to-end mail tests.

It serves folders of .eml files so the app's real IMAP stack (connect, sign in, list, EXAMINE,
UID SEARCH, UID FETCH with BODY.PEEK) can be driven on a simulator without a real mailbox.
Plain TCP on localhost only: the app allows that in DEBUG builds for 127.0.0.1.

    python3 scripts/mailtest/imap_test_server.py --port 1143 \
        --account tester@pausely.test:app-pass-1234:/path/to/mailbox

A mailbox is a directory whose sub-directories are folders (INBOX, Archive, Trash, Junk ...).
.eml files directly inside the directory are the INBOX. New files are picked up on the next EXAMINE,
with new UIDs, so "only mail since the last scan" can be tested.

An account may carry behaviours after a fourth colon, comma separated:
    slow=0.3        wait this many seconds before answering each command
    drop=5          close the connection on the 5th UID FETCH (a network drop mid-scan)
    apppw           any wrong password is refused the way Gmail refuses a regular password
    nosearch8       refuse CHARSET UTF-8 searches (some servers can't)
    bye             refuse at the greeting
Server-wide: --no-literal-plus makes the client wait for "+" before each literal.

Never put real mail in the repository; point --account at a folder outside it.
"""
import argparse
import asyncio
import datetime
import email
import email.header
import email.utils
import os
import re
import sys

FOLDER_FLAGS = {
    "trash": "\\Trash", "deleted messages": "\\Trash", "bin": "\\Trash",
    "junk": "\\Junk", "spam": "\\Junk", "bulk mail": "\\Junk",
    "sent": "\\Sent", "sent messages": "\\Sent", "drafts": "\\Drafts",
    "archive": "\\Archive", "all mail": "\\All",
}


class Message:
    def __init__(self, path, uid):
        with open(path, "rb") as handle:
            raw = handle.read()
        # IMAP carries CRLF line endings.
        raw = raw.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
        self.raw = raw
        self.uid = uid
        self.path = path
        split = raw.find(b"\r\n\r\n")
        self.header_bytes = raw if split < 0 else raw[: split + 2]
        parsed = email.message_from_bytes(self.header_bytes)
        self.sender = decode_header(parsed.get("From", ""))
        self.subject = decode_header(parsed.get("Subject", ""))
        self.date = parse_date(parsed.get("Date")) or datetime.datetime.fromtimestamp(
            os.path.getmtime(path), datetime.timezone.utc)

    def header_fields(self, names):
        wanted = {name.lower() for name in names}
        out = []
        keep = False
        for line in self.header_bytes.split(b"\r\n"):
            if not line:
                continue
            if line[:1] in (b" ", b"\t"):
                if keep:
                    out.append(line)
                continue
            name = line.split(b":", 1)[0].decode("ascii", "replace").strip().lower()
            keep = name in wanted
            if keep:
                out.append(line)
        return b"\r\n".join(out) + b"\r\n\r\n"


def decode_header(value):
    try:
        parts = email.header.decode_header(value)
        return "".join(p.decode(c or "utf-8", "replace") if isinstance(p, bytes) else p for p, c in parts)
    except Exception:
        return value or ""


def parse_date(value):
    if not value:
        return None
    try:
        date = email.utils.parsedate_to_datetime(value)
        if date.tzinfo is None:
            date = date.replace(tzinfo=datetime.timezone.utc)
        return date.astimezone(datetime.timezone.utc)
    except Exception:
        return None


class Folder:
    def __init__(self, name, directory):
        self.name = name
        self.directory = directory
        self.uid_by_file = {}
        self.next_uid = 1
        self.messages = []
        self.refresh()

    def refresh(self):
        if not os.path.isdir(self.directory):
            return
        for filename in sorted(os.listdir(self.directory)):
            if not filename.endswith(".eml") or filename in self.uid_by_file:
                continue
            uid = self.next_uid
            self.next_uid += 1
            self.uid_by_file[filename] = uid
            self.messages.append(Message(os.path.join(self.directory, filename), uid))

    @property
    def flags(self):
        special = FOLDER_FLAGS.get(self.name.lower())
        return "\\HasNoChildren" + (" " + special if special else "")


class Mailbox:
    def __init__(self, root):
        self.root = root
        self.folders = {}
        self.load()

    def load(self):
        names = []
        if os.path.isdir(self.root):
            names = [d for d in sorted(os.listdir(self.root)) if os.path.isdir(os.path.join(self.root, d))]
        if not any(n.upper() == "INBOX" for n in names):
            self.folders.setdefault("INBOX", Folder("INBOX", self.root))
        for name in names:
            key = "INBOX" if name.upper() == "INBOX" else name
            if key not in self.folders:
                self.folders[key] = Folder(key, os.path.join(self.root, name))

    def folder(self, name):
        if name.upper() == "INBOX":
            name = "INBOX"
        return self.folders.get(name)


class Account:
    def __init__(self, spec):
        parts = spec.split(":", 3)
        if len(parts) < 3:
            raise SystemExit("--account needs user:password:maildir[:behaviours]")
        self.user, self.password, root = parts[0], parts[1], parts[2]
        self.mailbox = Mailbox(root)
        self.behaviours = {}
        if len(parts) == 4:
            for item in parts[3].split(","):
                key, _, value = item.partition("=")
                self.behaviours[key.strip()] = value.strip() or "1"


# ---------------------------------------------------------------- command parsing

def tokenize(parts):
    """parts: list of str (command text) and bytes (literals) -> [(kind, value)]"""
    tokens = []
    for part in parts:
        if isinstance(part, bytes):
            tokens.append(("str", part.decode("utf-8", "replace")))
            continue
        i = 0
        while i < len(part):
            ch = part[i]
            if ch == " ":
                i += 1
            elif ch == "(":
                tokens.append(("lp", "("))
                i += 1
            elif ch == ")":
                tokens.append(("rp", ")"))
                i += 1
            elif ch == '"':
                i += 1
                value = []
                while i < len(part) and part[i] != '"':
                    if part[i] == "\\" and i + 1 < len(part):
                        i += 1
                    value.append(part[i])
                    i += 1
                i += 1
                tokens.append(("str", "".join(value)))
            else:
                start = i
                while i < len(part) and part[i] not in ' ()"':
                    i += 1
                tokens.append(("atom", part[start:i]))
    return tokens


def parse_key(tokens, i):
    kind, value = tokens[i]
    if kind == "lp":
        keys = []
        i += 1
        while tokens[i][0] != "rp":
            key, i = parse_key(tokens, i)
            keys.append(key)
        return ("AND", keys), i + 1
    word = value.upper()
    if word == "OR":
        left, i = parse_key(tokens, i + 1)
        right, i = parse_key(tokens, i)
        return ("OR", left, right), i
    if word == "NOT":
        inner, i = parse_key(tokens, i + 1)
        return ("NOT", inner), i
    if word in ("SINCE", "BEFORE", "FROM", "SUBJECT", "BODY", "TEXT", "UID"):
        return (word, tokens[i + 1][1]), i + 2
    if word == "ALL":
        return ("ALL",), i + 1
    raise ValueError("unsupported search key " + value)


def parse_search(tokens):
    keys = []
    i = 0
    while i < len(tokens):
        key, i = parse_key(tokens, i)
        keys.append(key)
    return ("AND", keys)


def uid_in_set(uid, spec, highest):
    for part in spec.split(","):
        if ":" in part:
            low, high = part.split(":", 1)
            low = highest if low == "*" else int(low)
            high = highest if high == "*" else int(high)
            if low > high:
                low, high = high, low
            # "n:*" always matches the newest message, as RFC 3501 says.
            if low <= uid <= high or (uid == highest and (low >= highest or high >= highest) and "*" in part):
                return True
        elif part == "*":
            if uid == highest:
                return True
        elif part and uid == int(part):
            return True
    return False


def matches(message, key, highest):
    kind = key[0]
    if kind == "AND":
        return all(matches(message, k, highest) for k in key[1])
    if kind == "OR":
        return matches(message, key[1], highest) or matches(message, key[2], highest)
    if kind == "NOT":
        return not matches(message, key[1], highest)
    if kind == "ALL":
        return True
    if kind == "SINCE":
        day = datetime.datetime.strptime(key[1], "%d-%b-%Y").date()
        return message.date.date() >= day
    if kind == "BEFORE":
        day = datetime.datetime.strptime(key[1], "%d-%b-%Y").date()
        return message.date.date() < day
    if kind == "FROM":
        return key[1].lower() in message.sender.lower()
    if kind == "SUBJECT":
        return key[1].lower() in message.subject.lower()
    if kind in ("BODY", "TEXT"):
        return key[1].lower().encode("utf-8") in message.raw.lower()
    if kind == "UID":
        return uid_in_set(message.uid, key[1], highest)
    return False


# ---------------------------------------------------------------- session

class Session:
    def __init__(self, server, reader, writer):
        self.server = server
        self.reader = reader
        self.writer = writer
        self.account = None
        self.folder = None
        self.fetches = 0

    def send(self, data):
        if isinstance(data, str):
            data = data.encode("utf-8")
        self.writer.write(data)

    async def read_command(self):
        parts = []
        while True:
            line = await self.reader.readline()
            if not line:
                return None
            text = line.decode("utf-8", "replace").rstrip("\r\n")
            literal = re.search(r"\{(\d+)(\+?)\}$", text)
            if not literal:
                parts.append(text)
                return parts
            parts.append(text[: literal.start()])
            size = int(literal.group(1))
            if not literal.group(2):
                self.send("+ Ready for literal data\r\n")
                await self.writer.drain()
            parts.append(await self.reader.readexactly(size))

    async def run(self):
        capabilities = "IMAP4rev1 SASL-IR AUTH=PLAIN" + ("" if self.server.no_literal_plus else " LITERAL+")
        if self.server.greeting_bye:
            self.send("* BYE Service temporarily unavailable\r\n")
            await self.writer.drain()
            return
        self.send("* OK [CAPABILITY %s] Pausely test server ready\r\n" % capabilities)
        await self.writer.drain()
        while True:
            parts = await self.read_command()
            if parts is None:
                return
            first = parts[0] if isinstance(parts[0], str) else ""
            head = first.split(" ", 2)
            if len(head) < 2:
                self.send("* BAD missing command\r\n")
                await self.writer.drain()
                continue
            tag, command = head[0], head[1].upper()
            rest = [head[2] if len(head) > 2 else ""] + parts[1:]
            if self.account and "slow" in self.account.behaviours:
                await asyncio.sleep(float(self.account.behaviours["slow"]))
            elif self.server.slow:
                await asyncio.sleep(self.server.slow)
            try:
                keep_going = await self.dispatch(tag, command, rest, capabilities)
            except (ValueError, IndexError) as error:
                self.send("%s BAD %s\r\n" % (tag, error))
                keep_going = True
            await self.writer.drain()
            if not keep_going:
                return

    async def dispatch(self, tag, command, rest, capabilities):
        if command == "CAPABILITY":
            self.send("* CAPABILITY %s\r\n%s OK CAPABILITY completed\r\n" % (capabilities, tag))
        elif command == "NOOP":
            self.send("%s OK NOOP completed\r\n" % tag)
        elif command == "LOGOUT":
            self.send("* BYE Logging out\r\n%s OK LOGOUT completed\r\n" % tag)
            return False
        elif command == "LOGIN":
            tokens = tokenize(rest)
            self.login(tag, tokens[0][1], tokens[1][1])
        elif command == "AUTHENTICATE":
            import base64
            tokens = tokenize(rest)
            if len(tokens) < 2 or tokens[0][1].upper() != "PLAIN":
                self.send("%s NO unsupported mechanism\r\n" % tag)
            else:
                fields = base64.b64decode(tokens[1][1]).split(b"\x00")
                self.login(tag, fields[1].decode(), fields[2].decode())
        elif self.account is None:
            self.send("%s NO Please sign in first\r\n" % tag)
        elif command == "LIST":
            for folder in self.account.mailbox.folders.values():
                self.send('* LIST (%s) "/" "%s"\r\n' % (folder.flags, folder.name))
            self.send("%s OK LIST completed\r\n" % tag)
        elif command in ("EXAMINE", "SELECT"):
            name = tokenize(rest)[0][1]
            folder = self.account.mailbox.folder(name)
            if folder is None:
                self.send("%s NO [NONEXISTENT] No such folder\r\n" % tag)
                return True
            folder.refresh()
            self.folder = folder
            self.send("* %d EXISTS\r\n* 0 RECENT\r\n" % len(folder.messages))
            self.send("* OK [UIDVALIDITY %d] UIDs valid\r\n" % self.server.uid_validity)
            self.send("* OK [UIDNEXT %d] Predicted next UID\r\n" % folder.next_uid)
            self.send("* FLAGS (\\Seen)\r\n")
            self.send("%s OK [READ-ONLY] %s completed\r\n" % (tag, command))
        elif command == "UID":
            await self.uid_command(tag, rest)
        else:
            self.send("%s BAD Unknown command %s\r\n" % (tag, command))
        return True

    def login(self, tag, user, password):
        account = self.server.accounts.get(user.lower())
        if account is None or account.password != password:
            if account is not None and "apppw" in account.behaviours:
                self.send("%s NO [ALERT] Application-specific password required: "
                          "https://support.google.com/accounts/answer/185833 (Failure)\r\n" % tag)
            else:
                self.send("%s NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)\r\n" % tag)
            return
        self.account = account
        self.send("%s OK %s authenticated (Success)\r\n" % (tag, user))

    async def uid_command(self, tag, rest):
        text = rest[0]
        verb, _, arguments = text.partition(" ")
        verb = verb.upper()
        if self.folder is None:
            self.send("%s NO No folder selected\r\n" % tag)
            return
        messages = self.folder.messages
        highest = messages[-1].uid if messages else 0
        if verb == "SEARCH":
            tokens = tokenize([arguments] + rest[1:])
            if len(tokens) >= 2 and tokens[0][1].upper() == "CHARSET":
                if "nosearch8" in self.account.behaviours:
                    self.send("%s NO [BADCHARSET (US-ASCII)] Charset not supported\r\n" % tag)
                    return
                tokens = tokens[2:]
            query = parse_search(tokens)
            found = [str(m.uid) for m in messages if matches(m, query, highest)]
            self.send("* SEARCH%s\r\n%s OK SEARCH completed\r\n" % ("".join(" " + u for u in found), tag))
        elif verb == "FETCH":
            self.fetches += 1
            drop = self.account.behaviours.get("drop")
            if drop and self.fetches >= int(drop):
                self.writer.close()
                raise ConnectionResetError("dropped on purpose")
            spec, _, attributes = arguments.partition(" ")
            for index, message in enumerate(messages):
                if not uid_in_set(message.uid, spec, highest):
                    continue
                self.send(b"* %d FETCH (" % (index + 1) + self.fetch_items(message, attributes) + b")\r\n")
            self.send("%s OK FETCH completed\r\n" % tag)
        else:
            self.send("%s BAD Unknown UID command\r\n" % tag)

    def fetch_items(self, message, attributes):
        items = [b"UID %d" % message.uid]
        upper = attributes.upper()
        if "INTERNALDATE" in upper:
            items.append(b'INTERNALDATE "' + message.date.strftime("%d-%b-%Y %H:%M:%S +0000").encode() + b'"')
        fields = re.search(r"BODY(?:\.PEEK)?\[HEADER\.FIELDS \(([^)]*)\)\]", attributes, re.I)
        if fields:
            names = fields.group(1).split()
            data = message.header_fields(names)
            items.append(b"BODY[HEADER.FIELDS (" + " ".join(names).encode() + b")] {%d}\r\n" % len(data) + data)
        whole = re.search(r"BODY(?:\.PEEK)?\[\](?:<(\d+)\.(\d+)>)?", attributes, re.I)
        if whole:
            data = message.raw
            if whole.group(1) is not None:
                start, length = int(whole.group(1)), int(whole.group(2))
                data = data[start:start + length]
                items.append(b"BODY[]<%d> {%d}\r\n" % (start, len(data)) + data)
            else:
                items.append(b"BODY[] {%d}\r\n" % len(data) + data)
        return b" ".join(items)


class Server:
    def __init__(self, arguments):
        self.accounts = {}
        for spec in arguments.account:
            account = Account(spec)
            self.accounts[account.user.lower()] = account
        self.no_literal_plus = arguments.no_literal_plus
        self.uid_validity = arguments.uid_validity
        self.slow = arguments.slow
        self.greeting_bye = arguments.bye

    async def handle(self, reader, writer):
        session = Session(self, reader, writer)
        try:
            await session.run()
        except (ConnectionResetError, asyncio.IncompleteReadError, BrokenPipeError):
            pass
        finally:
            try:
                writer.close()
            except Exception:
                pass


async def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=1143)
    parser.add_argument("--account", action="append", required=True, help="user:password:maildir[:behaviours]")
    parser.add_argument("--no-literal-plus", action="store_true")
    parser.add_argument("--uid-validity", type=int, default=20261111)
    parser.add_argument("--slow", type=float, default=0, help="seconds to wait before every command")
    parser.add_argument("--bye", action="store_true", help="refuse every connection at the greeting")
    arguments = parser.parse_args()
    server = Server(arguments)
    listener = await asyncio.start_server(server.handle, "127.0.0.1", arguments.port)
    counts = ", ".join("%s (%d messages)" % (a.user, sum(len(f.messages) for f in a.mailbox.folders.values()))
                       for a in server.accounts.values())
    print("IMAP test server on 127.0.0.1:%d: %s" % (arguments.port, counts), flush=True)
    async with listener:
        await listener.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
