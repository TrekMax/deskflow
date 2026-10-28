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
    f"版本：`{label}`，构建提交：`{sha}`。\n\n"
    "提供 Ubuntu、Windows 和 macOS 的 x86_64 / ARM64 原生构建。\n\n"
    "| 平台 | 架构 | 下载格式 |\n"
    "| --- | --- | --- |\n"
    "| Ubuntu 24.04 | x86_64、ARM64 | `.deb` |\n"
    "| Windows | x64、ARM64 | `.msi` 安装包、`.zip` 便携包 |\n"
    "| macOS 15 及以上 | Intel、Apple Silicon | `.dmg` |\n\n"
    "Ubuntu 安装包已在私有目录中包含所需的 Qt、libei 和 libportal。"
    "下载后可使用 `sudo apt install ./deskflow-*.deb` 安装对应架构的包。\n\n"
    "Windows MSI 安装包需要安装对应架构的最新 "
    "[Microsoft Visual C++ v14 运行库](https://learn.microsoft.com/zh-cn/cpp/windows/latest-supported-vc-redist)。"
    "ZIP 便携包已包含运行库，但不包含系统服务，因此无法在 UAC 提示或登录界面共享输入。\n\n"
    "macOS 已修复临时签名与 Hardened Runtime 冲突导致的 Qt framework 加载崩溃。"
    "如果安装过旧版，请退出应用后用本次下载的 `Deskflow.app` 替换旧应用。\n\n"
    "macOS 安装包使用临时签名（ad-hoc），不启用 Hardened Runtime，尚未经过 Apple 公证，"
    "首次打开时系统可能要求手动确认。Windows 安装包尚未进行 Authenticode 代码签名。\n\n"
    "下载对应平台的安装包及 `SHA256SUMS` 后，可在 Linux 中运行 "
    "`sha256sum --ignore-missing -c SHA256SUMS` 验证已下载文件的完整性。\n",
    encoding="utf-8",
)
print(f"Validated {len(expected)} targets and {len(assets)} release packages")
