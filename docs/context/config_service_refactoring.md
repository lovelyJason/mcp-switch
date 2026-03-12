# ConfigService 拆分重构

## 概述

将原本 **1409 行**的单文件 `lib/services/config_service.dart` 拆分为 4 个聚合在 `lib/services/config/` 目录下的文件，主文件降至 **280 行**，符合 `CLAUDE.md` 中 Service 文件 250 行的指导上限。

## 目录结构

```
lib/services/config/
├── config_service.dart           # 主文件 (280 行) - 核心 Profile 管理
├── config_service_settings.dart  # part 文件 (497 行) - _SettingsMixin
├── config_service_sync.dart      # part 文件 (357 行) - _SyncMixin
└── codex_config_helper.dart      # 独立静态工具类 (290 行)
```

## 拆分方案

### 技术选型：`part/part of` + Mixin

Dart 不允许将一个 class 的定义拆分到多个文件中。评估了三种方案：

| 方案 | 优势 | 劣势 |
|------|------|------|
| **Extension 方式** | 语法简洁 | 类内部无法直接调用 extension 方法 |
| **Composition / 委托** | 完全解耦 | 需要大量转发方法，改变外部 API |
| **Mixin + part** ✅ | 零外部改动，mixin 字段合并到类 | mixin 访问类字段需 cast `this as ConfigService` |

最终选择 **Mixin + part** 方案：两个 private mixin (`_SettingsMixin`, `_SyncMixin`) 通过 `part` 文件定义，`ConfigService` 使用 `with` 混入。外部调用方完全无感知。

### 各文件职责

#### 1. `config_service.dart` (主文件, 280 行)

ConfigService 类定义，混入 `_SettingsMixin` 和 `_SyncMixin`。

| 模块 | 内容 |
|------|------|
| 核心字段 | `_profiles`, `_activeProfileIds`, `_selectedEditor`, `_editorConfigPaths` |
| 初始化 | `init()`, `_loadCoreState()` |
| Profile CRUD | `saveProfile()`, `deleteProfile()`, `activateProfile()` |
| 编辑器 | `setEditor()`, `setConfigPath()`, `getConfigPath()` |
| MCP 开关 | `toggleServerStatus()` |
| Codex Auth | `_enrichCodexAuthStatus()`, `refreshCodexAuthStatus()` |
| 静态常量 | `availableModels` |

#### 2. `config_service_settings.dart` (part 文件, 497 行)

`mixin _SettingsMixin on ChangeNotifier` — 包含所有用户偏好设置。

| 模块 | 内容 |
|------|------|
| 主题/通用 | theme, tray, startup, log level, windows shell |
| API Keys | DeepL, Claude API Key/Base URL/Model |
| AI 助手 | chatbot icon, terminal AI model, chat AI model |
| Remote Claw | telegram/dingtalk 字段 + `saveRemoteClawConfig()` 等 |
| Proxy | proxy URL/auth + `saveProxyConfig()`, `clearProxyConfig()` |
| 加载 | `_loadAppSettings()`, `_initStartup()`, `refreshSettingsForSettingsScreen()` |
| 检测 helper | `_detectClaudePluginIntegrationFromConfig()`, `_detectClaudeOnboardingFromConfig()`, `_setClaudeOnboardingInConfig()` |

#### 3. `config_service_sync.dart` (part 文件, 357 行)

`mixin _SyncMixin on ChangeNotifier` — 配置文件的加载与同步写回。

| 模块 | 内容 |
|------|------|
| 加载 | `_loadProfiles()` — 从 SharedPreferences 缓存 + 配置文件双源同步 |
| 解析 | `_parseClaudeConfig()` — Claude Code 的 Global + Projects 结构 |
|  | `_parseStandardConfig()` — Cursor/Windsurf/Gemini 标准 JSON |
| 持久化 | `_persistProfiles()` — 写入 SharedPreferences |
| 同步写回 | `_syncCombinedConfig()` → `_syncClaudeConfig()` / `_syncCodexConfig()` / `_syncStandardConfig()` |
| 文件写入 | `_writeToEditorConfig()` |

通过 `ConfigService get _self => this as ConfigService;` 访问主类的 `_profiles` 等私有字段（同一 library 内合法）。

#### 4. `codex_config_helper.dart` (独立类, 290 行)

纯静态工具类 `CodexConfigHelper`，**不依赖 ConfigService 实例**。

| 方法 | 作用 |
|------|------|
| `parseToml()` | 解析 `~/.codex/config.toml` 为 `List<McpProfile>` |
| `generateToml()` | 将 `List<McpProfile>` 生成 TOML 字符串 |
| `parseAuthFromCli()` | 解析 `codex mcp list` 输出，提取 name → auth 映射 |
| `detectColumnStarts()` | CLI 表格列起始位置检测 |
| `splitByColumns()` | 按列位置拆分行数据 |
| `parseInlineTable()` | 解析 TOML 内联表 `{ "k" = "v" }` |
| `stringMapFrom()` | `dynamic` → `Map<String, String>` 安全转换 |
| `escapeTomlString()` | TOML 字符串转义 |

## Mixin 访问模式

```
┌─────────────────────────────────────────────────┐
│           ConfigService (主文件)                  │
│  ┌───────────────────────────────────────┐      │
│  │ _profiles, _activeProfileIds, ...     │      │
│  │ init(), saveProfile(), setEditor()    │      │
│  └───────────────────────────────────────┘      │
│                   with                           │
│  ┌──────────────────┐  ┌────────────────────┐   │
│  │  _SettingsMixin   │  │   _SyncMixin       │   │
│  │                   │  │                    │   │
│  │ _minimizeToTray   │  │ _self._profiles    │   │
│  │ setThemeMode()    │  │ _loadProfiles()    │   │
│  │ saveProxyConfig() │  │ _syncCombinedConfig│   │
│  └──────────────────┘  └────────────────────┘   │
│                                                   │
│  CodexConfigHelper (独立 static)                  │
│  ┌───────────────────────────────────────┐      │
│  │ parseToml(), generateToml()           │      │
│  │ parseAuthFromCli()                    │      │
│  └───────────────────────────────────────┘      │
└─────────────────────────────────────────────────┘
```

- **ConfigService → Mixin**：直接访问 mixin 字段（混入后成为类成员）
- **Mixin → ConfigService**：通过 `this as ConfigService` 获取主类私有字段（同一 library）
- **ConfigService → CodexConfigHelper**：静态方法调用，无实例依赖

## 外部影响

- **外部调用方**：`import` 路径从 `services/config_service.dart` 改为 `services/config/config_service.dart`，API 完全不变
- **涉及的 import 更新**：21 个文件（UI 组件、页面、服务、测试）

## 单元测试

| 测试文件 | 测试数 | 覆盖 |
|---------|--------|------|
| `test/services/codex_config_helper_test.dart` | 20 | TOML 解析/生成、CLI 解析、工具方法 |
| `test/services/config_service_test.dart` | 2 | Codex 远程 MCP 写入/读取集成测试 |
| `test/services/adapter_service_test.dart` | 4 | Adapter 服务（无改动，回归验证） |

全部 **26/26 通过**，`flutter analyze` 零 error，`flutter build macos` 构建成功。
