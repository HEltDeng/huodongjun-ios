#!/bin/zsh
set -eu
task_sim="${1:-DB71B0C2-FF9A-4D52-9B10-A99E1558FBE9}"
task_developer="$(xcode-select -p)"
task_state="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin); print(next((d["state"] for devices in data["devices"].values() for d in devices if d["udid"] == sys.argv[1]), "Missing"))' "$task_sim")"
if [[ "$task_state" == "Missing" ]]; then
  echo "找不到这台模拟器。请在 Xcode → Window → Devices and Simulators 中检查设备。"
  exit 1
fi
if [[ "$task_state" == "Shutdown" ]]; then
  xcrun simctl boot "$task_sim"
fi
open "$task_developer/Applications/Simulator.app" --args -CurrentDeviceUDID "$task_sim"
xcrun simctl bootstatus "$task_sim" -b
