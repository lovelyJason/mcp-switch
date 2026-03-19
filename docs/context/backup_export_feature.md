# 数据导出备份功能

## 概述

在设置面板 > 高级标签页底部提供"导出数据"和"导入数据"（暂未实现）按钮。导出功能将用户选择的数据分类打包为单个 `.mcpsw` 专属格式文件。

## 文件格式

### .mcpsw 专属二进制格式

在标准 ZIP 数据前插入 **6 字节自定义文件头**，使得文件改名为 `.zip` 后也无法被解压工具识别。

```
[4D 43 50 53 57 01] [标准 ZIP 数据...]
 ─── MCPSW + v1 ───  ── archive 包生成 ──
```

- 前 5 字节为魔数 `MCPSW`（ASCII）
- 第 6 字节为格式版本号 `0x01`
- 后续为标准 ZIP 压缩数据

### ZIP 内部结构

```
mcp_switch_backup_20260312_153000.mcpsw
├── manifest.json              # 元数据
├── preferences.json           # SharedPreferences 偏好设置
├── providers.json             # SQLite provider_profiles 导出
├── mcp_configs/               # 各编辑器 MCP 配置
│   ├── claude.json            # 仅 mcpServers 部分
│   ├── codex_config.toml
│   ├── cursor_mcp.json
│   ├── windsurf_mcp_config.json
│   ├── antigravity_mcp_config.json
│   ├── gemini_settings.json
│   └── kiro_mcp.json
├── prompts/
│   ├── CLAUDE.md
│   └── GEMINI.md
└── skills/
    ├── claude/...
    ├── codex/...
    └── antigravity/...
```

## 可导出的 5 个分类

| 分类 | BackupCategory 枚举 | 数据来源 | 备注 |
|------|---------------------|----------|------|
| 系统偏好设置 | `preferences` | SharedPreferences | 含 API Key、代理凭据等敏感数据 |
| MCP 列表配置 | `mcpConfigs` | 编辑器配置文件 | claude.json 仅提取 mcpServers |
| 全局提示词 | `prompts` | ~/.claude/CLAUDE.md, ~/.gemini/GEMINI.md | |
| Skills 目录 | `skills` | ~/.claude/skills/, ~/.codex/skills/, ~/.gemini/antigravity/skills/ | 递归复制 |
| 供应商列表 | `providers` | SQLite provider_profiles 表 | 序列化为 JSON 数组 |

## 代码结构

### 新建文件

| 文件 | 职责 |
|------|------|
| `lib/services/backup_service.dart` | 核心导出逻辑，BackupCategory 枚举，exportBackup() 方法 |
| `lib/ui/pages/settings/widgets/export_dialog.dart` | 导出弹窗，5 个分类复选框，敏感数据警告 |
| `lib/ui/pages/settings/widgets/backup_section.dart` | 设置页区块组件，导出/导入按钮 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `lib/ui/pages/settings/settings_screen.dart` | 高级标签页末尾添加 BackupSection |
| `lib/l10n/locales/zh.json` | 新增 18 个导出相关 i18n key |
| `lib/l10n/locales/en.json` | 同上 |

## 关键实现

### BackupService

```dart
class BackupService {
  static const List<int> _magic = [0x4D, 0x43, 0x50, 0x53, 0x57]; // "MCPSW"
  static const int _version = 0x01;

  Future<(bool, String?)> exportBackup(
    List<BackupCategory> categories,
    String outputPath,
  ) async {
    // 1. 按分类收集数据到 Archive
    // 2. ZipEncoder 生成 ZIP bytes
    // 3. 前拼 6 字节 header
    // 4. 写入 .mcpsw 文件
  }
}
```

### 偏好设置导出范围

导出以下 SharedPreferences key：

- 主题：`theme_mode`
- 窗口行为：`minimize_to_tray`, `launch_at_startup`, `enable_claude_plugin_integration`, `skip_claude_code_onboarding`, `log_level`
- AI 设置：`claude_api_key`, `claude_api_base_url`, `claude_model`, `show_chatbot_icon`, `terminal_ai_model_id`, `chat_ai_model_id`
- 高级：`deepl_api_key`, `proxy_url`, `proxy_username`, `proxy_password`
- 语言：通过 `S.localeNotifier.value.languageCode` 获取

### 容错机制

- 文件/目录不存在时静默跳过
- 跳过的项目记录在 `manifest.json` 的 `skipped` 数组中
- 导出失败通过 Toast 提示错误信息

## UI 交互流程

设置 > 高级 > 备份区块 → 点击导出 → 弹窗勾选分类 → FilePicker 选路径 → 生成 .mcpsw → Toast 成功
