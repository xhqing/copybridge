#!/usr/bin/env bash
# 构建可分发产物：copybridge-<version>（当前平台编译二进制，供 GitHub Release 上传）
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(tr -d '[:space:]' < "$DIR/VERSION")"
OUT="$DIR/copybridge-$VERSION"

swiftc -O "$DIR/copybridge.swift" -o "$OUT"
echo "构建完成：$OUT"
