<div align="center">
  <img src="assets/logo.svg" alt="copybridge" width="640">

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE.md)
  [![Version](https://img.shields.io/badge/Version-0.1.0-blue)](CHANGELOG.md)
  [![Type](https://img.shields.io/badge/Type-macOS%20Tool-0D9488)](#)
  [![Visitors](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/xhqing/xhqing/main/traffic/badges/copybridge.json)](https://github.com/xhqing)

  [English](README.md)
</div>

# copybridge

`copybridge` 是一个 macOS 剪贴板小桥：**在 VSCode 资源管理器里复制文件（⌘C），然后粘贴到任何地方**——Finder、微信、浏览器上传框，任何能接收文件的应用。VSCode 复制的文件原本只能粘回 VSCode 自己，copybridge 在后台悄悄把这个限制修掉。

## 解决什么问题

在 VSCode 资源管理器里复制文件时，VSCode 只往系统剪贴板写了它自己的**私有格式**（`code/file-list`）——这个格式的设计用途是「在 VSCode 内部粘贴文件」。系统应用不认识它，所以复制完到 Finder（或 VSCode 以外的任何地方）粘贴就是毫无反应，不管文件类型是什么（mp4、py，都一样）。

用 macOS 原生剪贴板探针实测验证：

- VSCode 里 ⌘C 后，剪贴板里只有 `code/file-list`（macOS 把它存在动态 UTI `dyn.…` 下）——没有 `public.file-url`、没有 `NSFilenamesPboardType`、没有文本；
- 之后到 Finder 文件夹里按 ⌘V：什么都没粘出来；
- 换成按系统原生格式写入同一个文件：Finder 正常粘贴。

（反向也一样——从 Finder 复制、往 VSCode 资源管理器里粘，长期不支持，官方 issue 是 microsoft/vscode#239898。）

## 工作原理

一个常驻的小进程（LaunchAgent）每 0.2 秒查看一次系统剪贴板。发现 VSCode 的私有格式 `code/file-list`（且剪贴板里还没有系统文件格式）时，它：

1. 从 URI 列表里解析出文件路径；
2. 补上 macOS 应用认识的格式——`NSFilenamesPboardType`（Finder 的传统文件格式）、`public.file-url`、`text/uri-list` 与纯文本路径；
3. 把 VSCode 的私有数据按原样（按原始动态 UTI 类型）写回——所以**在 VSCode 内部粘贴照旧可用**（已实测验证）。

你复制其它任何东西（纯文字、图片、来自其它应用的内容）时它完全不碰。如果未来 VSCode 官方自己支持了标准格式，copybridge 检测到系统格式已存在就会自动让路。

实现要点：macOS 会把非法 UTI 字符串 `code/file-list` 在「条目层」自动转成动态 UTI（`dyn.…`）存放——条目层用原名查不到，但剪贴板层的 API 可以读到。copybridge 把这两个方向的映射都处理好了。

## 安装与要求

- macOS（在 Apple 芯片上构建与测试）；
- 从源码构建需要 Xcode 命令行工具（`swiftc`）——或者直接从每次 Release 附带的预编译 arm64 二进制开始；
- 然后：

```bash
git clone https://github.com/xhqing/copybridge.git
cd copybridge
bash install.sh          # 编译 + 安装到 ~/.local/bin + 注册 LaunchAgent（无需 sudo）
```

`install.sh` 做三件事：编译、把二进制复制到 `~/.local/bin/copybridge`、注册用户级 LaunchAgent `com.xhq.copybridge`（登录时自动启动）。

卸载：

```bash
bash uninstall.sh        # 停止并移除 LaunchAgent 与二进制
```

## 验证是否生效

1. 在 VSCode 资源管理器里选中任意文件按 ⌘C；
2. 切到 Finder 按 ⌘V——文件出现；
3. `tail -f ~/Library/Logs/copybridge.log` 能看到 `bridged 1 file(s) to system clipboard` 一行。

## 日常管理

```bash
launchctl print gui/$UID/com.xhq.copybridge | grep -E "state|pid"   # 看状态
tail -f ~/Library/Logs/copybridge.log                              # 看日志
launchctl bootout gui/$UID/com.xhq.copybridge                      # 临时停用（下次登录自动恢复）
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.xhq.copybridge.plist   # 再启动
bash uninstall.sh                                                  # 彻底移除
```

## 边界

- **只对本地工作区生效**：远程窗口（SSH / WSL / 容器）里复制的文件会跳过（日志记 `skip: non-local uri`）——那种文件本来也拿不到 Finder。
- 复制后 0.2 秒内马上粘贴属于极端抢跑（正常手速不会遇到）；桥接在约 0.2 秒内完成。
- 目标应用认不认粘贴的文件取决于对方——copybridge 负责把「文件」正确放进剪贴板，接不接收是对方的事。

## 开发目录与生产目录

- **开发目录** = 本仓库（`~/Developer/copybridge`），一切改动在这里进行；
- **生产副本** = `~/.local/bin/copybridge`——LaunchAgent 实际运行的那份二进制；
- 生产副本只能来自正式发版的产物（tag + GitHub Release，用 `build.sh` 构建），或由 `install.sh` 现场编译一份新副本；禁止软链开发目录、禁止把常驻服务指向开发目录源码；
- 版本标识：源码里的版本常量（`let version = "…"`）与仓库根 `VERSION` 保持一致（由 CI 强制校验）。

## 版权与署名

Copyright (c) 2026 All Contributors。基于 [MIT License](LICENSE.md) 发布。

署名：使用或引用本项目时，请保留版权声明并注明来源：[copybridge](https://github.com/xhqing/copybridge)。
