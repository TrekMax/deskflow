#!/usr/bin/env python3
"""Exercise release bootstrap, retries, version routing and incomplete matrices."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.env = {**os.environ, "GITHUB_ENV": str(self.root / "env"),
                    "GITHUB_REF": "refs/heads/master", "GH_REPO": "example/deskflow"}
        self.git("init", "-q")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "commit", "--allow-empty", "-qm", "Initial commit")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True).strip()

    def run_script(self, script, *args, success=True):
        command = ["bash" if script.endswith(".sh") else "python3", str(SCRIPTS / script), *args]
        result = subprocess.run(command, cwd=self.root, env=self.env, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def version(self, ref):
        self.env["GITHUB_REF"] = ref
        Path(self.env["GITHUB_ENV"]).write_text("")
        self.run_script("version.py")
        return dict(line.split("=", 1) for line in Path(self.env["GITHUB_ENV"]).read_text().splitlines())

    def test_versions_without_prior_release(self):
        self.assertEqual(self.version("refs/heads/master")["DESKFLOW_RELEASE_TAG"], "continuous")
        self.assertEqual(self.version("refs/tags/v1.28.0")["DESKFLOW_PRERELEASE"], "false")
        release = self.version("refs/tags/v1.28.0-rc.1")
        self.assertEqual(release["DESKFLOW_PACKAGE_VERSION"], "1.28.0-rc.1")
        self.assertEqual(release["DESKFLOW_PRERELEASE"], "true")
        self.assertEqual(self.version("refs/heads/ci/release")["DESKFLOW_RELEASE_TAG"], "")
        self.env["GITHUB_REF"] = "refs/tags/vbad"
        self.run_script("version.py", success=False)

    def test_lightweight_version_tag(self):
        self.git("tag", "v1.28.0")
        self.assertEqual(self.version("refs/heads/master")["DESKFLOW_VERSION"], "1.28.0.0")

    def assets(self):
        self.env["DESKFLOW_PACKAGE_VERSION"] = "continuous"
        files = {
            "ubuntu-24.04-x86_64": ["ubuntu-noble-x86_64.deb"],
            "ubuntu-24.04-arm64": ["ubuntu-noble-aarch64.deb"],
            "windows-x64": ["win-x64.msi", "win-x64-portable.zip"],
            "windows-arm64": ["win-arm64.msi", "win-arm64-portable.zip"],
            "macos-x86_64": ["macos-x86_64.dmg"],
            "macos-arm64": ["macos-arm64.dmg"],
        }
        for target, names in files.items():
            directory = self.root / "dist" / f"package-{target}"
            directory.mkdir(parents=True)
            for name in names:
                (directory / f"deskflow-continuous-{name}").write_bytes(b"test artifact")

    def test_complete_matrix_checksums(self):
        self.assets()
        self.run_script("prepare-release.py", "dist")
        rows = (self.root / "dist/SHA256SUMS").read_text().splitlines()
        self.assertEqual(len(rows), 8)
        notes = (self.root / "dist/release-notes.md").read_text(encoding="utf-8")
        self.assertIn("构建提交", notes)
        self.assertIn("临时签名", notes)
        for row in rows:
            digest, name = row.split("  ")
            self.assertEqual(digest, hashlib.sha256((self.root / "dist" / name).read_bytes()).hexdigest())

    def test_missing_asset_prevents_partial_release(self):
        self.assets()
        next((self.root / "dist/package-windows-arm64").glob("*.msi")).unlink()
        self.run_script("prepare-release.py", "dist", success=False)
        self.assertFalse((self.root / "dist/SHA256SUMS").exists())
        self.assertEqual(len(list((self.root / "dist/package-windows-x64").iterdir())), 2)

    def mock_gh(self):
        binary = self.root / "gh"
        binary.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['GH_LOG'], 'a') as stream:
    stream.write(json.dumps(args) + '\\n')
if os.environ.get('FAIL_API') and args[0] == 'api':
    sys.exit(23)
if args[:2] == ['api', '--paginate'] and os.environ.get('EXISTING'):
    print('123')
if args[0] == 'api' and 'matching-refs' in args[1] and os.environ.get('EXISTING'):
    print('refs/tags/continuous')
''')
        binary.chmod(0o755)
        self.env.update(PATH=f"{self.root}:{os.environ['PATH']}", GH_LOG=str(self.root / "gh.log"),
                        DESKFLOW_RELEASE_TAG="continuous", DESKFLOW_PACKAGE_VERSION="continuous",
                        DESKFLOW_PRERELEASE="true")
        (self.root / "dist").mkdir()
        (self.root / "dist/deskflow-example.deb").write_bytes(b"artifact")
        (self.root / "dist/SHA256SUMS").write_text("checksum")
        (self.root / "dist/release-notes.md").write_text("notes")

    def calls(self):
        return [json.loads(line) for line in (self.root / "gh.log").read_text().splitlines()]

    def test_first_release_then_retry(self):
        self.mock_gh()
        self.run_script("publish-release.sh", "dist")
        calls = self.calls()
        release_calls = [call for call in calls if call[0] == "release"]
        self.assertEqual([call[1] for call in release_calls], ["create", "upload", "edit"])
        self.assertIn("--draft", release_calls[0])
        self.assertIn("Deskflow 持续构建版", release_calls[0])
        self.assertIn("--latest=false", release_calls[-1])
        self.env["EXISTING"] = "1"
        (self.root / "gh.log").write_text("")
        self.run_script("publish-release.sh", "dist")
        self.assertEqual([call[1] for call in self.calls() if call[0] == "release"], ["upload", "edit"])
        self.assertTrue(any("PATCH" in call for call in self.calls()))

    def test_api_failure_does_not_publish(self):
        self.mock_gh()
        self.env["FAIL_API"] = "1"
        self.run_script("publish-release.sh", "dist", success=False)
        self.assertFalse(any(call[0] == "release" for call in self.calls()))

    def test_stable_tag_not_moved(self):
        self.mock_gh()
        self.git("tag", "v1.28.0")
        self.env.update(DESKFLOW_RELEASE_TAG="v1.28.0", DESKFLOW_PRERELEASE="false")
        self.run_script("publish-release.sh", "dist")
        calls = self.calls()
        self.assertFalse(any("--method" in call for call in calls))
        self.assertIn("--latest", calls[-1])


if __name__ == "__main__":
    unittest.main()
