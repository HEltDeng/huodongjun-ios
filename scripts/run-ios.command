#!/bin/zsh
set -eu
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_sim="${1:-DB71B0C2-FF9A-4D52-9B10-A99E1558FBE9}"
"$task_root/scripts/open-simulator.command" "$task_sim"
python3 "$task_root/scripts/generate_xcode_project.py"
xcodebuild -project "$task_root/ios/CampusEvents.xcodeproj" -scheme CampusEvents -configuration Debug -sdk iphonesimulator -destination "id=$task_sim" -derivedDataPath "$task_root/.build" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
xcrun simctl install "$task_sim" "$task_root/.build/Build/Products/Debug-iphonesimulator/CampusEvents.app"
xcrun simctl launch "$task_sim" cn.huodongjun.campus
