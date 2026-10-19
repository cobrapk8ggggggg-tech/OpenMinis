#!/usr/bin/env bash
set -euo pipefail
mkdir -p audit/app
ditto -x -k audit/artifact/OpenMinis-simulator.zip audit/app
APP_PATH="$PWD/audit/app/Minis.app"
test -f "$APP_PATH/Minis"
xcrun simctl list devices available -j > audit/simulator-devices.json
SIMULATOR_ID=$(python3 - <<'PY'
import json
d=json.load(open('audit/simulator-devices.json'))
for runtime, devices in sorted(d['devices'].items(), reverse=True):
    phones=[x for x in devices if x.get('isAvailable') and 'iPhone' in x['name']]
    if 'iOS' in runtime and phones:
        print(phones[0]['udid']);break
else:raise SystemExit('No iPhone simulator available')
PY
)
collect_diagnostics() {
    xcrun simctl io "$SIMULATOR_ID" screenshot audit/simulator-last-state.png || true
    python3 - "$SIMULATOR_ID" <<'PY'
import subprocess,sys
with open('audit/simulator-app.log','w') as out:
    try:subprocess.run(['xcrun','simctl','spawn',sys.argv[1],'log','show','--last','3m','--style','compact','--predicate','process == "Minis"'],stdout=out,stderr=out,timeout=45)
    except subprocess.TimeoutExpired:out.write('\nLog query timed out.\n')
PY
    find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -iname '*Minis*' -type f -exec cp {} audit/ \; 2>/dev/null || true
}
trap collect_diagnostics EXIT
xcrun simctl boot "$SIMULATOR_ID" || true
python3 - "$SIMULATOR_ID" <<'PY'
import subprocess,sys
subprocess.run(['xcrun','simctl','bootstatus',sys.argv[1],'-b'],check=True,timeout=240)
PY
# Device-only restricted entitlements (HealthKit, iCloud, NFC, WeatherKit) must
# not be passed to host taskgated when running a local ad-hoc simulator binary.
# Keep the App Group required by the unmodified app's persistent storage.
python3 - <<'PY'
import plistlib
with open('audit/simulator-entitlements.plist','wb') as f:
    plistlib.dump({'com.apple.security.application-groups':['group.com.openminis.app']},f)
PY
xattr -cr "$APP_PATH"
codesign --force --deep --sign - --entitlements audit/simulator-entitlements.plist "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
codesign -d --entitlements :- "$APP_PATH" > audit/signature.txt 2>&1
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" com.openminis.app 2>&1 | tee audit/simulator-launch.txt
SIMULATOR_PID=$(awk '/com.openminis.app:/{print $NF}' audit/simulator-launch.txt)
test -n "$SIMULATOR_PID"
sleep 20
kill -0 "$SIMULATOR_PID"
ps -p "$SIMULATOR_PID" -o pid=,comm= > audit/simulator-process.txt
xcrun simctl io "$SIMULATOR_ID" screenshot audit/simulator-openminis.png
echo 'PASS: stock OpenMinis 1.14 remained alive after 20 seconds.' | tee -a audit/simulator-launch.txt
