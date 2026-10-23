#!/bin/zsh
set -eu

# A separate Google Play AVD used only to inspect the original Luma app.
# This script does not click, sign in, or operate any Android application.
task_sdk="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
task_avd="Luma_Reference_Play_API_36_1"
task_log="$HOME/Library/Logs/LumaReferenceEmulator.log"

if [[ ! -x "$task_sdk/emulator/emulator" ]]; then
  print "找不到 Android SDK：$task_sdk"
  exit 1
fi
if ! "$task_sdk/emulator/emulator" -list-avds | /usr/bin/grep -Fxq "$task_avd"; then
  print "尚未创建 $task_avd。请先完成 Google Play 系统镜像安装。"
  exit 1
fi
if "$task_sdk/platform-tools/adb" devices | /usr/bin/grep -q '^emulator-5556[[:space:]]'; then
  print "参考模拟器已在运行，请切换到 Android Emulator 窗口。"
  exit 0
fi
mkdir -p "$HOME/Library/Logs"
print "正在启动 Luma 参考模拟器。"
exec "$task_sdk/emulator/emulator" -avd "$task_avd" -port 5556 -netdelay none -netspeed full -no-boot-anim > "$task_log" 2>&1
