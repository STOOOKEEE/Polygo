#!/usr/bin/env python3
"""Run reward regressions against the existing macOS Debug application build."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import tempfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def captured(command, destination, timeout=60):
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    destination.write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f"Command exited {result.returncode}; evidence: {destination}")
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--derived-data", type=Path, required=True)
    parser.add_argument("--entry", type=Path, required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--output-parent", type=Path, required=True)
    args = parser.parse_args()
    if platform.system() != "Darwin":
        raise RuntimeError("Apple runtime required; this is not a portable package test")
    args.output_parent.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="polygo-model-reward-", dir=args.output_parent))
    print(f"EVIDENCE_DIRECTORY={output}", flush=True)
    products = args.derived_data / "Build/Products/Debug"
    app = products / "PolygoMacApp.app"
    dylib = app / "Contents/MacOS/PolygoMacApp.debug.dylib"
    objects = args.derived_data / "Build/Intermediates.noindex/Polygo.build/Debug/PolygoMacApp.build/Objects-normal" / platform.machine()
    module = objects / "PolygoMacApp.swiftmodule"
    package_frameworks = products / "PackageFrameworks"
    content = app / "Contents/Resources/Content"
    apple = products / "PolygoApple.framework/PolygoApple"
    for path in [args.entry, dylib, module, apple]:
        if not path.is_file():
            raise RuntimeError(f"Missing actual build input: {path}; no substituted model permitted")
    if not content.is_dir():
        raise RuntimeError(f"Missing actual bundled content: {content}")
    frameworks = sorted(package_frameworks.glob("*.framework"))
    libraries = [item / item.stem for item in frameworks]
    for path in libraries:
        if not path.is_file():
            raise RuntimeError(f"Missing actual package framework binary: {path}")

    sdk = captured(["xcrun", "--sdk", "macosx", "--show-sdk-path"], output / "sdk-path.txt")
    metadata = {
        "sha": args.sha,
        "architecture": platform.machine(),
        "os": captured(["sw_vers"], output / "os.txt"),
        "xcode": captured(["xcodebuild", "-version"], output / "xcode.txt"),
        "swift": captured(["xcrun", "swiftc", "--version"], output / "swift.txt"),
        "sdk": captured(["xcrun", "--sdk", "macosx", "--show-sdk-version"], output / "sdk-version.txt"),
        "entry_sha256": digest(args.entry),
        "app_dylib_sha256": digest(dylib),
        "app_model_source_sha256": digest(args.repo / "App/AppModel.swift"),
        "dependency_source_sha256": digest(args.repo / "App/Dependencies.swift"),
        "inputs": [str(path) for path in [module, dylib, apple, *libraries]],
        "status": "prepared-for-execution",
    }
    metadata_path = output / "provenance.json"
    metadata_path.write_text(json.dumps(metadata, indent=2))
    binary = output / "PolygoRewardProbe"
    command = [
        "xcrun", "swiftc", "-parse-as-library", "-swift-version", "5", "-Onone",
        "-module-name", "PolygoRewardProbe", "-sdk", sdk,
        "-target", platform.machine() + "-apple-macos14.0",
        "-I", str(objects), "-I", str(products),
        "-F", str(products), "-F", str(package_frameworks),
        str(args.entry), str(dylib), "-framework", "PolygoApple",
        *[str(path) for path in libraries], "-o", str(binary),
    ]
    for directory in [dylib.parent, products, package_frameworks, app / "Contents/Frameworks"]:
        command.extend(["-Xlinker", "-rpath", "-Xlinker", str(directory)])
    (output / "compile-command.json").write_text(json.dumps(command, indent=2))
    captured(command, output / "compile.log", timeout=180)
    # The probe never opens the GUI or substitutes an AppModel implementation.
    # It directly calls the already-built production types through their public DI.
    captured([str(binary), str(content), str(output / "journals")], output / "probe.log", timeout=120)
    metadata["status"] = "passed"
    metadata_path.write_text(json.dumps(metadata, indent=2))
    print((output / "probe.log").read_text(), end="")
    print(f"PROVENANCE={metadata_path}")


if __name__ == "__main__":
    main()
