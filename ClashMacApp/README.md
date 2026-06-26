# Clash Mac（自研原生客户端）

SwiftUI 原生 macOS Mihomo 客户端，对标 Clash Verge Rev 的使用体验。

## 环境要求

- macOS 15.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## 快速开始

```bash
cd ClashMacApp
./Scripts/download-mihomo.sh   # 下载 Mihomo 内核到 Resources/Core/
xcodegen generate
open ClashMac.xcodeproj
```

在 Xcode 中 ⌘R 运行。首次 TUN 模式需将 `Clash Mac.app` 复制到 `/Applications/` 并在系统设置中批准 Helper。

## 工程结构

```
ClashMacApp/
├── ClashMac/           # 主应用源码
├── ClashMacHelper/     # Privileged Helper（TUN）
├── Shared/             # XPC 协议
├── Config/             # Entitlements、LaunchDaemon plist
├── Scripts/            # 内核下载脚本
└── project.yml         # XcodeGen 配置
```

## 数据目录

- 配置：`~/Library/Application Support/ClashMac/`
- 内核更新：`~/Library/Application Support/ClashMac/Core/`
- GeoData：`~/Library/Application Support/ClashMac/work/`

从旧版 LiteClash 目录迁移会在首次启动时自动完成。

## 功能概览

- 菜单栏面板 + 控制台（首页 / 代理 / 订阅 / 连接 / 规则 / 日志 / 解锁 / 设置）
- TUN（Privileged Helper）与系统代理 / 守护
- 多 Profile、订阅导入（含 Base64）、本地 YAML、删除与批量更新
- 代理卡片：国旗、协议标签、单节点 / 组测速
- 连接活跃/已关闭、过滤、详情、累计流量与侧边栏曲线
- 规则可视化添加、YAML 编辑、日志流
- 解锁检测 + 自定义 URL
- 内核与 GeoData 一键更新、CLI（`~/.local/bin/clashmac`）、自定义菜单栏图标
