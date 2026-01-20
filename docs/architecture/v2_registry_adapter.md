# MCP Switch V2 架构演进：注册表与适配器模式

待确认中

**版本**: v2.0 (Draft)  
**状态**: 规划中 (Planned)

---

## 1. 核心理念

MCP Switch V2 的核心目标是将 **配置数据原子化**。此时，软件不再是一个简单的 JSON 编辑器，而是一个**智能配置中心 (Configuration Hub)**。

### 痛点回顾 (V1)
*   **重复劳动**: 同一个 Context7 服务，需要在 Windsurf 和 Claude 中分别配置两遍。
*   **维护困难**: API Key 变更时，需要修改多处方言配置。
*   **体验割裂**: 无法统一管理服务的 Log、Tag 等元数据。

### 解决方案 (V2)
引入 **Registry (资源注册表)** + **Adapter (方言适配器)** 模式。
*   **Write Once**: 在 Registry 中只定义一次服务的核心参数（Endpoint, Token）。
*   **Run Anywhere**: 通过 Adapter 自动为不同编辑器生成符合其规范的 JSON 片段。

---

## 2. 数据架构 (Data Schema)

全局配置文件 (`~/.mcp-switch/config.json`) 将升级为以下结构：

```json
{
  "version": "2.0",
  "registry": {
    // [Key]: 服务的唯一标识 ID
    "context7-remote": {
      "meta": {
        "name": "Context7 Cloud",
        "icon": "assets/icons/cloud.png",
        "description": "Context7 远程推理服务"
      },
      "mode": "sse", // 核心模式: sse | local
      "config": {
        // SSE 模式下的原子字段
        "endpoint": "https://api.context7.com/sse", 
        "headers": {
            "CONTEXT7_API_KEY": "sk-..." 
        }
      }
    },
    
    "figma-helper": {
      "meta": {
        "name": "Figma Helper",
        "icon": "assets/icons/figma.png"
      },
      "mode": "local",
      "config": {
        // Local 模式下的原子字段
        "command": "npx",
        "args": ["-y", "figma-mcp"],
        "env": { "FIGMA_TOKEN": "..." }
      }
    }
  },

  "profiles": {
    // 针对每个编辑器的开关状态
    "windsurf": { "active_ids": ["context7-remote", "figma-helper"] },
    "claude": { "active_ids": ["context7-remote"] },
    "cursor": { "active_ids": [] }
  }
}
```

---

## 3. 适配器逻辑 (Adapter Logic)

适配器层负责将 `registry` item 转换为特定编辑器的方言。

### 3.1 SSE 模式适配矩阵

| 字段 | Windsurf / Antigravity | Claude / VSCode | Gemini CLI |
| :--- | :--- | :--- | :--- |
| **URL 键名** | `serverUrl` | `url` | `httpUrl` |
| **Type 标记** | (不需要) | `"type": "http"` | (不需要) |
| **Headers** | 直接透传 | 直接透传 | 强制追加 `Accept: text/event-stream` |

### 3.2 伪代码实现

```dart
// 只有在用户点击“应用”时才执行此逻辑
Map<String, dynamic> generateConfig(String editor, RegistryItem item) {
  if (item.mode == 'sse') {
    switch (editor) {
      case 'windsurf':
        return {
          "serverUrl": item.config.endpoint,
          "headers": item.config.headers
        };
      case 'claude':
        return {
          "type": "http",
          "url": item.config.endpoint,
          "headers": item.config.headers
        };
      case 'gemini':
         var headers = item.config.headers;
         headers['Accept'] = 'text/event-stream';
         return {
           "httpUrl": item.config.endpoint,
           "headers": headers
         };
    }
  }
  // Local 模式通常较统一，直接返回 command/args/env 即可
}
```

---

## 4. 迁移策略 (Migration)

从 V1 过渡到 V2 将是一个渐进过程：

1.  **Backup**: 首次启动 V2 版本时，自动从 `~` 目录备份所有编辑器的原始配置文件。
2.  **Ingest**: 尝试读取 Windsurf/Claude 的现存配置，通过正则或启发式规则，**反向生成** Registry 条目。
    *   *识别到 `serverUrl` -> 提取为 SSE Item*
    *   *识别到 `command: npx` -> 提取为 Local Item*
3.  **Takeover**: 生成 `config.json` 并接管后续的写入权限。

---

## 5. UI 变更

*   **主页**: 展示 Registry 卡片列表，而非直接展示 JSON 代码。
*   **详情页**: 提供表单式编辑（输入 Endpoint, Token），而非 JSON 编辑器。
*   **高级模式**: 仍保留“查看生成的 JSON”功能，供调试使用。
