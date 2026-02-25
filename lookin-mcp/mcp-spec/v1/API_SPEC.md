# Lookin-MCP API 规格（P0）

版本：`v1`  
适用范围：`lookin.health / lookin.get_selected_view_context / lookin.set_requirement_items / lookin.get_requirement_code_info / lookin.capture_selected_view_screenshot`

## 1. 目标

本文件定义编码前的 API 契约：

- 每个 Tool 的入参 Schema
- 每个 Tool 的出参 Schema（成功）
- 统一错误模型（失败）

## 2. 通用约定

## 2.1 调用语义

- 所有 Tool 名称使用 `lookin.*` 前缀。
- 采用 MCP Tool 调用语义；以下 Schema 描述的是 `structuredContent` 的结构。
- 失败时返回 MCP error，error `data` 必须遵循本文“统一错误模型”。

## 2.2 通用字段约束

- `timestamp`：Unix 毫秒时间戳（`int64`）。
- `sessionId`：字符串，来自 `appInfoIdentifier`。
- `nodeId`：字符串，优先取 `viewOid`，否则取 `layerOid`。
- `codeInfo`：`String`，**不限制格式**，由调用方/LLM 自行理解。

## 2.3 统一错误模型

失败响应使用 MCP error，`data` 字段结构如下：

```json
{
  "code": "LOOKIN_MCP_NO_SELECTION",
  "message": "No selected view in current session.",
  "recoverable": true,
  "hint": "Please select a view in Lookin and retry.",
  "sessionId": "1844674407370955",
  "timestamp": 1739999999999
}
```

字段定义：

- `code`：稳定错误码（见第 4 节）
- `message`：可读错误信息
- `recoverable`：是否可通过重试/切换状态恢复
- `hint`：恢复建议
- `sessionId` / `timestamp`：可用时返回

## 3. Tool 规格

## 3.1 `lookin.health`

用途：最小可用探针，用于连接与会话预检。  
复杂度约束：不遍历 hierarchy、不读取 attributes。

### 参数 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {},
  "additionalProperties": false
}
```

### 成功返回 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": [
    "status",
    "timestamp"
  ],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["ok", "no_session"]
    },
    "sessionId": { "type": "string" },
    "appName": { "type": "string" },
    "appBundleIdentifier": { "type": "string" },
    "timestamp": { "type": "integer" }
  },
  "additionalProperties": false
}
```

### 成功示例

```json
{
  "status": "ok",
  "sessionId": "94837612",
  "appName": "SwiftUIApp",
  "appBundleIdentifier": "com.example.swiftuiapp",
  "timestamp": 1740123456789
}
```

### 失败示例

```json
{
  "code": "LOOKIN_MCP_NO_SESSION",
  "message": "No active inspectable app session.",
  "recoverable": true,
  "hint": "Connect an app in Lookin, then retry.",
  "timestamp": 1740123456790
}
```

## 3.2 `lookin.get_selected_view_context`

用途：返回当前选中视图的结构化上下文（FR-1）。  
该接口采用 **Dashboard-first** 设计：核心是 iOS 视图属性（右侧 Dashboard 等价信息），`parent/children` 仅作为结构提示。

