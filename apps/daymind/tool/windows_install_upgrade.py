"""Real per-user Inno install/upgrade/uninstall checks on a disposable CI runner.

Only RUNNER_TEMP installs are removed. Existing task rows and original asset
bytes must survive an old 0.6.1 install, new upgrade, uninstall and reinstall.
No user content, owner identifiers or support paths are printed.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys


def run(args, cwd=None, timeout=120):
    result = subprocess.run([str(x) for x in args], cwd=cwd, capture_output=True,
                            text=True, errors="replace", timeout=timeout)
    if result.returncode:
        raise RuntimeError("Installer gate command failed; no package accepted")
    return result.stdout


def digest(path):
    with path.open("rb") as data:
        return hashlib.file_digest(data, "sha256").hexdigest()


def snapshot(support):
    db = support / "daymind.sqlite"
    connection = sqlite3.connect(db.as_uri() + "?mode=ro", uri=True, timeout=10)
    try:
        assert connection.execute("PRAGMA quick_check").fetchone()[0] == "ok"
        rows = connection.execute("SELECT * FROM tasks ORDER BY id").fetchall()
        assert rows, "Installer fixture must contain real tasks"
    finally:
        connection.close()
    images = {}
    library = support / "characters"
    for path in library.rglob("*"):
        if path.is_symlink():
            raise ValueError("Unexpected linked installer fixture")
        if path.is_file():
            images[str(path.relative_to(library))] = digest(path)
    assert images, "Installer fixture must contain original artwork"
    return rows, images


def same(before, after):
    assert before[0] == after[0], "Installer changed persistent task rows"
    assert all(after[1].get(name) == value for name, value in before[1].items()), "Installer changed original artwork"


def main():
    assert os.name == "nt", "Windows runner required"
    root = Path(os.environ["RUNNER_TEMP"]).resolve()
    install = root / "daymind-installer-gate"
    assert not install.exists(), "Use a fresh disposable install location"
    baseline = Path(sys.argv[1]).resolve()
    current = Path("build/windows-installer/DayMind-Setup.exe").resolve()
    current_exe = Path("build/windows/x64/runner/Release/daymind_smart.exe").resolve()
    version = re.search(r"^version:\s*(\d+\.\d+\.\d+)", Path("pubspec.yaml").read_text(), re.M).group(1)
    evidence = Path(os.environ["DAYMIND_INSTALL_EVIDENCE_PATH"])
    support = Path(json.loads(evidence.read_text(encoding="utf-8"))["support"]).resolve()
    appdata = Path(os.environ["APPDATA"]).resolve()
    assert support.is_relative_to(appdata) and support != appdata
    assert baseline.is_relative_to(root) and baseline.is_file() and current.is_file()
    before = snapshot(support)
    script = Path("tool/windows_tray_smoke.ps1").resolve()

    def stage(label):
        print('INSTALL_UPGRADE_STAGE: ' + label, flush=True)

    def install_package(package):
        run([package, "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", f"/DIR={install}"], timeout=180)
        assert (install / "daymind_smart.exe").is_file()

    def exercise(expected, old=False):
        # Read the actual installed PE version, not the input installer name.
        command = "$v=(Get-Item -LiteralPath $env:DAYMIND_INSTALL_EXE).VersionInfo.ProductVersion; if($v -notmatch $env:DAYMIND_INSTALL_VERSION_PATTERN){throw 'Installed PE version mismatch'}"
        env = {**os.environ, "DAYMIND_INSTALL_EXE": str(install / "daymind_smart.exe"),
               "DAYMIND_INSTALL_VERSION_PATTERN": "^" + re.escape(expected) + r"($|[.+])"}
        result = subprocess.run(["pwsh", "-NoProfile", "-Command", command],env=env,capture_output=True,timeout=30)
        assert result.returncode == 0, "Installed PE version mismatch"
        args = ["pwsh", "-NoProfile", "-File", script, "-AppDirectory", install]
        if old:
            args.append("-Baseline") # 0.6.1 predates the new single-instance feature.
        run(args, timeout=90)
        same(before, snapshot(support))

    try:
        stage('install baseline 0.6.1')
        install_package(baseline)
        exercise("0.6.1", old=True)
        stage('install current version')
        install_package(current)
        assert digest(install / "daymind_smart.exe") == digest(current_exe), "Upgrade did not install current binary"
        exercise(version)
        stage('uninstall and retain data')
        run([install / "unins000.exe", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"],timeout=120)
        same(before,snapshot(support))
        stage('install current version')
        install_package(current)
        exercise(version)
        print("INSTALL_UPGRADE_POC: " + json.dumps({"baseline":"0.6.1", "current":version,
              "taskRows":len(before[0]), "preservedArtworkFiles":len(before[1]),
              "upgradePreservedData":True, "uninstallPreservedData":True, "reinstallPassed":True}))
    finally:
        uninstaller = install / "unins000.exe"
        if uninstaller.exists():
            run([uninstaller, "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"],timeout=120)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Keep task content, filesystem locations and command details private.
        print("FAIL: Windows installer upgrade gate (" + type(error).__name__ + "); inspect the failed stage before accepting a package.", file=sys.stderr)
        sys.exit(1)
