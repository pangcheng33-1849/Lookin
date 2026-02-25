# Lookin-MCP API 规格（V2）

版本：`v2`  
范围：

- `lookin.get_hierarchy_by_node_id`
- `lookin.get_view_context_by_node_id`
- `lookin.capture_view_screenshot_by_node_id`

## 1. 通用约定

- `sessionId`：字符串，来自当前 inspect session。
- `timestamp`：Unix 毫秒时间戳（`int64`）。
- `nodeId`：字符串；规则与 v1 一致（优先 `viewOid`，否则 `layerOid`）。
- 失败返回 MCP error，错误码沿用 v1，并新增 `LOOKIN_MCP_NODE_NOT_FOUND`。

## 2. `lookin.get_hierarchy_by_node_id`

## 2.1 输入（最终）

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "nodeId": { "type": "string", "minLength": 1 },
    "depth": { "type": "integer", "minimum": 0, "maximum": 16, "default": 1 }
  },
  "additionalProperties": false
}
```

语义：

- `nodeId` 缺失：从 roots 开始返回子树。
- `depth=0`：仅返回起始层节点本身，不展开 children。
- `depth` 最大为 `16`，超过上限返回 `LOOKIN_MCP_BAD_ARGUMENT`。

## 2.2 输出（最终）

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["session", "hierarchy"],
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
    "hierarchy": {
      "type": "object",
      "required": ["startFrom", "depth", "nodes"],
      "properties": {
        "startFrom": { "type": "string", "enum": ["roots", "node"] },
        "startNodeId": { "type": "string" },
        "depth": { "type": "integer", "minimum": 0 },
        "nodes": {
          "type": "array",
          "items": { "$ref": "#/$defs/hierarchyNode" }
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false,
  "$defs": {
    "hierarchyNode": {
      "type": "object",
      "required": ["nodeId", "className", "ivarNameOfParent", "hasChildren", "children"],
      "properties": {
        "nodeId": { "type": "string" },
        "className": { "type": "string" },
        "ivarNameOfParent": { "type": "string" },
        "hasChildren": { "type": "boolean" },
        "children": {
          "type": "array",
          "items": { "$ref": "#/$defs/hierarchyNode" }
        }
      },
      "additionalProperties": false
    }
  }
}
```

## 3. `lookin.get_view_context_by_node_id`

## 3.1 输入（最终）

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["nodeId"],
  "properties": {
    "nodeId": { "type": "string", "minLength": 1 },
    "childrenDepth": { "type": "integer", "minimum": 0, "default": 1 }
  },
  "additionalProperties": false
}
```

## 3.2 输出（最终）

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["session", "targetNode"],
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
    "targetNode": { "type": "object" }
  },
  "additionalProperties": false
}
```

约束（最终）：

- `targetNode` 的内部结构必须与 v1 `lookin.get_selected_view_context` 的 `selectedNode` 完全同构。
- 对同一节点、同一 `childrenDepth`，`targetNode` 内容应与 `selectedNode` 一致（仅键名差异：`selectedNode -> targetNode`）。

## 4. `lookin.capture_view_screenshot_by_node_id`

## 4.1 输入（最终）

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["nodeId"],
  "properties": {
    "nodeId": { "type": "string", "minLength": 1 },
    "format": { "type": "string", "enum": ["png"], "default": "png" }
  },
  "additionalProperties": false
}
```

## 4.2 输出（最终）

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["path", "width", "height", "timestamp", "sessionId", "nodeId"],
  "properties": {
    "path": { "type": "string" },
    "width": { "type": "number" },
    "height": { "type": "number" },
    "timestamp": { "type": "integer" },
    "sessionId": { "type": "string" },
    "nodeId": { "type": "string" }
  },
  "additionalProperties": false
}
```

约束（最终）：

- 输出字段集合与 v1 `lookin.capture_selected_view_screenshot` 完全一致。
