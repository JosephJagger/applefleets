#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
with_codex="false"
if [[ "${1:-}" == "--codex" ]]; then
  with_codex="true"
fi

cd "$project_root/Mac"
swift build -c release

install_root="$HOME/Library/Application Support/AppleFleets"
binary_path="$install_root/bin/applefleets"
launch_agents="$HOME/Library/LaunchAgents"
plist_path="$launch_agents/com.local.applefleets.watch.plist"
mkdir -p "$install_root/bin" "$install_root/logs" "$launch_agents"
cp ".build/release/applefleets" "$binary_path"

arguments=("$binary_path" "watch" "--interval" "15")
if [[ "$with_codex" == "true" ]]; then
  arguments+=("--codex")
fi

plist_tmp="$(mktemp /tmp/applefleets-launchd.XXXXXX)"
trap 'rm -f "$plist_tmp"' EXIT
{
  print '<?xml version="1.0" encoding="UTF-8"?>'
  print '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  print '<plist version="1.0"><dict>'
  print '<key>Label</key><string>com.local.applefleets.watch</string>'
  print '<key>ProgramArguments</key><array>'
  for argument in "${arguments[@]}"; do
    escaped="${argument//&/&amp;}"
    escaped="${escaped//</&lt;}"
    escaped="${escaped//>/&gt;}"
    print "<string>$escaped</string>"
  done
  print '</array>'
  print '<key>RunAtLoad</key><true/>'
  print '<key>KeepAlive</key><true/>'
  print "<key>StandardOutPath</key><string>$install_root/logs/watch.log</string>"
  print "<key>StandardErrorPath</key><string>$install_root/logs/watch-error.log</string>"
  print '</dict></plist>'
} > "$plist_tmp"

plutil -lint "$plist_tmp"
cp "$plist_tmp" "$plist_path"
launchctl bootout "gui/$(id -u)" "$plist_path" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist_path"
print "AppleFleets 已安装并开始监听。日志：$install_root/logs"

