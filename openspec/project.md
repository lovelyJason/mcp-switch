# 项目：MCP Switch

## 概述

MCP Switch 是一个专为 macOS 设计的 Flutter 应用，帮助开发者高效管理多个 AI 代码编辑器的 **MCP (Model Context Protocol)** 配置文件。

在不同的 AI 辅助开发工具（Cursor、Windsurf、Claude Code 等）之间切换时，管理分散且格式各异的 MCP 配置往往令人头疼。MCP Switch 提供了一个统一、现代化的界面，让你能够集中管理这些配置，并只需一键即可应用到指定的编辑器中。

## 技术栈

- **框架**: Flutter 3.x (仅支持 macOS)
- **语言**: Dart (SDK ^3.10.1)
- **状态管理**: Provider
- **存储**: SharedPreferences / JSON 文件系统
- **窗口管理**: window_manager (自定义无边框窗口 + 可拖拽标题栏)
- **系统集成**: tray_manager (菜单栏托盘), launch_at_startup (开机自启)

### 核心依赖

| 包名 | 用途 |
|------|------|
| `provider` | 状态管理 |
| `window_manager` | 自定义窗口管理 |
| `shared_preferences` | 本地设置持久化 |
| `tray_manager` | macOS 菜单栏托盘 |
| `launch_at_startup` | 开机自启配置 |
| `flutter_markdown` | Markdown 渲染 (用于提示词) |
| `xterm` + `flutter_pty` | 终端模拟 |
| `json_annotation` + `json_serializable` | Model 的 JSON 序列化 |

## 项目结构

```
lib/
├── main.dart               # 应用入口
├── constants/
│   └── version.dart        # 自动生成的版本常量
├── l10n/
│   ├── s.dart              # 国际化代理
│   └── locales/            # 翻译 JSON 文件 (en, zh)
├── models/
│   ├── editor_type.dart    # 支持的编辑器定义
│   ├── mcp_profile.dart    # MCP 配置 Profile 模型
│   ├── mcp_profile.g.dart  # 生成的序列化代码
│   └── claude_prompt.dart  # Claude 提示词/规则模型
├── providers/              # (预留给 Provider notifiers)
├── services/
│   ├── config_service.dart  # MCP 配置读写操作
│   ├── prompt_service.dart  # Claude 提示词/规则管理
│   ├── terminal_service.dart# PTY 终端处理
│   ├── logger_service.dart  # 应用日志
│   └── logger/
│       └── file_output.dart # 文件日志输出
├── ui/
│   ├── main_window.dart          # 主窗口布局
│   ├── config_list_screen.dart   # MCP 配置列表
│   ├── project_detail_screen.dart# 项目 MCP 详情
│   ├── mcp_server_edit_screen.dart# MCP Server 编辑器
│   ├── settings_screen.dart      # 应用设置
│   ├── claude_prompts_screen.dart# Claude 提示词列表
│   ├── claude_prompt_edit_screen.dart# 提示词编辑器
│   ├── rules_screen.dart         # 编辑器规则列表
│   ├── rule_edit_screen.dart     # 规则编辑器
│   ├── components/               # 可复用 UI 组件
│   │   ├── add_profile_dialog.dart
│   │   ├── custom_dialog.dart
│   │   ├── custom_toast.dart
│   │   ├── styled_popup_menu.dart
│   │   ├── project_card.dart
│   │   ├── profile_card.dart
│   │   ├── editor_selector.dart
│   │   └── claude_terminal.dart
│   └── widgets/
│       └── fresh_markdown_editor.dart
└── utils/
    └── app_theme.dart        # 主题定义 (浅色/深色)
```

## 支持的编辑器

| 编辑器 | 配置格式 | 配置路径 |
|--------|----------|----------|
| Cursor | JSON | `~/.cursor/mcp.json` |
| Windsurf | JSON | `~/.codeium/windsurf/mcp_config.json` |
| Claude Code | JSON | `~/.claude.json` (全局) |
| Codex | TOML | `~/.codex/config.toml` |
| Antigravity | JSON | `~/.antigravity/mcp.json` |
| Gemini | JSON | `~/.gemini/mcp.json` |

## 核心功能

1. **多编辑器支持**: 一个界面管理 6+ AI 编辑器的 MCP 配置
2. **可视化配置编辑**: 表单模式 + JSON/TOML 代码模式双向绑定
3. **自定义路径管理**: 配置可指向 Dropbox/iCloud 实现跨设备同步
4. **Claude Code 集成**: 管理 `CLAUDE.md` 系统提示词和全局规则
5. **MCP Server 预设**: 一键添加常用 Server (Figma, Chrome DevTools, Context7)
6. **原生 macOS 体验**: 无边框窗口、深色模式、菜单栏托盘、开机自启

## 代码规范

### 代码风格

- 使用 Dart analysis + `flutter_lints`
- Model 使用 `json_serializable` 进行 JSON 编解码
- UI 遵循一致的组件拆分 (screens → components → widgets)
- Service 层处理 I/O 和业务逻辑，UI 只负责展示

### 命名规范

- 文件名: `snake_case.dart`
- 类名: `PascalCase`
- 变量/函数: `camelCase`
- 私有成员: `_prefixed`

### 状态管理

- 使用 `Provider` + `ChangeNotifier` 实现响应式状态
- Service 是单例或通过 Provider 实例化
- 避免在 UI Widget 中直接进行文件 I/O

### 国际化

- 所有用户可见字符串放在 `lib/l10n/locales/{lang}.json`
- 通过 `S.of(context).keyName` 访问
- 支持语言: 英文 (en)、中文 (zh)

## 版本管理

- 版本定义在 `pubspec.yaml` (如 `1.0.1+2`)
- 通过 `scripts/bump_version.py` 自动生成 `lib/constants/version.dart`
- 发布流程: 版本递增 → 构建 → 打 Tag → GitHub Release

## 开发命令

```bash
# Debug 模式运行
flutter run -d macos

# Release 构建
flutter build macos --release

# 重新生成 JSON 序列化代码
flutter pub run build_runner build --delete-conflicting-outputs

# 更新应用图标
python3 scripts/update_icon.py <图片路径>

# 版本递增 (自动检测 GitHub 最新 Release)
python3 scripts/bump_version.py
```

## 测试策略

- Service 层单元测试 (config_service, prompt_service)
- 关键 UI 组件的 Widget 测试
- macOS 特定功能手动测试 (托盘、窗口管理)

## 未来规划

详见 [README.md](../README.md#-路线图-roadmap):
- 多配置方案切换 (Profiles)
- 云同步 (iCloud/GitHub Gist)
- MCP Server 市场
- AI 驱动的规则生成器
- 本地 RAG 知识库索引
