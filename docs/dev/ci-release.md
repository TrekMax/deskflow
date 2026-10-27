# CI builds and releases

`Continuous Integration` builds and tests six native targets on pull requests,
pushes to `master`, version tags and manual dispatches:

| Target | Runner | Qt | Packages |
| --- | --- | --- | --- |
| Ubuntu 24.04 x86_64 | ubuntu-24.04 | 6.8.3 | DEB |
| Ubuntu 24.04 ARM64 | ubuntu-24.04-arm | 6.8.3 | DEB |
| Windows x64 | windows-2022 | 6.12.0 | MSI, portable ZIP |
| Windows ARM64 | windows-11-arm | 6.12.0 | MSI, portable ZIP |
| macOS Intel | macos-15-intel | 6.9.3 | DMG, macOS 12+ |
| macOS ARM64 | macos-15 | 6.12.0 | DMG, macOS 14.4+ |

Qt SDK versions and the Windows vcpkg revision are pinned. Ubuntu's libei 1.3.0
and libportal 0.9.1 sources are verified against SHA256 digests. Runner images,
Homebrew and Ubuntu security updates can still change independently.

## Ubuntu packages

Ubuntu 24.04's Qt, libei and libportal are older than Deskflow's requirements.
`BUNDLE_LINUX_RUNTIME=ON` deploys newer libraries and Qt plugins under
`/usr/lib/deskflow`, with public executable symlinks under `/usr/bin`. Qt's
configuration stays private to Deskflow. System libraries remain package
manager dependencies, calculated by CPack/dpkg-shlibdeps.

The package validation step starts a fresh Ubuntu 24.04 container pinned by
image digest. It installs only the DEB and test tools, checks all bundled ELF
libraries, runs the GUI/core version commands and starts the GUI under Xvfb.
No source checkout, SDK or dependency prefix is mounted in the container.
This checks packaging and X11 startup, not physical keyboard sharing or
Wayland compositor portal permissions.

## Signing

macOS packages use the existing ad-hoc signing fallback and are not notarized.
No Apple certificate or notarization secrets are required. Gatekeeper can
require explicit approval on the receiving Mac. Validation checks the app's
signature and rejects links to Homebrew or runner-local libraries.

Windows packages are not Authenticode-signed. CI validates both portable
executables and MSI installation, execution and uninstallation, without Qt or
vcpkg directories on PATH.

## Release behavior

- Release titles and notes are generated in Chinese, including installation,
  signing and checksum instructions.
- Pull requests and manual runs only upload Actions artifacts.
- A successful push to `master` creates or updates the `continuous` prerelease.
- A tag such as `v1.28.0` publishes a stable release and marks it latest.
- A tag such as `v1.28.0-rc.1` publishes a prerelease without replacing latest.
- All six targets, unit tests and package validations must pass first.
- The publish job requires exactly eight expected packages, computes
  `SHA256SUMS`, and stages a new release as a draft before publishing it.
- Re-running publication updates existing assets without deleting a release.
  Stable version tags are never moved. Only the `continuous` tag is updated.

For example, after merging the desired commit, create an annotated version tag
and push it. Use a new version rather than moving a published version tag.
The tag must match `vMAJOR.MINOR.PATCH` with an optional prerelease suffix.

`Extended Compatibility` retains the other distributions, FreeBSD and Flatpak.
It runs weekly and on manual dispatch, independently of core release gates.
No workflow updates the upstream Deskflow Homebrew tap or documentation site.

## Local verification

```sh
python3 .github/scripts/test-release.py
shellcheck .github/scripts/*.sh
actionlint .github/workflows/continuous-integration.yml .github/workflows/extended-compatibility.yml
```

The release tests use a temporary Git repository and a fake GitHub CLI. They
cover first publication, retries, API failures, stable/prerelease routing and
incomplete artifact matrices without writing to GitHub.
