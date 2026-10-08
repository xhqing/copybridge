#!/usr/bin/env bash
# 安装 copybridge：编译 → 装二进制 → 注册 LaunchAgent（用户级，无需 sudo）
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/copybridge"
PLIST="$HOME/Library/LaunchAgents/com.xhq.copybridge.plist"
LABEL="com.xhq.copybridge"
LOG="$HOME/Library/Logs/copybridge.log"

echo "==> 编译"
swiftc -O "$DIR/copybridge.swift" -o "$DIR/copybridge"

echo "==> 安装二进制到 $BIN"
mkdir -p "$BIN_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp "$DIR/copybridge" "$BIN"
chmod +x "$BIN"

echo "==> 写入 LaunchAgent"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLISTEOF

echo "==> 启动"
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"
launchctl kickstart "gui/$UID/$LABEL" 2>/dev/null || true
sleep 0.5
echo "==> 状态:"
launchctl print "gui/$UID/$LABEL" 2>/dev/null | grep -E "state|pid" | head -3 || echo "(launchctl 未列出，请检查日志 $LOG)"
echo "完成。日志：$LOG"
