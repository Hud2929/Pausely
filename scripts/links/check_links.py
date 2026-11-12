#!/usr/bin/env python3
"""Requests every cancellation link the app offers and records what came back.

    python3 scripts/links/check_links.py            # check links not yet recorded
    python3 scripts/links/check_links.py --all      # check every link again
    python3 scripts/links/check_links.py --retry    # check again the ones that gave no clear answer

Reads the links from the Swift sources (the service list and the catalog), asks each one once with a
plain browser-like request that carries nothing about anyone, and writes scripts/links/checked.json:

    "https://www.netflix.com/cancelplan": {"result": "ok", "status": 200, "checked": "2026-11-11"}

result is one of:
    ok       the page answered (2xx, or a redirect that ends in one)
    walled   the site answered that you must sign in or that robots may not look (a sign-in redirect,
             401, 403, 422, 429, a bot challenge): the address exists, which is all a cancel page can
             show a stranger
    gone     the page does not exist (404, 410) or the domain does not resolve
    unclear  no answer in time, or a server error; check again later

`LinkCheckTests` fails when the app offers a link that is not in the file or is recorded as gone.
"""
import concurrent.futures, datetime, json, pathlib, re, socket, ssl, sys, urllib.error, urllib.parse, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
RECORD = pathlib.Path(__file__).with_name("checked.json")
SOURCES = ["Pausely/Services/ServiceDatabase.swift", "Pausely/Services/CatalogData.swift",
           "Pausely/Services/SubscriptionCatalogService.swift"]
AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"


def links():
    found = set()
    for source in SOURCES:
        text = (ROOT / source).read_text(encoding="utf-8")
        found.update(re.findall(r'(?:cancelURL|cancellationURL): "([^"]+)"', text))
    return sorted(found)


def ask(url, hops=5):
    request = urllib.request.Request(url, headers={"User-Agent": AGENT, "Accept": "text/html,*/*;q=0.8",
                                                   "Accept-Language": "en"})
    try:
        with urllib.request.urlopen(request, timeout=15, context=ssl.create_default_context()) as answer:
            return "ok", answer.status
    except urllib.error.HTTPError as error:
        # Permanent redirects this Python does not follow by itself.
        if error.code in (307, 308) and hops > 0 and error.headers.get("Location"):
            return ask(urllib.parse.urljoin(url, error.headers["Location"]), hops - 1)
        if error.code in (404, 410):
            return "gone", error.code
        # Any other refusal short of a server error: the address exists and won't show a stranger
        # (sign-in redirects that loop, 401, 403, 422, 429, a bot challenge).
        if error.code < 500:
            return "walled", error.code
        return "unclear", error.code
    except urllib.error.URLError as error:
        reason = error.reason
        if isinstance(reason, socket.gaierror):
            return "gone", "no such domain"
        return "unclear", str(reason)[:60]
    except (TimeoutError, socket.timeout, ConnectionError, ssl.SSLError, OSError) as error:
        return "unclear", str(error)[:60]


def origin(url):
    parts = urllib.parse.urlsplit(url)
    return f"{parts.scheme}://{parts.netloc}/"


def repair():
    """Rewrites the sources so the app offers no link that is gone.

    A dead page is replaced by its site's front page when that answers (the app then calls it the
    service's website, not its cancellation page). When the whole site is gone, the link is removed:
    a catalog entry loses its link, and a service with no link left is dropped from the service list.
    """
    record = json.loads(RECORD.read_text())
    dead = sorted(url for url in links() if record.get(url, {}).get("result") == "gone")
    homes = sorted({origin(url) for url in dead} - set(record))
    today = datetime.date.today().isoformat()
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
        for url, (result, status) in zip(homes, pool.map(ask, homes)):
            record[url] = {"result": result, "status": status, "checked": today}
    replaced = removed = 0
    for source in SOURCES:
        path = ROOT / source
        text = path.read_text(encoding="utf-8")
        for url in dead:
            home = origin(url)
            alive = record.get(home, {}).get("result") in ("ok", "walled") and home != url
            if alive:
                count = text.count(f'"{url}"')
                text = text.replace(f'cancelURL: "{url}"', f'cancelURL: "{home}"')
                text = text.replace(f'cancellationURL: "{url}"', f'cancellationURL: "{home}"')
                replaced += count
            else:
                # A service entry is two lines: its link is on the first.
                text, dropped = re.subn(r'        \.init\(id: "[^"]+", name: "[^"]+", cancelURL: "' + re.escape(url) + r'",\n[^\n]*\n', "", text)
                text, cleared = re.subn(r'cancellationURL: "' + re.escape(url) + '"', "cancellationURL: nil", text)
                removed += dropped + cleared
        path.write_text(text, encoding="utf-8")
    RECORD.write_text(json.dumps(record, indent=1, sort_keys=True, ensure_ascii=False) + "\n")
    print(f"{len(dead)} dead links: {replaced} uses now point at the site's front page, {removed} removed")


def main():
    if "--repair" in sys.argv:
        repair()
        sys.argv.remove("--repair")
    record = json.loads(RECORD.read_text()) if RECORD.exists() else {}
    wanted = links()
    if "--all" in sys.argv:
        todo = wanted
    elif "--retry" in sys.argv:
        todo = [u for u in wanted if record.get(u, {}).get("result") in (None, "unclear")]
    else:
        todo = [u for u in wanted if u not in record]
    today = datetime.date.today().isoformat()
    print(f"{len(wanted)} links in the app, {len(todo)} to check")
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
        for url, (result, status) in zip(todo, pool.map(ask, todo)):
            record[url] = {"result": result, "status": status, "checked": today}
    record = {url: record[url] for url in wanted if url in record}   # links no longer in the app are dropped
    RECORD.write_text(json.dumps(record, indent=1, sort_keys=True, ensure_ascii=False) + "\n")
    counts = {}
    for entry in record.values():
        counts[entry["result"]] = counts.get(entry["result"], 0) + 1
    print(counts)
    for url, entry in sorted(record.items()):
        if entry["result"] == "gone":
            print("gone:", url, entry["status"])


if __name__ == "__main__":
    main()
