![Preview](https://cdn.lookin.work/public/style/images/independent/homepage/preview_en_1x.jpg "Preview")

# Introduction
You can inspect and modify views in iOS app via Lookin, just like UI Inspector in Xcode, or another app called Reveal.

Official Website：https://lookin.work/

# Integration Guide
To use Lookin macOS app, you need to integrate LookinServer (iOS Framework of Lookin) into your iOS project.

> **Warning**
Never integrate LookinServer in Release building configuration.

## via CocoaPods:
### Swift Project
`pod 'LookinServer', :subspecs => ['Swift'], :configurations => ['Debug']`
### Objective-C Project
`pod 'LookinServer', :configurations => ['Debug']`
## via Swift Package Manager:
`https://github.com/QMUI/LookinServer/`

# Repository
LookinServer: https://github.com/QMUI/LookinServer

macOS app: https://github.com/hughkli/Lookin/

# Tips
- How to display custom information in Lookin: https://bytedance.larkoffice.com/docx/TRridRXeUoErMTxs94bcnGchnlb
- How to display more member variables in Lookin: https://bytedance.larkoffice.com/docx/CKRndHqdeoub11xSqUZcMlFhnWe
- How to turn on Swift optimization for Lookin: https://bytedance.larkoffice.com/docx/GFRLdzpeKoakeyxvwgCcZ5XdnTb
- Documentation Collection: https://bytedance.larkoffice.com/docx/Yvv1d57XQoe5l0xZ0ZRc0ILfnWb

# Lookin MCP (Local)
After Lookin app starts and connects to a target iOS app, MCP is exposed on local endpoint:

- `http://127.0.0.1:4010/mcp`

Health check (JSON-RPC 2.0):

```bash
curl -sS -X POST "http://127.0.0.1:4010/mcp" \
  -H "Content-Type: application/json" \
  -H "MCP-Protocol-Version: 2025-06-18" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"lookin.health","arguments":{}}}'
```

## Agent Configuration (Codex / Claude Code)

### Codex
Create project config file `.codex/config.toml`:

```toml
[mcp_servers.LookinMCP]
url = "http://127.0.0.1:4010/mcp"
```

### Claude Code
Create project file `.mcp.json`:

```json
{
  "mcpServers": {
    "LookinMCP": {
      "url": "http://127.0.0.1:4010/mcp"
    }
  }
}
```

Then restart the agent session and verify by calling `lookin.health`.

# lookinmcp-cli
You can use the published CLI package to call MCP tools directly:

```bash
# one-off
npx @cheng-pang/lookinmcp-cli health

# install locally (global)
npm install -g @cheng-pang/lookinmcp-cli
lookinmcp-cli get_selected_view_context --children-depth 1

# install in current project
npm install -D @cheng-pang/lookinmcp-cli
./node_modules/.bin/lookinmcp-cli get_requirement_code_info
```

Supported commands:
- `health`
- `get_selected_view_context`
- `set_requirement_items`
- `get_requirement_code_info`
- `capture_selected_view_screenshot`

# Acknowledgements
https://qxh1ndiez2w.feishu.cn/docx/YIFjdE4gIolp3hxn1tGckiBxnWf

---
# 简介
Lookin 可以查看与修改 iOS App 里的 UI 对象，类似于 Xcode 自带的 UI Inspector 工具，或另一款叫做 Reveal 的软件。

官网：https://lookin.work/

# 安装 LookinServer Framework
如果这是你的 iOS 项目第一次使用 Lookin，则需要先把 LookinServer 这款 iOS Framework 集成到你的 iOS 项目中。

> **Warning**
记得不要在 AppStore 模式下集成 LookinServer。

## 通过 CocoaPods：

### Swift 项目
`pod 'LookinServer', :subspecs => ['Swift'], :configurations => ['Debug']`
### Objective-C 项目
`pod 'LookinServer', :configurations => ['Debug']`

## 通过 Swift Package Manager:
`https://github.com/QMUI/LookinServer/`

# 源代码仓库

iOS 端 LookinServer：https://github.com/QMUI/LookinServer

macOS 端软件：https://github.com/hughkli/Lookin/

# 技巧
- 如何在 Lookin 中展示自定义信息: https://bytedance.larkoffice.com/docx/TRridRXeUoErMTxs94bcnGchnlb
- 如何在 Lookin 中展示更多成员变量: https://bytedance.larkoffice.com/docx/CKRndHqdeoub11xSqUZcMlFhnWe
- 如何为 Lookin 开启 Swift 优化: https://bytedance.larkoffice.com/docx/GFRLdzpeKoakeyxvwgCcZ5XdnTb
- 文档汇总：https://bytedance.larkoffice.com/docx/Yvv1d57XQoe5l0xZ0ZRc0ILfnWb

# Lookin MCP（本地）
当 Lookin 启动并连接到目标 iOS App 后，会在本地暴露 MCP 服务：

- `http://127.0.0.1:4010/mcp`

健康检查（JSON-RPC 2.0）：

```bash
curl -sS -X POST "http://127.0.0.1:4010/mcp" \
  -H "Content-Type: application/json" \
  -H "MCP-Protocol-Version: 2025-06-18" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"lookin.health","arguments":{}}}'
```

## Agent 配置方式（Codex / Claude Code）

### Codex
在项目下创建 `.codex/config.toml`：

```toml
[mcp_servers.LookinMCP]
url = "http://127.0.0.1:4010/mcp"
```

### Claude Code
在项目下创建 `.mcp.json`：

```json
{
  "mcpServers": {
    "LookinMCP": {
      "url": "http://127.0.0.1:4010/mcp"
    }
  }
}
```

配置后重启 Agent 会话，再调用 `lookin.health` 验证连通性。

# lookinmcp-cli 使用
可以通过已发布的 CLI 包直接调用 MCP tools：

```bash
# 一次性执行
npx @cheng-pang/lookinmcp-cli health

# 全局安装
npm install -g @cheng-pang/lookinmcp-cli
lookinmcp-cli get_selected_view_context --children-depth 1

# 项目内安装
npm install -D @cheng-pang/lookinmcp-cli
./node_modules/.bin/lookinmcp-cli get_requirement_code_info
```

支持的命令：
- `health`
- `get_selected_view_context`
- `set_requirement_items`
- `get_requirement_code_info`
- `capture_selected_view_screenshot`

# 鸣谢
https://qxh1ndiez2w.feishu.cn/docx/YIFjdE4gIolp3hxn1tGckiBxnWf
