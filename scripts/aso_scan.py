#!/usr/bin/env python3
"""
App Store keyword scanner (uses Apple's public iTunes Search API; no login or paid tools).

  python3 scripts/aso_scan.py                      # scan the default phrase list, US + CA, save JSON
  python3 scripts/aso_scan.py --track Pausely      # once live: report Pausely's rank for every phrase
  python3 scripts/aso_scan.py --terms "bill reminder,trial tracker" --country ca

Difficulty proxy = median rating count of the top-5 results (higher = harder to outrank), plus how many of the
top-10 are small apps (<1,000 ratings). It does NOT measure search volume: Apple only exposes that in Apple Search
Ads (Advanced) "Search Popularity" and in App Store Connect > Analytics > Search Terms after launch.
"""
import argparse, json, statistics, sys, time, urllib.parse, urllib.request

DEFAULT_TERMS = [
    "subscription tracker", "subscription manager", "track subscriptions", "cancel subscriptions", "recurring payments",
    "recurring bills", "bill reminder", "bill tracker", "free trial reminder", "trial tracker", "subscription reminder",
    "subscription cost", "hidden subscriptions", "forgotten subscriptions", "find subscriptions", "renewal reminder",
    "subscription organizer", "subscription alerts", "price increase alert", "cancel trial", "manage subscriptions",
]
LANG = {"us": "en_us", "ca": "en_ca"}

def search(term, country, limit):
    q = urllib.parse.urlencode({"term": term, "country": country, "entity": "software", "limit": limit, "lang": LANG.get(country, "en_us")})
    for _ in range(3):
        try:
            with urllib.request.urlopen("https://itunes.apple.com/search?" + q, timeout=20) as r:
                return json.load(r).get("results", [])
        except Exception:
            time.sleep(4)
    return []

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--terms", help="comma-separated phrases (default: built-in list)")
    ap.add_argument("--country", default="us", choices=["us", "ca"])
    ap.add_argument("--track", help="app name fragment to rank, e.g. Pausely")
    ap.add_argument("--out", default="aso_scan.json")
    args = ap.parse_args()
    terms = [t.strip() for t in args.terms.split(",")] if args.terms else DEFAULT_TERMS
    limit = 100 if args.track else 10
    results = {}
    for term in terms:
        apps = search(term, args.country, limit)
        results[term] = [{"name": a.get("trackName"), "ratings": a.get("userRatingCount", 0), "id": a.get("trackId")} for a in apps]
        if args.track:
            rank = next((i + 1 for i, a in enumerate(apps) if args.track.lower() in (a.get("trackName") or "").lower()), None)
            print(f"{term:<28} rank: {rank if rank else 'not in top ' + str(limit)}")
        else:
            top5 = [a["ratings"] for a in results[term][:5]]
            small = sum(1 for a in results[term] if a["ratings"] < 1000)
            med = int(statistics.median(top5)) if top5 else 0
            lead = results[term][0]["name"] if results[term] else "-"
            print(f"{term:<28} median(top5 ratings)={med:>7}  small apps in top10={small:>2}  #1={lead[:34]}")
        time.sleep(3.2)  # stay polite: the API allows roughly 20 requests a minute
    json.dump(results, open(args.out, "w"), indent=1)
    print("saved", args.out)

if __name__ == "__main__":
    sys.exit(main())
