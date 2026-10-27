#!/usr/bin/env bash
set -uo pipefail

if [[ "${1:-}" != detach ]]; then
  exec /usr/bin/hdiutil "$@"
fi

# Finder and Spotlight can briefly keep a newly customized DMG busy.
for attempt in 1 2 3 4 5; do
  if /usr/bin/hdiutil "$@"; then
    exit 0
  else
    result=$?
  fi
  echo "Disk image detach attempt $attempt failed ($result)" >&2
  if (( attempt < 5 )); then
    sleep 3
  fi
done
exit "$result"
