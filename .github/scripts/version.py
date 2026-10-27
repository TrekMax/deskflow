#!/usr/bin/env python3
"""Resolve package/release names without requiring an existing release tag."""
import os
import re
import subprocess


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


sha = git("rev-parse", "HEAD")
ref = os.environ.get("GITHUB_REF", "")
try:
    description = git("describe", "--tags", "--long", "--match", "v[0-9]*")
except subprocess.CalledProcessError:
    description = ""
match = re.fullmatch(r"v(\d+\.\d+\.\d+).*-(\d+)-g[0-9a-f]+", description)
version = f"{match[1]}.{match[2]}" if match else "1.27.0.9999"
if ref.startswith("refs/tags/"):
    tag = ref.removeprefix("refs/tags/")
    if not re.fullmatch(r"v\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?", tag):
        raise SystemExit(f"Unsupported release tag: {tag}")
    label = tag[1:]
    prerelease = "-" in label
elif ref == "refs/heads/master":
    tag, label, prerelease = "continuous", "continuous", True
else:
    tag, label, prerelease = "", f"snapshot-{sha[:8]}", True
values = {
    "DESKFLOW_VERSION": version,
    "DESKFLOW_PACKAGE_VERSION": label,
    "DESKFLOW_RELEASE_TAG": tag,
    "DESKFLOW_PRERELEASE": str(prerelease).lower(),
}
with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
    for key, value in values.items():
        output.write(f"{key}={value}\n")
print(f"Version {version}; package {label}; prerelease {prerelease}")
