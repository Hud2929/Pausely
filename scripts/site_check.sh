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
  local branch=$1 ref="" page
  if git rev-parse --verify --quiet "$branch" >/dev/null; then
    ref="$branch"
  elif git rev-parse --verify --quiet "origin/$branch" >/dev/null; then
    ref="origin/$branch"
  elif [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    return
  else
    echo "$branch: no such local branch"
    return
  fi
  for page in $(pages_for "$branch"); do
    git show "$ref:$page" 2>/dev/null | cmp -s - "pausely.pro/$page" || echo "$branch:$page differs from pausely.pro/$page"
  done
}

if [ "${1:-}" = "--sync" ]; then
  for branch in gh-pages site-next; do
    work=$(mktemp -d)
    git worktree add --quiet "$work" "$branch" || exit 1
    if [ "$branch" = site-next ]; then
      # site-next carries everything the publish branch has (so it can be published by a plain push)
      # and keeps its own landing page.
      git -C "$work" merge --quiet --no-commit --no-ff gh-pages >/dev/null 2>&1 || true
      git -C "$work" checkout --quiet HEAD -- index.html
    fi
    for page in $(pages_for "$branch"); do cp "pausely.pro/$page" "$work/$page"; done
    git -C "$work" add -A
    if git -C "$work" rev-parse --verify --quiet MERGE_HEAD >/dev/null || ! git -C "$work" diff --cached --quiet; then
      git -C "$work" commit --quiet -m "Pages brought in line with pausely.pro/, where they are edited and held by WebsiteTruthTests"
      echo "$branch: committed locally, not pushed"
    fi
    git worktree remove --force "$work"
  done
  exit 0
fi

differing gh-pages
differing site-next