### 参数 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "childrenDepth": { "type": "integer", "minimum": 0, "default": 1 }
  },
  "additionalProperties": false
}
```

### 成功返回 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["session", "selectedNode"],
  "properties": {
    "session": {
      "type": "object",
      "required": ["sessionId", "timestamp"],
      "properties": {
        "sessionId": { "type": "string" },
        "appName": { "type": "string" },
        "appBundleIdentifier": { "type": "string" },
        "timestamp": { "type": "integer" }
      },
      "additionalProperties": false
    },
    "selectedNode": {
      "type": "object",
      "required": ["identity", "iosRaw", "dashboard"],
      "properties": {
        "identity": {
          "type": "object",
          "required": ["nodeId"],
          "properties": {
            "nodeId": { "type": "string" },
            "viewOid": { "type": "integer" },
            "layerOid": { "type": "integer" }
          },
          "additionalProperties": false
        },
        "iosRaw": {
          "type": "object",
          "properties": {
            "classChainList": { "type": "array", "items": { "type": "string" } },
            "rawClassName": { "type": "string" },
            "memoryAddress": { "type": "string" },
            "frame": {
              "type": "object",
              "properties": {
                "x": { "type": "number" },
                "y": { "type": "number" },
                "width": { "type": "number" },
                "height": { "type": "number" }
              },
              "required": ["x", "y", "width", "height"],
              "additionalProperties": false
            },
            "bounds": {
              "type": "object",
              "properties": {
                "x": { "type": "number" },
                "y": { "type": "number" },
                "width": { "type": "number" },
                "height": { "type": "number" }
              },
              "required": ["x", "y", "width", "height"],
              "additionalProperties": false
            },
            "isHidden": { "type": "boolean" },
            "alpha": { "type": "number" },
            "representedAsKeyWindow": { "type": "boolean" },
            "hostViewControllerClassName": { "type": "string" },
            "specialTrace": { "type": "string" },
            "ivarTraces": {
              "type": "array",
              "items": {
                "type": "object",
                "required": ["relation", "hostClassName", "ivarName"],
                "properties": {
                  "relation": { "type": "string" },
                  "hostClassName": { "type": "string" },
                  "ivarName": { "type": "string" }
                },
                "additionalProperties": false
              }
            }
          },
          "additionalProperties": false
        },
        "dashboard": {
          "type": "object",
          "required": ["groups"],
          "properties": {
            "groups": {
              "type": "array",
              "items": {
                "type": "object",
                "required": ["groupIdentifier", "groupTitle", "sections"],
                "properties": {
                  "groupIdentifier": { "type": "string" },
                  "groupTitle": { "type": "string" },
                  "isUserCustom": { "type": "boolean" },
                  "sections": {
                    "type": "array",
                    "items": {
                      "type": "object",
                      "required": ["sectionIdentifier", "sectionTitle", "attributes"],
                      "properties": {
                        "sectionIdentifier": { "type": "string" },
                        "sectionTitle": { "type": "string" },
                        "isUserCustom": { "type": "boolean" },
                        "attributes": {
                          "type": "array",
                          "items": {
                            "type": "object",
                            "required": ["attrIdentifier", "attrTitle"],
                            "properties": {
                              "attrIdentifier": { "type": "string" },
                              "attrTitle": { "type": "string" },
                              "displayTitle": { "type": "string" },
                              "value": {},
                              "extraValue": {}
                            },
                            "additionalProperties": false
                          }
                        }
                      },
                      "additionalProperties": false
                    }
                  }
                },
                "additionalProperties": false
              }
            }
          },
          "additionalProperties": false
        },
        "structureHints": {
          "type": "object",
          "properties": {
            "parent": {
              "type": "object",
              "required": ["nodeId", "className", "frame"],
              "properties": {
                "nodeId": { "type": "string" },
                "className": { "type": "string" },
                "frame": {
                  "type": "object",
                  "properties": {
                    "x": { "type": "number" },
                    "y": { "type": "number" },
                    "width": { "type": "number" },
                    "height": { "type": "number" }
                  },
                  "required": ["x", "y", "width", "height"],
                  "additionalProperties": false
                }
              },
              "additionalProperties": false
            },
            "childrenSummary": {
              "type": "array",
              "items": {
                "type": "object",
                "required": ["nodeId", "className", "frame", "subitemCount"],
                "properties": {
                  "nodeId": { "type": "string" },
                  "className": { "type": "string" },
                  "frame": {
                    "type": "object",
                    "properties": {
                      "x": { "type": "number" },
                      "y": { "type": "number" },
                      "width": { "type": "number" },
                      "height": { "type": "number" }
                    },
                    "required": ["x", "y", "width", "height"],
                    "additionalProperties": false
                  },
                  "subitemCount": { "type": "integer" }
                },
                "additionalProperties": false
              }
            }
          },
          "additionalProperties": false
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
```

### 成功示例

