"""Measure actual output bytes; report compressed and unpacked sizes separately."""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import zipfile
from collections import defaultdict

app, package = map(Path, sys.argv[1:])
assert app.is_dir(), app
with (app / "Info.plist").open("rb") as source:
    info = plistlib.load(source)
files = [(p, p.stat().st_size) for p in app.rglob("*") if p.is_file() and not p.is_symlink()]
groups = defaultdict(int)
for path, size in files:
    relative = path.relative_to(app)
    groups[relative.parts[0]] += size
report = {
    "git_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
    "upstream_commit": "b4c0661d5631ebab4d1a2e6f3fd4c805d4030a6c",
    "version": info.get("CFBundleShortVersionString"),
    "bundle_id": info.get("CFBundleIdentifier"),
    "platform": info.get("CFBundleSupportedPlatforms"),
    "unpacked_app_bytes": sum(size for _, size in files),
    "package_bytes": package.stat().st_size,
    "package_sha256": hashlib.file_digest(package.open("rb"), "sha256").hexdigest(),
    "extensions": [p.name for p in sorted((app / "PlugIns").glob("*.appex"))],
    "components": dict(sorted(groups.items(), key=lambda item: -item[1])),
    "largest_files": [{"path": str(p.relative_to(app)), "bytes": size}
                      for p, size in sorted(files, key=lambda item: -item[1])[:40]],
    "notes": [
        "Full upstream app; extensions and bundled native dependencies are retained.",
        "Device IPA is unsigned, locally ZIP-compressed; not an App Store download-size measurement.",
        "Bundle bytes exclude runtime data and extracted Linux rootfs after first launch.",
        "Simulator package sizes must not be used as device distribution sizes.",
    ],
}
with zipfile.ZipFile(package) as archive:
    report["zip_members_uncompressed_bytes"] = sum(i.file_size for i in archive.infolist())
Path("audit/size-report.json").write_text(json.dumps(report, indent=2))
def size_text(value):
    return f"{value:,} bytes / {value / 1_000_000:.2f} MB / {value / 1048576:.2f} MiB"
lines = ["# OpenMinis source build size report", "",
         f"Version: {report['version']}; platform: {report['platform']}", "",
         f"- Package: {size_text(report['package_bytes'])}",
         f"- Unpacked .app: {size_text(report['unpacked_app_bytes'])}",
         f"- Extensions retained: {', '.join(report['extensions'])}", "",
         "| Bundle component | MB (decimal) |", "|---|---:|"]
lines += [f"| {name} | {size / 1_000_000:.2f} |" for name, size in report["components"].items()]
lines += ["", *report["notes"], "", f"SHA-256: `{report['package_sha256']}`"]
Path("audit/size-report.md").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
