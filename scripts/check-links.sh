#!/usr/bin/env bash
# Validates relative links in sf-tutorial markdown files.
#
# For every relative link found in markdown under sf-tutorial/, confirms the
# target path exists on disk. Prints any unresolved links and exits non-zero
# if it finds at least one. Portable to bash 3.2 (macOS default).

set -u

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
tutorial_root=$(cd -- "$script_dir/.." && pwd)

cd "$tutorial_root"

# Match markdown links: [label](target). Capture target only.
# Ignore http(s)/mailto/tel URLs and #fragment-only anchors.
link_re='\[[^]]*\]\(([^)#[:space:]]+)(#[^)]*)?\)'

broken=0
checked=0

# Collect markdown files: every top-level .md plus progression/ and hardening/.
files=$( { find . -maxdepth 1 -type f -name '*.md'
           find ./progression ./hardening -type f -name '*.md' ; } | sort)

while IFS= read -r file; do
  [ -f "$file" ] || continue
  file_dir=$(dirname -- "$file")

  while IFS= read -r line; do
    rest=$line
    while [[ $rest =~ $link_re ]]; do
      target=${BASH_REMATCH[1]}
      # Move past this match to find the next one on the same line.
      rest=${rest#*"${BASH_REMATCH[0]}"}

      case "$target" in
        http://*|https://*|mailto:*|tel:*) continue ;;
        \#*) continue ;;
      esac

      # Strip query string if present.
      target=${target%%\?*}

      if [[ $target == /* ]]; then
        resolved=$target
      else
        resolved="$file_dir/$target"
      fi

      checked=$((checked + 1))

      if [ ! -e "$resolved" ]; then
        printf '%s: broken link -> %s (resolved: %s)\n' "$file" "$target" "$resolved"
        broken=$((broken + 1))
      fi
    done
  done < "$file"
done <<< "$files"

printf '\nlink-check: %d link(s) checked, %d broken.\n' "$checked" "$broken"

if [ "$broken" -gt 0 ]; then
  exit 1
fi
