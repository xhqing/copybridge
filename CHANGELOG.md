# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.0] - 2026-10-08

### Added

- **copybridge 初版**：让 VSCode 资源管理器里「复制文件」（选中文件按 ⌘C / 右键复制）之后，可以直接粘贴到 Finder、微信、浏览器上传框等系统应用。原理：常驻小进程（LaunchAgent）每 0.2 秒查看一次系统剪贴板，发现 VSCode 私有格式 `code/file-list` 且剪贴板里还没有系统文件格式时，解析出文件路径并补上 `NSFilenamesPboardType`（Finder 传统格式）、`public.file-url`、`text/uri-list` 与纯文本路径；同时按原样保留 VSCode 的私有数据（按原始动态 UTI 类型写回），VSCode 内部粘贴不受影响（实测验证）。
- 只处理本地工作区（`file://`）的文件；远程窗口（SSH / WSL / 容器）复制的文件跳过、原剪贴板保持不动（日志记 `skip: non-local uri`）；普通复制（文字、图片、其它应用的任何内容）完全不碰。VSCode 未来若官方支持标准格式，本工具检测到系统格式已存在时会自动让路。
- `install.sh` / `uninstall.sh`：一键编译安装到 `~/.local/bin/copybridge` 并注册用户级 LaunchAgent（无需 sudo）+ 一键卸载。
- `copybridge --once`：只处理一次当前剪贴板后退出（用于测试）。
- `copybridge --version`：输出版本号。

### Project

- **建立本仓库（开发目录）**：copybridge 的开发在 `~/Developer/copybridge` 进行；`~/.local/bin/copybridge` 为生产副本（LaunchAgent 实际运行所在），发版（tag + GitHub Release）后从 Release 产物安装，禁止软链 / 直跑开发目录二进制（运行版本与开发版本隔离）。
- CI（`.github/workflows/ci.yml`，macOS runner）：Swift 编译检查、`--version` 输出与 `VERSION` 一致性检查、shell 脚本语法检查、shellcheck 静态检查。
- README 中英双语 + LOGO + 徽章；MIT LICENSE；CHANGELOG 与 VERSION。
- 踩坑记录（实现要点）：macOS 会把非法 UTI 字符串 `code/file-list` 在「条目层」自动转成动态 UTI（`dyn.…`）存放，条目层用原名查不到、剪贴板层（`NSPasteboard.data(forType:)`）才能查到——本工具按剪贴板层读取、按原始动态 UTI 名字写回，VSCode 内部粘贴才不受影响。
