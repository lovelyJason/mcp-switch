# 会话管理（Session Manager）功能设计文档

## 概述

会话管理是 MCP Switch 的本地会话记录可视化管理功能，对 Claude Code 和 Codex 的本地会话进行扫描、展示和管理，支持搜索、过滤、查看对话详情、复制恢复命令和删除会话。

参考项目：[cc-switch](https://github.com/user/cc-switch) 的会话管理模块，UI 按 MCP Switch 风格重新实现。

---

## 数据源

### Claude Code 会话

- **路径**：`~/.claude/projects/**/*.jsonl`
- **格式**：每行一个 JSON 对象（JSONL）
- **元数据行**：`{ "sessionId": "xxx", "cwd": "/path", "timestamp": "2026-03-01T10:00:00Z", "isMeta": true }`
- **消息行**：`{ "message": { "role": "user|assistant", "content": "..." }, "timestamp": "..." }`
- **恢复命令**：`claude --resume <sessionId>`
- **排除规则**：跳过 `agent-` 开头的文件（子代理会话）

### Codex 会话

- **路径**：`~/.codex/sessions/**/*.jsonl`
- **格式**：JSONL，结构不同于 Claude
- **元数据行**：`{ "type": "session_meta", "payload": { "id": "uuid", "cwd": "/path" }, "timestamp": "..." }`
- **消息行**：`{ "type": "response_item", "payload": { "type": "message", "role": "user", "content": [...] }, "timestamp": "..." }`
- **恢复命令**：`codex resume <sessionId>`
- **Session ID 推断**：从文件名中提取 UUID 格式的 ID

### Content 提取规则

`message.content` 可能是以下三种格式之一：

| 类型 | 示例 | 提取方式 |
|------|------|---------|
| String | `"hello"` | 直接使用 |
| Array | `[{"text": "hello"}, {"input_text": "..."}]` | 遍历提取 `text`/`input_text`/`output_text` 字段 |
| Object | `{"text": "hello"}` | 取 `text` 字段 |

---

## 数据模型

### SessionMeta

```dart
class SessionMeta {
  final String providerId;    // "claude" | "codex"
  final String sessionId;
  final String? title;        // 从 projectDir 提取最后一段
  final String? summary;      // 最后一条消息截断到 160 字符
  final String? projectDir;   // 会话工作目录
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final String? sourcePath;   // JSONL 文件完整路径
  final String? resumeCommand;
}
```

### SessionMessage

```dart
class SessionMessage {
  final String role;      // "user" | "assistant" | "tool" | "system"
  final String content;
  final DateTime? timestamp;
}
```

---

## 架构设计

### 文件结构

```
lib/
├── models/
│   └── session_meta.dart           # 数据模型
├── services/
│   └── session_service.dart        # 扫描/解析/加载/删除
└── ui/pages/sessions/
    ├── session_manager_screen.dart  # 主页面（状态管理）
    └── widgets/
        ├── session_list_panel.dart  # 左侧列表面板
        └── session_detail_panel.dart # 右侧详情面板
```

### 层级职责

| 层 | 文件 | 职责 |
|----|------|------|
| **Model** | `session_meta.dart` | 纯数据结构，不含业务逻辑 |
| **Service** | `session_service.dart` | 文件 I/O、JSONL 解析、会话扫描/删除 |
| **Screen** | `session_manager_screen.dart` | 状态管理、事件分发、搜索过滤逻辑 |
| **Widget** | `session_list_panel.dart` | 列表渲染、搜索栏、Provider 过滤 |
| **Widget** | `session_detail_panel.dart` | 详情头部、恢复命令、消息列表 |

---

## UI 设计

### 布局

```
┌──────────────────────────────────────────────────┐
│  ← 返回   会话管理                    (AppBar)    │
├────────────────┬─────────────────────────────────┤
│ 会话列表  217  │  🤖 pr-guardian                  │
│ 🔍 ⚙ 🔄      │  ⏰ 2026/3/11 11:40  📁 project │
│                │  ┌─────────────────────────────┐ │
│ 🤖 pr-guardian │  │ claude --resume 2bdfe... 📋 │ │
│   ⏰ 2 小时前  │  └─────────────────────────────┘ │
│                │                                   │
│ 🤖 mcp-switch │  💬 对话记录  42                   │
│   ⏰ 16 小时前 │  ┌─────────────────────────────┐ │
│                │  │ User           14:30         │ │
│ 💻 94ff4c9b   │  │ 帮我实现这个功能...            │ │
│   ⏰ 16 小时前 │  └─────────────────────────────┘ │
│                │  ┌─────────────────────────────┐ │
│                │  │ Assistant       14:31        │ │
│                │  │ 好的，让我来分析...            │ │
│                │  └─────────────────────────────┘ │
└────────────────┴─────────────────────────────────┘
```

### 左侧列表面板

- **头部**：标题 + 会话数 badge + 搜索/过滤/刷新按钮
- **搜索栏**：点击搜索图标展开，ESC/X 收起，跨 title/summary/projectDir/sessionId 匹配
- **Provider 过滤**：PopupMenuButton，支持 All / Claude Code / Codex
- **列表项**：Provider 图标 + 标题 + 箭头 + 相对时间，选中态橙色高亮
- **空态**：图标 + "未找到会话记录" 文字

### 右侧详情面板

- **未选中态**：居中图标 + "选择一个会话查看详情"
- **详情头部**：Provider 图标 + 标题 + 恢复按钮（橙色 FilledButton）+ 删除按钮（红色 OutlinedButton）
- **元信息行**：时间 / 项目目录（可复制）/ Provider 标签
- **恢复命令条**：monospace 字体 + 复制按钮，灰色背景圆角容器
- **消息列表**：
  - User 消息：橙色调背景，左侧 32px 缩进
  - Assistant 消息：蓝色调背景，右侧 32px 缩进
  - Tool/System 消息：灰色背景，无缩进
  - Hover 时显示复制按钮
  - 内容可选中复制（SelectableText）

### 主题适配

- 所有颜色使用 `withValues(alpha:)` 确保深浅色模式均可用
- 恢复命令条背景根据 `isDark` 切换 `grey.shade800` / `grey.shade100`
- 主操作按钮使用 `Colors.orange`（项目主题色）

---

## 导航入口

| 编辑器 | 入口位置 | 交互方式 |
|--------|---------|---------|
| Claude | More 下拉菜单 → "会话管理" | PopupMenuItem |
| Codex | 胶囊按钮组 → 时钟图标 | IconButton |

---

## 会话解析策略

### 性能优化：头尾行读取

参考 cc-switch 的 `read_head_tail_lines` 策略：
- 只读取文件前 10 行（提取元数据：sessionId、cwd、createdAt）
- 只读取文件后 30 行（提取 lastActiveAt、summary）
- 完整消息列表仅在用户点击查看详情时才加载

### 容错处理

- 单个文件解析失败不影响其他会话
- JSON 解析失败的行直接跳过
- 空内容消息被过滤
- 缺少 sessionId 时从文件名推断

### 排序规则

所有会话按 `lastActiveAt`（优先）或 `createdAt` 降序排列，最近活跃的在最前。

---

## 国际化 Key 清单

| Key | 中文 | 英文 |
|-----|------|------|
| `session_manager` | 会话管理 | Sessions |
| `session_list` | 会话列表 | Session List |
| `session_search_hint` | 搜索会话... | Search sessions... |
| `session_filter_all` | 全部 | All |
| `session_no_sessions` | 未找到会话记录 | No sessions found |
| `session_select_hint` | 选择一个会话查看详情 | Select a session to view details |
| `session_no_messages` | 无消息记录 | No messages |
| `session_conversation_history` | 对话记录 | Conversation History |
| `session_resume` | 恢复会话 | Resume |
| `session_delete` | 删除会话 | Delete |
| `session_copy_command` | 复制命令 | Copy Command |
| `session_resume_copied` | 恢复命令已复制到剪贴板 | Resume command copied to clipboard |
| `session_delete_title` | 删除会话 | Delete Session |
| `session_delete_confirm` | 确定要永久删除会话 "{title}" 吗？ | Permanently delete session "{title}"? |
| `session_deleted` | 会话已删除 | Session deleted |
| `session_delete_failed` | 删除会话失败 | Failed to delete session |
| `session_time_just_now` | 刚刚 | just now |
| `session_time_minutes_ago` | 分钟前 | min ago |
| `session_time_hours_ago` | 小时前 | hours ago |
| `session_time_days_ago` | 天前 | days ago |

---

## 后续迭代方向

### v2 可能的增强

- **终端恢复**：macOS 通过 AppleScript 直接在 Terminal/iTerm2 中打开会话（而非仅复制命令）
- **全文搜索**：对消息内容建立倒排索引，支持跨会话关键词搜索
- **虚拟列表**：对超长消息列表使用 `ListView.builder` + 懒加载分页
- **文件监听**：监听会话目录变化自动刷新列表
- **Gemini CLI 支持**：扫描 `~/.gemini/` 下的会话文件
- **会话标签/收藏**：本地标记重要会话
- **导出 Markdown**：将对话记录导出为可读的 Markdown 文件

---

## 踩坑记录

### 1. Claude JSONL 格式的 content 多态

Claude 的 `message.content` 不一定是 String，可能是 Array（每个元素含 `text`/`input_text`）或 Object（含 `text` 字段）。必须用统一的 `_extractText()` 方法处理所有情况。

### 2. Codex 的不同数据结构

Codex 的 JSONL 使用 `type` + `payload` 的包装结构，而非 Claude 的扁平 `message` 字段。需要分别实现两套解析逻辑。

### 3. agent- 前缀文件

Claude 的 `~/.claude/projects/` 下会有 `agent-xxx.jsonl` 子代理文件，这些不是主会话，扫描时需要跳过。

### 4. Session ID 推断

部分会话文件的 JSONL 中可能没有 `sessionId` 字段（旧版本格式），此时从文件名推断：
- Claude：使用文件名（去掉 .jsonl）
- Codex：从文件名中用正则提取 UUID
