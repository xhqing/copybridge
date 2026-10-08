#!/usr/bin/env bash
# 卸载 copybridge：停止并移除 LaunchAgent 与二进制（日志保留）
set -euo pipefail

LABEL="com.xhq.copybridge"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BIN="$HOME/.local/bin/copybridge"

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
rm -f "$PLIST" "$BIN"
echo "已卸载。日志保留在 ~/Library/Logs/copybridge.log（可自行删除）"
