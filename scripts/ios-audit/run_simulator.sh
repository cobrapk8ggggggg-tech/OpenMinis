#!/usr/bin/env bash
set -euo pipefail
xcrun simctl list devices available -j > audit/simulator-devices.json
SIMULATOR_ID=$(python3 - <<'PY'
import json
data = json.load(open('audit/simulator-devices.json'))
for runtime, devices in sorted(data['devices'].items(), reverse=True):
    if 'iOS' not in runtime:
        continue
    phones = [d for d in devices if d.get('isAvailable') and 'iPhone' in d['name']]
    if phones:
        print(phones[0]['udid'])
        break
else:
    raise SystemExit('No available iPhone simulator runtime')
PY
)
xcrun simctl boot "$SIMULATOR_ID" || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b
APP_PATH="$PWD/audit/DerivedData/Build/Products/Release-iphonesimulator/Minis.app"
codesign --force --deep --sign - "$APP_PATH"
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" com.openminis.app | tee audit/simulator-launch.txt
sleep 20
xcrun simctl spawn "$SIMULATOR_ID" launchctl list > audit/simulator-processes.txt
grep 'com.openminis.app' audit/simulator-processes.txt
xcrun simctl io "$SIMULATOR_ID" screenshot audit/simulator-launch.png
xcrun simctl spawn "$SIMULATOR_ID" log show --last 2m --style compact \
    --predicate 'process == "Minis"' > audit/simulator-app.log
echo 'Installed, launched, and process present after 20 seconds.' >> audit/simulator-launch.txt
