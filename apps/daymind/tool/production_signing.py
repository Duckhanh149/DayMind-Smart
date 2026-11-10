"""Opt-in release signing. Never print credential values or persist them in Git."""
import base64
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys


def required(name):
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"Missing GitHub Actions secret/configuration: {name}")
    return value


def fingerprint(name, length=64):
    value = required(name).replace(":", "").lower()
    if not re.fullmatch(r"[0-9a-f]{%d}" % length, value):
        raise ValueError(f"Invalid public certificate fingerprint configuration: {name}")
    return value


def prepare_android():
    for name in ("DAYMIND_ANDROID_KEY_ALIAS", "DAYMIND_ANDROID_STORE_PASSWORD", "DAYMIND_ANDROID_KEY_PASSWORD"):
        required(name)
    fingerprint("DAYMIND_ANDROID_CERT_SHA256")
    data = base64.b64decode(required("DAYMIND_ANDROID_KEYSTORE_BASE64"), validate=True)
    if not 100 <= len(data) <= 1024 * 1024:
        raise ValueError("Invalid bounded Android signing store")
    path = Path(required("RUNNER_TEMP")) / "daymind-production.keystore"
    # The temporary runner owns this file; it is never uploaded as an artifact.
    with path.open("xb") as out:
        os.chmod(path, 0o600)
        out.write(data)
    with Path(required("GITHUB_ENV")).open("a", encoding="utf-8") as out:
        out.write(f"DAYMIND_ANDROID_KEYSTORE_PATH={path}\n")
    print("Production Android signing store prepared in runner-private temporary storage.")


def verify_android():
    expected = fingerprint("DAYMIND_ANDROID_CERT_SHA256")
    sdk = Path(required("ANDROID_HOME"))
    apk = Path("build/app/outputs/flutter-apk/app-arm64-v8a-release.apk")
    result = subprocess.run([str(sdk / "build-tools/36.0.0/apksigner"), "verify", "--print-certs", str(apk)],
                            capture_output=True, text=True, timeout=30)
    found = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)", result.stdout)
    if result.returncode or not found or any(value.lower() != expected for value in found):
        raise ValueError("APK signature verification/fingerprint mismatch; production artifact rejected")
    print(f"Production APK signature verified; SHA256 {hashlib.sha256(apk.read_bytes()).hexdigest()}")


def cleanup():
    path = Path(required("RUNNER_TEMP")) / "daymind-production.keystore"
    path.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        {"prepare-android": prepare_android, "verify-android": verify_android, "cleanup": cleanup}[sys.argv[1]]()
    except Exception as error:
        # No subprocess output, secret values, or exception repr with input data.
        if isinstance(error, ValueError) and str(error).startswith(("Missing GitHub", "Invalid public", "APK signature")):
            print(str(error), file=sys.stderr)
        else:
            print("Production signing failed; no production artifact approved.", file=sys.stderr)
        sys.exit(1)
