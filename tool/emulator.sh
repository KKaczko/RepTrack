#!/usr/bin/env bash
# Uruchamia emulator RepTrack (docs/development.md) i czeka na gotowy system.
#
#   bash tool/emulator.sh            okno emulatora
#   bash tool/emulator.sh --headless bez okna (testy automatyczne)
set -euo pipefail

AVD="${REPTRACK_AVD:-RepTrack_360dp}"
SDK="${ANDROID_HOME:-D:/Dev/tools/android-sdk}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"

window_args=()
if [[ "${1:-}" == "--headless" ]]; then
  window_args=(-no-window)
fi

if "$ADB" devices | grep -q '^emulator-'; then
  echo "Emulator już działa."
else
  echo "Start $AVD…"
  "$EMULATOR" -avd "$AVD" -no-boot-anim -gpu auto -no-audio "${window_args[@]}" \
    > /dev/null 2>&1 &
fi

"$ADB" wait-for-device
until [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
  sleep 2
done
echo "Emulator gotowy: $("$ADB" devices | grep '^emulator-' | cut -f1)"
