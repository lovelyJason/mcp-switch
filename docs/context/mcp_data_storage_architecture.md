# MCP Switch 数据存储架构

## 概述

MCP Switch 使用 **SharedPreferences** 作为本地数据持久化方案，存储 MCP 配置的元数据和应用状态。

## 存储位置

| 平台 | 路径 |
|------|------|
| macOS | `~/Library/Preferences/com.example.mcp_switch.plist` |
| Windows | `%APPDATA%\com.example\mcp_switch\shared_preferences.json` |
| Linux | `~/.local/share/mcp_switch/shared_preferences.json` |

## 核心数据结构

### 1. MCP Profiles (`mcp_profiles`)

存储所有编辑器的 MCP 配置列表。

**Key**: `mcp_profiles`

**数据结构**:
```json
{
  "cursor": [
    {
      "id": "uuid-xxx",
      "name": "figma-mcp",
      "description": "Configured via MCP Switch",
      "content": {
        "mcpServers": {
          "figma-mcp": {
            "command": "npx",
            "args": ["-y", "figma-developer-mcp"]
          }
        }
      }
    }
  ],
  "claude": [...],
  "windsurf": [...],
  "codex": [...],
  "antigravity": [...],
  "gemini": [...]
}
```

**字段说明**:
| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | UUID，MCP Switch 内部唯一标识 |
| `name` | String | MCP 服务器名称（对应配置文件中的 key） |
| `description` | String | 来源标识：`Configured via MCP Switch` 或 `Imported from config` |
| `content` | Map | 完整的 MCP 配置内容 |

### 2. 其他 SharedPreferences Keys

| Key | 类型 | 说明 |
|-----|------|------|
| `claude_api_key` | String | Anthropic API Key（用于内置聊天机器人） |
| `show_chatbot_icon` | bool | 是否显示聊天机器人悬浮按钮 |
| `chatbot_position_x` | double | 聊天机器人位置 X |
| `chatbot_position_y` | double | 聊天机器人位置 Y |
| `locale` | String | 界面语言（zh/en） |
| `theme_mode` | String | 主题模式（light/dark/system） |
| `minimize_to_tray` | bool | 是否最小化到托盘 |
| `custom_config_path` | String | 自定义配置文件路径 |

## 数据流向

```
┌─────────────────────────────────────────────────────────────────────┐
│                        编辑器配置文件                                 │
│  ~/.claude.json, ~/.cursor/mcp.json, ~/.codeium/windsurf/...       │
└────────────────────────────┬────────────────────────────────────────┘
                             │ 读取 & 同步
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     ConfigService (内存)                             │
│  _profiles: Map<EditorType, List<McpProfile>>                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │ 持久化
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SharedPreferences                                 │
│  Key: "mcp_profiles" -> JSON String                                 │
└─────────────────────────────────────────────────────────────────────┘
```

## 同步机制

### 启动时同步 (`loadProfiles`)

1. 从 SharedPreferences 读取缓存的 `mcp_profiles`
2. 读取各编辑器的配置文件（JSON/TOML）
3. 对比合并：
   - 配置文件中存在但缓存中没有 → 标记为 `Imported from config`
   - 缓存中存在的 → 保留 description（保持来源标识）
4. 写回 SharedPreferences

### 保存时同步 (`saveProfile`)

1. 更新内存中的 `_profiles`
2. 写入 SharedPreferences
3. 写入对应编辑器的配置文件

## 核心代码位置

| 文件 | 说明 |
|------|------|
| `lib/services/config_service.dart` | 数据层核心，所有 CRUD 操作 |
| `lib/models/mcp_profile.dart` | McpProfile 数据模型 |
| `lib/models/editor_type.dart` | EditorType 枚举 |

## 未来扩展点

### 跨编辑器同步

利用 SharedPreferences 的集中存储特性，可以实现：

1. **一键同步到所有编辑器**
   - 从 `_profiles[sourceEditor]` 复制到其他编辑器
   - 处理不同编辑器的配置格式差异（JSON vs TOML）

2. **MCP 模板库**
   - 新增 `mcp_templates` Key 存储用户常用配置
   - 快速部署到任意编辑器

3. **配置版本历史**
   - 新增 `mcp_history` Key 存储变更记录
   - 支持回滚操作

### 数据结构扩展建议

```json
{
  "mcp_profiles": { ... },
  "mcp_templates": [
    {
      "id": "tpl-xxx",
      "name": "我的 Figma 配置",
      "config": { ... },
      "syncToEditors": ["cursor", "claude", "windsurf"]
    }
  ],
  "sync_settings": {
    "autoSync": true,
    "masterEditor": "claude",
    "syncOnStartup": true
  }
}
```

## 注意事项

1. **数据量限制**: SharedPreferences 适合存储小量配置数据，不适合存储大文件， 后续重构为home目录中json吧
2. **并发写入**: 多处同时写入可能导致数据覆盖，建议通过 ConfigService 单例统一管理
3. **敏感数据**: API Key 等敏感信息目前明文存储，生产环境建议使用 flutter_secure_storage
