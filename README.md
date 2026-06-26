# ClashMac

原生 SwiftUI macOS Mihomo 客户端，UI 与使用体验参考 [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev)。

## 快速开始

```bash
cd ClashMacApp
./Scripts/download-mihomo.sh   # 可选：下载内嵌内核
xcodegen generate
open ClashMac.xcodeproj
```

详细说明见 [ClashMacApp/README.md](ClashMacApp/README.md)。

## 安全特性

- Helper XPC 签名校验 + 安装用户 GID 绑定
- 默认 Unix Socket API（HTTP 外部控制默认关闭）
- Keychain 存储控制 API 密钥
- 订阅 HTTPS 强制、Geo/内核下载 SHA256 清单校验
- 诊断导出自动脱敏

## License

MIT
