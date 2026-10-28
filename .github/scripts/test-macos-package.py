#!/usr/bin/env python3
"""Validate ad-hoc macOS packages after copying them off the disk image."""
import os
from pathlib import Path
import re
import subprocess
import tempfile


MACHO_MAGICS = {
    bytes.fromhex(value) for value in (
        "feedface", "cefaedfe", "feedfacf", "cffaedfe",
        "cafebabe", "bebafeca", "cafebabf", "bfbafeca",
    )
}


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, timeout=120, **kwargs)


def check_signatures(app):
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(app))
    for relative in (
        "Contents/MacOS/Deskflow", "Contents/MacOS/deskflow-core",
        "Contents/Frameworks/QtWidgets.framework/Versions/A/QtWidgets",
        "Contents/PlugIns/platforms/libqcocoa.dylib",
    ):
        if not (app / relative).is_file():
            raise ValueError(f"Required packaged binary missing: {relative}")
    binaries = []
    for binary in sorted(app.rglob("*")):
        if binary.is_symlink() or not binary.is_file():
            continue
        with binary.open("rb") as stream:
            if stream.read(4) not in MACHO_MAGICS:
                continue
        architectures = run("/usr/bin/lipo", "-archs", str(binary), capture_output=True).stdout.split()
        for architecture in architectures:
            result = run(
                "/usr/bin/codesign", "--display", "--verbose=4", "--arch", architecture,
                str(binary), capture_output=True,
            )
            metadata = result.stdout + result.stderr
            flags = re.search(r"\bflags=0x([0-9a-fA-F]+)", metadata)
            if not flags or "Signature=adhoc" not in metadata or "TeamIdentifier=not set" not in metadata:
                raise ValueError(f"Expected ad-hoc signature: {binary} ({architecture})\n{metadata}")
            # Both implicit (runtime) and explicit library validation require a Team ID.
            if int(flags[1], 16) & (0x10000 | 0x2000):
                raise ValueError(f"Ad-hoc binary enables Hardened Runtime/library validation: {binary}")
        binaries.append(binary)
    print(f"Verified ad-hoc signing policy for {len(binaries)} Mach-O files", flush=True)
    return binaries


def main():
    packages = list(Path("build").glob("deskflow-*.dmg"))
    if len(packages) != 1:
        raise ValueError(f"Expected one DMG, got {packages}")
    with tempfile.TemporaryDirectory(prefix="deskflow-package-", dir=os.environ.get("RUNNER_TEMP")) as directory:
        root = Path(directory)
        mount = root / "mount"
        app = root / "Deskflow.app"
        run("/usr/bin/hdiutil", "attach", str(packages[0]), "-nobrowse", "-mountpoint", str(mount), input="Y\n")
        try:
            run("/usr/bin/ditto", str(mount / "Deskflow.app"), str(app))
        finally:
            run("/bin/bash", ".github/scripts/hdiutil-retry.sh", "detach", str(mount))

        binaries = check_signatures(app)
        for binary in binaries:
            links = run("/usr/bin/otool", "-L", str(binary), capture_output=True).stdout
            if re.search(r"^\s+(/opt/homebrew|/usr/local/opt|/Users/runner)", links, re.MULTILINE):
                raise ValueError(f"Build-machine library dependency: {binary}\n{links}")

        env = {key: value for key, value in os.environ.items() if not key.startswith(("DYLD_", "QT_", "QML"))}
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        for name in ("deskflow-core", "Deskflow"):
            run(str(app / "Contents/MacOS" / name), "--version", env=env)

        # Finder launches through LaunchServices. Require application output as open's
        # exit status alone does not prove that dyld successfully started the app.
        stdout, stderr = root / "launch.stdout", root / "launch.stderr"
        run(
            "/usr/bin/open", "-n", "-W", "--stdout", str(stdout), "--stderr", str(stderr),
            str(app), "--args", "--version", env=env,
        )
        output = stdout.read_text() if stdout.exists() else ""
        if "Deskflow:" not in output:
            error = stderr.read_text() if stderr.exists() else ""
            raise ValueError(f"LaunchServices did not start the installed app:\n{output}\n{error}")
        print(output, flush=True)

        # Reproduce the old signing policy on a disposable copy. Its cryptographic
        # signature is valid, but our policy check must reject the runtime flag.
        broken = root / "invalid-runtime.app"
        run("/usr/bin/ditto", str(app), str(broken))
        run("/usr/bin/codesign", "--force", "--sign", "-", "--options", "runtime", str(broken))
        try:
            check_signatures(broken)
        except ValueError as error:
            if "Hardened Runtime/library validation" not in str(error):
                raise
            print(f"Signing regression detected as expected: {error}", flush=True)
        else:
            raise ValueError("Signing policy check accepted the original crash configuration")


if __name__ == "__main__":
    main()
