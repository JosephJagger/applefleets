#!/bin/zsh
set -euo pipefail

plist_path="$HOME/Library/LaunchAgents/com.local.applefleets.watch.plist"
if [[ -f "$plist_path" ]]; then
  launchctl bootout "gui/$(id -u)" "$plist_path" 2>/dev/null || true
  rm "$plist_path"
fi
print 'AppleFleets 自动监听已停止。生成的内容和配对配置均已保留。'

