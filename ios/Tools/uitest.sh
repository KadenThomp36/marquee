#!/bin/bash
#
# Run the UI walkthrough against a Marquee server and pull the screenshots out.
#
# The server and credentials come from your environment — never from this repo:
#
#   MARQUEE_TEST_SERVER=127.0.0.1:8010 \
#   MARQUEE_TEST_USER=you \
#   MARQUEE_TEST_PASSWORD=… \
#   Tools/uitest.sh
#
# With nothing set, only the "a fresh install reveals nothing" test runs, which is
# exactly what a stranger cloning this repo should be able to do.
#
# Point it at a *development* server. The household's real database is not a fixture.
set -euo pipefail

SIM="${MARQUEE_TEST_SIM:-iPhone 17 Pro}"
# xcodebuild's destination parser chokes on names with parentheses — "iPad Pro
# 11-inch (M4)" — so resolve whatever was asked for to a UDID and use that.
SIM_ID="$(xcrun simctl list devices available -j \
  | SIM="$SIM" python3 -c 'import json,re,sys,os
want = os.environ["SIM"]
data = json.load(sys.stdin)["devices"]

def version(runtime):
    return [int(part) for part in re.findall(r"\d+", runtime.rsplit(".", 1)[-1])]

# Newest runtime first: several runtimes carry a device of the same name, and only
# the iOS 26 ones can run a deployment target of 26.
for runtime in sorted(data, key=version, reverse=True):
    for device in data[runtime]:
        if device["name"] == want or device["udid"] == want:
            print(device["udid"]); raise SystemExit
raise SystemExit("no simulator named " + want)')"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${MARQUEE_TEST_OUT:-$ROOT/.uitest}"
BUNDLE="dev.kadenthompson.marquee"

cd "$ROOT"
mkdir -p "$OUT"
rm -rf "$OUT/result.xcresult" "$OUT/shots"
mkdir -p "$OUT/shots"

echo "▸ preparing $SIM"
xcrun simctl bootstatus "$SIM_ID" -b >/dev/null 2>&1 || true
# A previous run leaves a paired session in the simulator's keychain, and the
# pairing screen is half of what's under test — so start from genuinely unpaired.
xcrun simctl uninstall "$SIM_ID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl keychain "$SIM_ID" reset >/dev/null 2>&1 || true

echo "▸ building"
xcodebuild build-for-testing \
  -project Marquee.xcodeproj -scheme Marquee -sdk iphonesimulator \
  -destination "id=$SIM_ID" -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
  2>&1 | grep -E "error:|warning: .*Swift|BUILD" || true

echo "▸ testing"
# MQ_ONLY=AppearanceTests/testAppAtAccessibilityTextSize narrows a run while
# iterating on one screen. Unset, everything runs.
ONLY=()
[ -n "${MQ_ONLY:-}" ] && ONLY=(-only-testing "MarqueeUITests/$MQ_ONLY")

set +e
TEST_RUNNER_MARQUEE_TEST_SERVER="${MARQUEE_TEST_SERVER:-}" \
TEST_RUNNER_MARQUEE_TEST_USER="${MARQUEE_TEST_USER:-}" \
TEST_RUNNER_MARQUEE_TEST_PASSWORD="${MARQUEE_TEST_PASSWORD:-}" \
xcodebuild test-without-building \
  -project Marquee.xcodeproj -scheme Marquee -sdk iphonesimulator \
  -destination "id=$SIM_ID" \
  -resultBundlePath "$OUT/result.xcresult" \
  ${ONLY[@]+"${ONLY[@]}"} \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
  2>&1 | grep -E "Test Case|error:|XCTAssert"
STATUS=${PIPESTATUS[0]}
set -e

echo "▸ screenshots → $OUT/shots"
rm -rf "$OUT/attachments"
xcrun xcresulttool export attachments --path "$OUT/result.xcresult" \
  --output-path "$OUT/attachments" >/dev/null 2>&1 || true
python3 - "$OUT" <<'PY'
import json, pathlib, re, shutil, sys
out = pathlib.Path(sys.argv[1])
manifest = out / "attachments" / "manifest.json"
if not manifest.exists():
    raise SystemExit
for test in json.load(open(manifest)):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName", "")
        if not re.match(r"^\d\d", name):
            continue
        clean = re.sub(r"_\d+_[0-9A-F-]{36}", "", name)
        if not clean.endswith(".png"):
            clean += ".png"
        src = out / "attachments" / a["exportedFileName"]
        if src.exists():
            shutil.copy(src, out / "shots" / clean)
            print("  " + clean)
PY

exit $STATUS
