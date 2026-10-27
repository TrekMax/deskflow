#!/usr/bin/env python3
"""Require the complete platform matrix before preparing a release."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(sys.argv[1])
label = os.environ["DESKFLOW_PACKAGE_VERSION"]
expected = {
    "ubuntu-24.04-x86_64": [f"deskflow-{label}-ubuntu-noble-x86_64.deb"],
    "ubuntu-24.04-arm64": [f"deskflow-{label}-ubuntu-noble-aarch64.deb"],
    "windows-x64": [f"deskflow-{label}-win-x64.msi", f"deskflow-{label}-win-x64-portable.zip"],
    "windows-arm64": [f"deskflow-{label}-win-arm64.msi", f"deskflow-{label}-win-arm64-portable.zip"],
    "macos-x86_64": [f"deskflow-{label}-macos-x86_64.dmg"],
    "macos-arm64": [f"deskflow-{label}-macos-arm64.dmg"],
}
assets = []
# Validate the entire matrix before moving any files.
for target, names in expected.items():
    directory = root / f"package-{target}"
    actual = {p.name for p in directory.iterdir() if p.is_file()} if directory.is_dir() else set()
    if actual != set(names):
        raise SystemExit(f"{target}: expected {names}, got {sorted(actual)}")
    for name in names:
        source = directory / name
        if source.stat().st_size == 0:
            raise SystemExit(f"Empty release asset: {source}")
        assets.append(source)
for source in assets:
    shutil.move(source, root / source.name)
checksums = []
for name in sorted(source.name for source in assets):
    digest = hashlib.sha256()
    with (root / name).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    checksums.append(f"{digest.hexdigest()}  {name}\n")
(root / "SHA256SUMS").write_text("".join(checksums), encoding="utf-8")
sha = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
(root / "release-notes.md").write_text(
    f"Build commit: `{sha}`\n\n"
    "Ubuntu packages target Ubuntu 24.04 and bundle Qt, libei and libportal in a private directory.\n\n"
    "macOS packages use ad-hoc signing and are not notarized. Gatekeeper may require explicit approval.\n\n"
    "Windows packages are not Authenticode-signed.\n\n"
    "Verify downloaded packages with `sha256sum -c SHA256SUMS`.\n",
    encoding="utf-8",
)
print(f"Validated {len(expected)} targets and {len(assets)} release packages")
