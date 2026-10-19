"""Build the original native code for Simulator, without replacing its runtime.

Only SDK selection, deployment flags and framework platform metadata change.
This is applied in the simulator CI workspace only, never the device build.
"""
from pathlib import Path

for name in ("build_lame.sh", "build_ffmpeg.sh", "build_ish.sh"):
    path = Path("deps") / name
    text = path.read_text()
    assert "--sdk iphoneos" in text, name
    text = text.replace("--sdk iphoneos", "--sdk iphonesimulator")
    text = text.replace("-miphoneos-version-min=", "-mios-simulator-version-min=")
    if name == "build_ffmpeg.sh":
        text = text.replace("<string>iPhoneOS</string>", "<string>iPhoneSimulator</string>")
    path.write_text(text)
    print(f"Selected iphonesimulator in {path}")
