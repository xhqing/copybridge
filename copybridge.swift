// copybridge —— 让 VSCode 从资源管理器复制的文件可以直接粘贴到 Finder、微信等系统应用。
//
// 背景：VSCode 复制文件时只写它自己的私有剪贴板格式 `code/file-list`，
// 系统应用（Finder 等）不认识这个格式，所以「复制完粘到别处」没有反应。
//
// 原理：本进程常驻后台，每 0.2 秒查看一次系统剪贴板。一旦发现 `code/file-list`
// 出现（且剪贴板里还没有系统文件格式），就把文件以 macOS 原生格式补进去：
//   - NSFilenamesPboardType（Finder 传统文件格式，实测 Finder 可粘贴）
//   - public.file-url / text/uri-list / 纯文本（供其它应用取用）
// 同时保留 VSCode 自己的 `code/file-list`，所以在 VSCode 内部的粘贴照旧可用。
//
// 用法：
//   copybridge           常驻监听
//   copybridge --once    只处理一次当前剪贴板然后退出（用于测试）
//   copybridge --version 输出版本号

import AppKit
import Foundation

let vscodeFormat = NSPasteboard.PasteboardType("code/file-list")
let fileNamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
let fileURLType = NSPasteboard.PasteboardType("public.file-url")
let uriListType = NSPasteboard.PasteboardType("text/uri-list")

let version = "0.1.0"
let pollInterval: TimeInterval = 0.2
let runOnce = CommandLine.arguments.contains("--once")

func log(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    if let data = "[\(stamp)] \(message)\n".data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

/// 检查当前剪贴板；如果里面有 VSCode 复制文件留下的私有格式，就补充系统格式。
/// 返回 true 表示重写了剪贴板。
@discardableResult
func bridgeClipboardOnce() -> Bool {
    let pasteboard = NSPasteboard.general

    // 坑：macOS 会把 `code/file-list`（不是合法 UTI 字符串）在「条目层」自动转成
    // 动态 UTI（dyn.…）存放，条目层用原名查不到；而「剪贴板层」的 data(forType:)
    // 兼容旧式字符串、可以直接用原名读出。所以这里一律从剪贴板层读取。
    guard let rawListData = pasteboard.data(forType: vscodeFormat), !rawListData.isEmpty,
          let uriText = String(data: rawListData, encoding: .utf8) else { return false }

    // 已经是系统文件格式（或 VSCode 未来自己支持了），不动
    if pasteboard.data(forType: fileURLType) != nil || pasteboard.data(forType: fileNamesType) != nil {
        return false
    }

    var pathAndURI: [(path: String, uri: String)] = []
    for line in uriText.split(separator: "\n") where !line.isEmpty {
        let uriString = String(line)
        guard let url = URL(string: uriString), url.isFileURL else {
            log("skip: non-local uri \(uriString)")
            return false // 远程工作区等非本地文件：保持原样
        }
        pathAndURI.append((url.path, uriString))
    }
    let fm = FileManager.default
    let existing = pathAndURI.filter { fm.fileExists(atPath: $0.path) }
    guard !existing.isEmpty else { return false }

    // 找到承载这份数据的动态 UTI 类型名，重写时按原类型写回，
    // 保证 VSCode 内部的粘贴依然能读到（Electron 走同一映射查找）。
    var carrierType: NSPasteboard.PasteboardType?
    for item in pasteboard.pasteboardItems ?? [] {
        for type in item.types where item.data(forType: type) == rawListData {
            carrierType = type
        }
    }

    pasteboard.clearContents()
    let item = NSPasteboardItem()
    if let carrierType {
        item.setData(rawListData, forType: carrierType)
    }
    if let plist = try? PropertyListSerialization.data(fromPropertyList: existing.map { $0.path },
                                                       format: .binary, options: 0) {
        item.setData(plist, forType: fileNamesType)
    }
    if existing.count == 1 {
        item.setString(existing[0].uri, forType: fileURLType)
    }
    item.setString(existing.map { $0.uri }.joined(separator: "\n"), forType: uriListType)
    item.setString(existing.map { $0.path }.joined(separator: "\n"), forType: .string)

    pasteboard.writeObjects([item])
    log("bridged \(existing.count) file(s) to system clipboard")
    return true
}

if CommandLine.arguments.contains("--version") {
    print("copybridge \(version)")
    exit(0)
}

if runOnce {
    let changed = bridgeClipboardOnce()
    log(changed ? "done (clipboard rewritten)" : "done (nothing to do)")
    exit(0)
}

log("copybridge \(version) started (poll every \(pollInterval)s)")
var lastChangeCount = NSPasteboard.general.changeCount
while true {
    Thread.sleep(forTimeInterval: pollInterval)
    let pasteboard = NSPasteboard.general
    if pasteboard.changeCount != lastChangeCount {
        lastChangeCount = pasteboard.changeCount
        if bridgeClipboardOnce() {
            // 吸收刚才自己写入引起的变化
            lastChangeCount = NSPasteboard.general.changeCount
        }
    }
}
