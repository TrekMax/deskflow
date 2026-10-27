#!/usr/bin/env bash
set -euo pipefail
package_dir=$(realpath "${1:-build}")
# No build tools, Qt SDK, source tree or host dependency paths are mounted here.
docker run --rm -i -v "$package_dir:/packages:ro" \
  ubuntu:24.04@sha256:24737cef17f4e22b1977df7d9a05e77c4e28b7da5b8911f8d8ccda136bf3573c bash -se <<'CONTAINER'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y /packages/deskflow-*.deb xvfb xauth file
# Test all installed plugins too, including Wayland plugins not used by Xvfb.
while IFS= read -r -d '' binary; do
  if file "$binary" | grep -q ELF; then
    dependencies=$(ldd "$binary")
    if grep -q 'not found' <<< "$dependencies"; then
      echo "$binary: $dependencies" >&2
      exit 1
    fi
  fi
done < <(find /usr/lib/deskflow -type f -print0)
QT_QPA_PLATFORM=offscreen deskflow --version
QT_QPA_PLATFORM=offscreen deskflow-core --version
xvfb-run -a env QT_QPA_PLATFORM=xcb deskflow --version
# Require the event loop to remain alive. An immediate crash is not success.
set +e
xvfb-run -a env QT_QPA_PLATFORM=xcb timeout 5s deskflow
result=$?
set -e
test "$result" -eq 124
CONTAINER
