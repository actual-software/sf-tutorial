#!/usr/bin/env bash
# Validates every relative link and every heading anchor in sf-tutorial's markdown.
#
# The work happens in check_links.py, which sits next to this file. It walks the
# whole tree rather than an enumerated directory list, and it tests the
# #fragment rather than discarding it. Both of those need CommonMark fence
# tracking and the unicode-aware github-slugger transform, which is why the
# implementation moved to Python; this wrapper keeps the entry point people
# already know.
#
#   scripts/check-links.sh                  check everything
#   scripts/check-links.sh --self-test      prove every directory is traversed
#   scripts/check-links.sh --verify-anchors diff computed anchors against GitHub
#   scripts/check-links.sh --help           the rest

set -eu

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if ! command -v python3 >/dev/null 2>&1; then
  # Exiting non-zero rather than checking a subset is the point. A checker that
  # quietly narrows its own scope when a dependency is missing is the exact
  # failure this rewrite exists to end.
  echo "check-links: python3 not found, so nothing was checked." >&2
  echo "Install Python 3.8 or newer and run this again." >&2
  exit 2
fi

exec python3 "$script_dir/check_links.py" "$@"
