# AI Chatbot 功能

## 概述

MCP Switch 内置的 AI 聊天助手，基于 Claude API，专门用于帮助用户管理插件、市场、技能和 MCP 配置。

## 功能特性

### 1. 设置页面 AI Tab
- **Claude API Key 配置**：密码遮蔽输入框
- **获取 API Key 链接**：跳转 Anthropic Console
- **悬浮图标开关**：控制是否显示全局悬浮图标
- **清空聊天历史**：一键清除所有对话记录

### 2. 全局悬浮图标
- 可拖拽，位置持久化（SharedPreferences）
- 未配置 API Key 时显示脉冲动画提示
- 右上角关闭按钮可隐藏图标
- 点击打开聊天面板

### 3. 侧边滑出聊天面板
- 从右侧滑出，带半透明遮罩
- 消息气泡 UI（用户蓝色，AI 紫色）
- 工具调用状态实时显示
- 支持清空对话、导出到剪贴板

### 4. AI Agent 能力（Tool Use）

| 工具名称 | 功能 |
|---------|------|
| `list_plugins` | 列出所有已安装插件 |
| `list_marketplaces` | 列出所有已添加的市场 |
| `list_skills` | 列出所有可用技能 |
| `get_plugin_info` | 获取指定插件的详细信息 |
| `add_marketplace` | 添加新的插件市场 |
| `install_plugin` | 从市场安装插件 |
| `uninstall_plugin` | 卸载已安装的插件 |
| `run_terminal_command` | 执行终端命令（仅限 claude 相关） |

### 5. 聊天历史持久化
- 存储路径：`~/.mcp-switch/chat_history.json`
- 自动加载历史记录
- 支持导出为文本格式

## 技术实现

### SDK
- `anthropic_sdk_dart: ^0.1.0`
- 支持 Tool Use（Function Calling）
- 使用 `claude-3-haiku-20240307` 模型

### 状态管理
- Provider + ChangeNotifier
- `AiChatService` 作为全局服务

### UI 组件
- `FloatingChatbotIcon`：悬浮图标
- `GlobalChatbotPanel`：聊天面板
- 参考现有 `FloatingTerminalIcon` 和 `GlobalTerminalPanel` 模式

## 文件结构

```
lib/
├── models/
│   └── chat_message.dart          # 聊天消息模型
├── services/
│   ├── ai_chat_service.dart       # AI 聊天核心服务
│   └── config_service.dart        # 添加 claudeApiKey, showChatbotIcon
├── ui/
│   ├── settings_screen.dart       # 添加 AI Tab
│   └── components/
│       ├── floating_chatbot_icon.dart
│       └── global_chatbot_panel.dart
└── main.dart                      # 注册 AiChatService Provider
```

## 使用方法

1. 打开 **设置 → AI** Tab
2. 输入 Claude API Key（从 https://console.anthropic.com 获取）
3. 点击界面上的 ✨ 悬浮图标
4. 开始对话，例如：
   - "列出所有已安装的插件"
   - "帮我添加 anthropics/claude-code-plugins 市场"
   - "安装 xxx 插件"

## System Prompt

```
你是 MCP Switch 的智能助手，专门帮助用户管理：
- Claude Code 插件（plugins）
- 插件市场（marketplaces）
- Skills 技能
- MCP 服务器配置

你可以：
1. 查询已安装的插件、市场、技能
2. 安装/卸载插件
3. 添加/移除插件市场
4. 配置 MCP 服务器
5. 执行终端命令

请用简洁友好的方式回答用户问题。如果需要执行操作，会调用相应的工具。
回答请使用中文，除非用户明确要求英文。
```

## 安全限制

- `run_terminal_command` 工具仅允许执行包含 `claude` 关键字的命令
- API Key 使用密码输入框，不明文显示
- 聊天历史仅存储在本地

## 国际化

支持中英文，相关 key 在 `lib/l10n/locales/` 下：
- `ai_settings`, `claude_api_key`, `chatbot`, `thinking` 等 20+ 个字符串
