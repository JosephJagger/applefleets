#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
with_codex="false"
proxy_url=""
while (( $# > 0 )); do
  case "$1" in
    --codex)
      with_codex="true"
      shift
      ;;
    --proxy)
      if (( $# < 2 )); then
        print -u2 "--proxy 后面需要 HTTP 代理地址，例如 http://127.0.0.1:7890"
        exit 2
      fi
      proxy_url="$2"
      shift 2
      ;;
    *)
      print -u2 "未知参数：$1"
      print -u2 "用法：./scripts/install-mac-agent.sh [--codex] [--proxy http://127.0.0.1:端口]"
      exit 2
      ;;
  esac
done

if [[ -n "$proxy_url" && "$proxy_url" != http://* && "$proxy_url" != https://* ]]; then
  print -u2 "代理地址必须以 http:// 或 https:// 开头。请填写代理软件的 HTTP 端口。"
  exit 2
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
  if [[ -n "$proxy_url" ]]; then
    escaped_proxy="${proxy_url//&/&amp;}"
    escaped_proxy="${escaped_proxy//</&lt;}"
    escaped_proxy="${escaped_proxy//>/&gt;}"
    print '<key>EnvironmentVariables</key><dict>'
    print "<key>HTTPS_PROXY</key><string>$escaped_proxy</string>"
    print "<key>https_proxy</key><string>$escaped_proxy</string>"
    print '<key>NO_PROXY</key><string>localhost,127.0.0.1,::1,.local,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12</string>'
    print '<key>no_proxy</key><string>localhost,127.0.0.1,::1,.local,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12</string>'
    print '</dict>'
  fi
  print "<key>StandardOutPath</key><string>$install_root/logs/watch.log</string>"
  print "<key>StandardErrorPath</key><string>$install_root/logs/watch-error.log</string>"
  print '</dict></plist>'
} > "$plist_tmp"

plutil -lint "$plist_tmp"
cp "$plist_tmp" "$plist_path"
launchctl bootout "gui/$(id -u)" "$plist_path" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist_path"
print "AppleFleets 已安装并开始监听。日志：$install_root/logs"
if [[ -n "$proxy_url" ]]; then
  print "Codex HTTPS 请求使用代理：$proxy_url；iPhone 局域网连接保持直连。"
fi