```json
{
  "session": {
    "sessionId": "94837612",
    "appName": "SwiftUIApp",
    "appBundleIdentifier": "com.example.swiftuiapp",
    "timestamp": 1740123457000
  },
  "selectedNode": {
    "identity": {
      "nodeId": "102938",
      "viewOid": 102938,
      "layerOid": 202938
    },
    "iosRaw": {
      "classChainList": ["UIStackView", "UIView", "UIResponder", "NSObject"],
      "rawClassName": "UIStackView",
      "memoryAddress": "0x600003f14000",
      "frame": { "x": 8, "y": 0, "width": 294, "height": 40 },
      "bounds": { "x": 0, "y": 0, "width": 294, "height": 40 },
      "isHidden": false,
      "alpha": 1,
      "representedAsKeyWindow": false
    },
    "dashboard": {
      "groups": [
        {
          "groupIdentifier": "l",
          "groupTitle": "Layout",
          "isUserCustom": false,
          "sections": [
            {
              "sectionIdentifier": "l_f",
              "sectionTitle": "Frame",
              "isUserCustom": false,
              "attributes": [
                {
                  "attrIdentifier": "l_f_f",
                  "attrTitle": "Frame",
                  "displayTitle": "Frame",
                  "value": { "x": 8, "y": 0, "width": 294, "height": 40 },
                  "extraValue": null
                }
              ]
            }
          ]
        }
      ]
    },
    "structureHints": {
      "parent": {
        "nodeId": "8989",
        "className": "UIScrollView",
        "frame": { "x": 0, "y": 0, "width": 375, "height": 812 }
      },
      "childrenSummary": [
        {
          "nodeId": "209383",
          "className": "UIButton",
          "frame": { "x": 0, "y": 0, "width": 36, "height": 40 },
          "subitemCount": 0
        }
      ]
    }
  }
}
```

### 失败示例

```json
{
  "code": "LOOKIN_MCP_NO_SELECTION",
  "message": "No selected view in current session.",
  "recoverable": true,
  "hint": "Please select a view in Lookin and retry.",
  "sessionId": "94837612",
  "timestamp": 1740123457001
}
```

### 合理性证明（验收口径）

`get_selected_view_context` 的 schema 合理性通过以下 3 条验证：

1. 同源性：`dashboard.groups[].sections[].attributes[]` 与 Lookin Dashboard 渲染输入同构（`selectedItem -> queryAllAttrGroupList -> attrSections -> attributes`）。
2. 一致性：`dashboard.groups[].sections[].attributes[]` 的数量与当前选中节点真实属性数量一致。
3. 完整性策略：成功响应必须包含可用的 `dashboard.groups[].sections[].attributes[]`；若当前选中节点不支持完整属性上下文（如 customInfo），应返回错误而非部分成功。

## 3.3 `lookin.set_requirement_items`

用途：增删需求项列表（append/remove），并刷新 `codeInfo` 上下文。

### 参数 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["operation", "items"],
  "properties": {
    "operation": {
      "type": "string",
      "enum": ["append", "remove"]
    },
    "items": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["requirementId"],
        "properties": {
          "requirementId": { "type": "string", "minLength": 1 },
          "description": { "type": "string", "minLength": 1 }
        },
        "additionalProperties": false
      }
    }
  },
  "additionalProperties": false
}
```

说明：

- `operation=append`：追加 requirement 项；每个 `item` 必须包含 `requirementId + description`。
- `operation=remove`：移除 requirement 项；每个 `item` 仅使用 `requirementId`，`description` 会被忽略。

### 成功返回 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["sessionId", "timestamp", "operation", "total"],
  "properties": {
    "sessionId": { "type": "string" },
    "timestamp": { "type": "integer" },
    "operation": {
      "type": "string",
      "enum": ["append", "remove"]
    },
    "total": { "type": "integer" },
    "items": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["requirementId", "description"],
        "properties": {
          "requirementId": { "type": "string" },
          "description": { "type": "string" }
        },
        "additionalProperties": false
      }
    }
  },
  "additionalProperties": false
}
```

### 成功示例

```json
{
  "sessionId": "94837612",
  "timestamp": 1740123457100,
  "operation": "append",
  "total": 2,
  "items": [
    {"requirementId": "R-1", "description": "首页右上角搜索按钮"},
    {"requirementId": "R-2", "description": "点赞按钮文案与图标"}
  ]
}
```

### 失败示例

```json
{
  "code": "LOOKIN_MCP_DUP_REQUIREMENT_ID",
  "message": "Duplicate requirementId detected: R-1",
  "recoverable": true,
  "hint": "Ensure requirementId is unique in one request.",
  "sessionId": "94837612",
  "timestamp": 1740123457101
}
```

## 3.4 `lookin.get_requirement_code_info`

用途：拉取 requirement 与 `codeInfo` 映射。

### 参数 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {},
  "additionalProperties": false
}
```

### 成功返回 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["sessionId", "timestamp", "records"],
  "properties": {
    "sessionId": { "type": "string" },
    "timestamp": { "type": "integer" },
    "records": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["requirementId", "description", "codeInfo"],
        "properties": {
          "requirementId": { "type": "string" },
          "description": { "type": "string" },
          "codeInfo": { "type": "string" }
        },
        "additionalProperties": false
      }
    }
  },
  "additionalProperties": false
}
```

