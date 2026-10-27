#!/usr/bin/env bash
set -euo pipefail
# Meson and its Python modules come from apt, while the Qt action adds a
# separate Python to PATH. Keep dependency generation on Ubuntu's interpreter.
export PATH="/usr/bin:/bin:$PATH"

root=$(pwd)
prefix="$root/deps/prefix"
mkdir -p deps/downloads deps/src
fetch() {
  local url=$1 file=$2 checksum=$3
  if [[ ! -f "$file" ]]; then
    curl --fail --location --retry 3 --connect-timeout 30 --max-time 300 "$url" -o "$file"
  fi
  echo "$checksum  $file" | sha256sum --check
}
fetch https://gitlab.freedesktop.org/libinput/libei/-/archive/1.3.0/libei-1.3.0.tar.gz \
  deps/downloads/libei-1.3.0.tar.gz 162dc7b0d86a4575cdde1d3cb04f364f89a8b1ba6d95fe0b442564e0444d851d
fetch https://github.com/flatpak/libportal/releases/download/0.9.1/libportal-0.9.1.tar.xz \
  deps/downloads/libportal-0.9.1.tar.xz de801ee349ed3c255a9af3c01b1a401fab5b3fc1c35eb2fd7dfb35d4b8194d7f

tar -xf deps/downloads/libei-1.3.0.tar.gz -C deps/src
tar -xf deps/downloads/libportal-0.9.1.tar.xz -C deps/src
meson setup deps/build-libei deps/src/libei-1.3.0 --wipe \
  --prefix="$prefix" --libdir=lib --buildtype=release -Dtests=disabled -Dliboeffis=disabled
meson compile -C deps/build-libei
meson install -C deps/build-libei
meson setup deps/build-libportal deps/src/libportal-0.9.1 --wipe \
  --prefix="$prefix" --libdir=lib --buildtype=release \
  -Dbackend-gtk3=disabled -Dbackend-gtk4=disabled -Dbackend-qt5=disabled -Dbackend-qt6=disabled \
  -Dintrospection=false -Dvapi=false -Ddocs=false -Dtests=false
meson compile -C deps/build-libportal
meson install -C deps/build-libportal
mkdir -p "$prefix/share/licenses/deskflow-dependencies"
cp deps/src/libei-1.3.0/COPYING "$prefix/share/licenses/deskflow-dependencies/libei.txt"
cp deps/src/libportal-0.9.1/COPYING "$prefix/share/licenses/deskflow-dependencies/libportal.txt"
