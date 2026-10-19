# Pausely - App Store Metadata

This file used to hold hand-written metadata that promised features the app does not have (Smart Pause, AI alternatives, user counts, savings averages) and used the wrong domain. It was removed so it cannot be copied into App Store Connect by mistake.

Use these instead (all generated from `scripts/store_copy.py` + `scripts/store_locales.py`, limit-checked by `python3 scripts/store_copy.py --check`, and validated with `asc metadata validate --dir ./metadata --subscription-app`):

| What | Where |
|---|---|
| English master listing (name, subtitle, keywords, description, what's new, review notes) | `APP_STORE_LISTING.md` |
| Per-language, per-country metadata that `asc metadata push` reads | `metadata/app-info/<locale>.json`, `metadata/version/<version>/<locale>.json` |
| Plain-text copies for proofreading and translators | `AppStoreMetadata/<locale>/*.txt` |
| Seasonal promotional text | `AppStoreScreenshots/PromotionalText.md` |
| Full plan: store UI, screenshots, ASO matrix, Apple account | `APP_STORE_LISTING_PLAN.md` |
| Keyword research and competitor evidence | `ASO_KEYWORD_PLAN.md`, `scripts/aso_scan_*.json` |
