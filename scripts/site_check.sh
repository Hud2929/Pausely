#!/bin/bash
# The website exists in three places: the folder pausely.pro/ (where it is edited and tested), the
# local branch gh-pages (what `git push origin gh-pages` publishes) and the local branch site-next
# (the landing page for the next version, with the same policy pages). This prints every page that
# differs between the folder and those branches, one per line; nothing printed means they agree.
#
#   bash scripts/site_check.sh          what differs
#   bash scripts/site_check.sh --sync   commit the folder's pages onto both local branches (never pushes)
#
# Whether the live site matches is a separate question: `git fetch origin && git diff gh-pages origin/gh-pages --stat`.
set -uo pipefail
cd "$(dirname "$0")/.."

POLICIES="privacy.html terms.html refunds.html cookies.html delete.html support.html waitlist.html"
pages_for() { if [ "$1" = gh-pages ]; then echo "index.html $POLICIES"; else echo "$POLICIES"; fi; }

differing() {
  local branch=$1 page
  git rev-parse --verify --quiet "$branch" >/dev/null || { echo "$branch: no such local branch"; return; }
  for page in $(pages_for "$branch"); do
    git show "$branch:$page" 2>/dev/null | cmp -s - "pausely.pro/$page" || echo "$branch:$page differs from pausely.pro/$page"
  done
}

if [ "${1:-}" = "--sync" ]; then
  for branch in gh-pages site-next; do
    [ -z "$(differing "$branch")" ] && continue
    work=$(mktemp -d)
    git worktree add --quiet "$work" "$branch" || exit 1
    for page in $(pages_for "$branch"); do cp "pausely.pro/$page" "$work/$page"; done
    git -C "$work" add -A
    git -C "$work" commit --quiet -m "Pages brought in line with pausely.pro/, where they are edited and held by WebsiteTruthTests"
    git worktree remove --force "$work"
    echo "$branch: committed locally, not pushed"
  done
  exit 0
fi

differing gh-pages
differing site-next