### 成功示例

```json
{
  "sessionId": "94837612",
  "timestamp": 1740123457200,
  "records": [
    {
      "requirementId": "R-1",
      "description": "首页右上角搜索按钮",
      "codeInfo": "SearchButtonView, SearchIconView; file=Modules/Search/SearchHeaderView.m"
    },
    {
      "requirementId": "R-2",
      "description": "点赞按钮文案与图标",
      "codeInfo": "DUXDiggButton|DUXDiggButtonLabel|DUXDiggButtonImage"
    }
  ]
}
```

### 失败示例

```json
{
  "code": "LOOKIN_MCP_NO_SESSION",
  "message": "No active inspectable app session.",
  "recoverable": true,
  "hint": "Connect an app in Lookin, then retry.",
  "timestamp": 1740123457201
}
```

## 3.5 `lookin.capture_selected_view_screenshot`

用途：导出当前选中视图截图文件路径（FR-3）。

### 参数 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "format": {
      "type": "string",
      "enum": ["png"],
      "default": "png"
    }
  },
  "additionalProperties": false
}
```

### 成功返回 Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": [
    "sessionId",
    "nodeId",
    "path",
    "width",
    "height",
    "format",
    "timestamp"
  ],
  "properties": {
    "sessionId": { "type": "string" },
    "nodeId": { "type": "string" },
    "path": { "type": "string" },
    "width": { "type": "integer" },
    "height": { "type": "integer" },
    "format": { "type": "string", "enum": ["png"] },
    "timestamp": { "type": "integer" }
  },
  "additionalProperties": false
}
```

### 成功示例

```json
{
  "sessionId": "94837612",
  "nodeId": "102938",
  "path": "/Users/bytedance/Library/Caches/com.lookin.client/mcp-screenshots/102938_1740123457400.png",
  "width": 294,
  "height": 40,
  "format": "png",
  "timestamp": 1740123457400
}
```

### 失败示例

```json
{
  "code": "LOOKIN_MCP_SCREENSHOT_FAILED",
  "message": "Failed to write screenshot file.",
  "recoverable": true,
  "hint": "Check cache directory permission and retry.",
  "sessionId": "94837612",
  "timestamp": 1740123457401
}
```

## 4. 错误码全集（P0）

- `LOOKIN_MCP_NO_SESSION`
  - 语义：当前无可用调试会话
  - 触发：未连接 Inspecting App / 会话已结束
  - 恢复：在 Lookin 中连接 App 后重试

- `LOOKIN_MCP_NO_SELECTION`
  - 语义：当前未选中视图
  - 触发：调用需要选中节点的 Tool（如 context/screenshot）
  - 恢复：在左树或中预览选择目标节点

- `LOOKIN_MCP_DUP_REQUIREMENT_ID`
  - 语义：`requirementId` 重复
  - 触发：`set_requirement_items` 请求内重复
  - 恢复：修正重复 ID 后重试

- `LOOKIN_MCP_REQUIREMENT_NOT_FOUND`
  - 语义：目标 requirement 不存在
  - 触发：`set_requirement_items` 在 `operation=remove` 时指定了不存在的 `requirementId`
  - 恢复：先调用 `set_requirement_items`

- `LOOKIN_MCP_SCREENSHOT_FAILED`
  - 语义：截图写盘失败
  - 触发：截图对象缺失/路径写入失败
  - 恢复：检查会话与文件权限后重试

- `LOOKIN_MCP_BAD_ARGUMENT`
  - 语义：参数不合法
  - 触发：入参缺失、类型错误、取值越界，或当前选中节点不支持完整属性上下文（如 customInfo）
  - 恢复：按 Schema 修正请求参数

## 5. 与 PRD/技术方案对齐说明

- 与 `lookin-mcp/mcp-spec/v1/PRD.md` 对齐：
  - FR-1 以 Dashboard 属性结构为核心输出
  - FR-2 `codeInfo` 为 `String` 且格式不限制
  - FR-3 返回截图文件路径
  - FR-4 所有 Tool 返回 `sessionId/timestamp`（失败时可选）
- 与 `lookin-mcp/mcp-spec/v1/TECHNICAL_DESIGN.md` 对齐：
  - `lookin.health` 低复杂度保留
  - 传输使用 Streamable HTTP（本地回环）
  - 短期持久化策略不影响本 API 契约
