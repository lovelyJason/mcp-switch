# Provider Switch（供应商配置切换）功能设计文档

## 概述

Provider Switch 是 MCP Switch 的供应商（API 代理/中转站）配置管理功能，支持为 Claude Code 和 Codex 两种 CLI 工具创建多套供应商配置方案，通过一键切换激活，自动写入对应的配置文件。

## 设计思想

### 核心理念

**"多方案保存 + 一键切换"** — 用户可以为同一个 CLI 工具保存多个供应商配置（如官方 API、第三方中转站），通过点击激活按钮切换，系统自动将配置写入目标配置文件。

### 为什么用 SQLite 而不是 SharedPreferences

1. **结构化数据**：供应商配置包含多个字段（API Token、Base URL、Model 等），天然适合关系型存储
2. **可扩展性**：未来可增加导入/导出功能、配置同步等
3. **与 MCP 配置解耦**：供应商配置独立于 MCP 配置，避免 SharedPreferences 存储过多数据
4. **参考实现**：项目 `~/projects/my/amber-list` 的 Drift ORM 封装模式

### 配置文件格式差异

| CLI 工具 | 配置文件路径 | 格式 | 管理的字段 |
|---------|------------|------|-----------|
| Claude Code | `~/.claude/settings.json` | JSON | `env.ANTHROPIC_AUTH_TOKEN`, `env.ANTHROPIC_BASE_URL`, `env.CLAUDE_CODE_MAX__OUTPUT_TOKENS`, `env.MAX_THINKING_TOKENS`, `model` |
| Codex | `~/.codex/config.toml` | TOML | `model`, `model_reasoning_effort`, `personality`, `model_provider`, `[model_providers.custom]` |
| Codex | `~/.codex/auth.json` | JSON | `OPENAI_API_KEY`（API 密钥，独立于 config.toml） |

### 写入策略：保留合并

配置文件中可能包含其他非供应商字段（如 Claude 的 `permissions`、`env` 中的其他变量），写入时必须：

1. 读取现有配置文件内容
2. 仅修改供应商相关字段
3. 保留其他所有字段不变
4. 写回文件

**Claude Code** 的 JSON 是结构化的，直接操作 Map 对象即可。
**Codex** 的 TOML 由于没有 Dart 原生 TOML 库支持写入，采用基于 section 感知的 upsert/remove 策略（`_mergeCodexConfig`），支持顶级键值对和 `[model_providers.custom]` section 的安全合并。

**Codex auth.json** 独立于 config.toml，存储 API 密钥。格式为 `{"OPENAI_API_KEY": "sk-xxx"}`。激活时同步写入，取消激活时清理 `OPENAI_API_KEY` 键（保留其他字段如 OAuth token）。

## 架构设计

### 数据层（Drift ORM）

```
lib/data/database.dart
├── ProviderProfiles 表定义
├── AppDatabase 单例（WAL 模式，schemaVersion = 2）
├── Migration（v1→v2: 新增 website 列）
├── CRUD 方法
└── database.g.dart（代码生成）
```

**表结构**：

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT (PK) | UUID |
| editorType | TEXT | `claude` 或 `codex` |
| name | TEXT | 配置名称 |
| description | TEXT? | 描述 |
| isActive | BOOLEAN | 是否激活（同一 editorType 下只能有一个激活） |
| apiToken | TEXT? | API 密钥 |
| baseUrl | TEXT? | API 代理地址 |
| model | TEXT? | 模型名称 |
| maxOutputTokens | TEXT? | 最大输出 Token（仅 Claude） |
| maxThinkingTokens | TEXT? | 最大思考 Token（仅 Claude） |
| website | TEXT? | 供应商官网链接（v2 新增） |
| modelReasoningEffort | TEXT? | 推理力度（仅 Codex） |
| personality | TEXT? | 人格设定（仅 Codex） |
| createdAt | DATETIME | 创建时间 |
| updatedAt | DATETIME | 更新时间 |

**激活逻辑**：使用事务，先 `deactivateAll(editorType)` 再激活目标，保证同类型只有一个激活。

### 服务层

```
lib/services/provider_switch_service.dart
├── 内存缓存（_claudeProfiles, _codexProfiles）
├── 官方配置同步（_syncClaudeOfficial, _syncCodexOfficial）
├── 配置文件↔DB 激活状态校正（_reconcileActiveFromConfig）
├── 手动刷新（refreshFromConfig）
├── CRUD 操作（委托给 Database）
├── 激活/取消（toggleActive）
├── 配置文件写入（_writeClaudeSettings, _writeCodexConfig, _writeCodexAuth）
├── 配置文件清理（_clearClaudeSettings, _clearCodexConfig）
├── Codex TOML 合并引擎（_mergeCodexConfig, _upsertTopLevelKey, _upsertCustomProviderSection 等）
├── Codex 模型动态拉取（codex app-server model/list）
├── Codex 模型缓存（内存 + ~/.mcp-switch/cache/codex_models.json）
├── 配置预览生成（generateCodexPreview, generateCodexAuthPreview）
├── 配置文件读取（readClaudeConfigFile, readCodexConfigFile, readCodexAuthFile）
└── 静态模型列表（claudeModels, codexModels）
```

### UI 层

```
lib/ui/pages/provider_switch/
├── provider_list_screen.dart    # 列表页（Claude/Codex 切换 + 刷新按钮）
└── provider_edit_screen.dart    # 编辑/新增页（动态表单 + 预设填充 + 配置预览）
```

**入口点**：`lib/ui/pages/home/header_action_buttons.dart` 胶囊按钮组

- Claude: `Skills | Prompt | Provider | More`
- Codex: `Skills | Provider`

## 关键流程

### 启动同步流程

```
init()
  → _loadProfiles()          // 加载内存缓存
  → _seedOfficialProfiles()
    → _syncClaudeOfficial()   // 读 settings.json，upsert 官方配置
    → _syncCodexOfficial()    // 读 config.toml + auth.json，upsert 官方配置（含 apiToken）
    → _reconcileActiveFromConfig('claude')  // 以配置文件为准校正激活
    → _reconcileActiveFromConfig('codex')
    → _loadProfiles()         // 刷新缓存
  → notifyListeners()
```

**同步规则**：
- 官方配置（id 前缀 `official-`）只在首次创建时设为 active
- 后续启动只更新字段，不动 isActive
- `_reconcileActiveFromConfig` 根据配置文件实际内容匹配 DB 中的 profile 并激活

### 配置文件↔DB 校正逻辑（_reconcileActiveFromConfig）

**Claude Code**：
```
读取 settings.json → 提取 ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN
```

**Codex**：
```
读取 config.toml → 提取 model_provider 值
  → 若 model_provider = "custom" → 从 [model_providers.custom] 提取 base_url
  → 否则 baseUrl = null（官方配置）
读取 auth.json → 提取 OPENAI_API_KEY 作为 apiToken
```

**通用匹配逻辑**（Claude 和 Codex 共用）：
```
  → 精确匹配（baseUrl + apiToken 都一致）
  → 模糊匹配（仅 baseUrl 一致）
  → 兜底匹配（baseUrl 为空时匹配官方 profile）
  → 激活匹配到的 profile，取消其余
  → 若无匹配：保证不出现多个 active（保留最新的）
```

**Source of Truth = 配置文件**。如果用户手动修改了配置文件（settings.json / config.toml），启动时或点击刷新按钮后，DB 会自动校正。

### 激活流程

```
用户点击"切换使用" → toggleActive(id, editorType, true)
  → DB: deactivateAll(editorType)
  → DB: activateProfile(editorType, id)
  → 刷新内存缓存
  → 从缓存获取 profile
  → 写入配置文件
    → Claude: _writeClaudeSettings() → settings.json
    → Codex: _writeCodexConfig() → config.toml + _writeCodexAuth() → auth.json
  → (写入失败) → DB 回滚激活状态 + rethrow
  → notifyListeners()
```

### 手动刷新流程

```
用户点击刷新按钮 → refreshFromConfig()
  → _seedOfficialProfiles()  // 完整的同步+校正流程
  → notifyListeners()
  → Toast 提示"配置已刷新"
```

### Codex 模型列表获取流程

```
打开 Codex 供应商编辑页
  → 先用静态列表立即渲染下拉（保证首屏可用）
  → 后台调用 getCodexModels()
    → 命中内存缓存（6h）则直接返回
    → 否则尝试读取磁盘缓存 ~/.mcp-switch/cache/codex_models.json
    → 若缓存无效/过期，启动 codex app-server 子进程
      → initialize → initialized → model/list
      → 解析 result.data[].model
      → 更新内存 + 写入磁盘缓存
      → 立即关闭 stdin 并终止子进程
    → 若动态拉取失败，回退到磁盘缓存，再不行回退静态列表
  → UI 刷新下拉项；保留当前已选 model（即使不在新列表）
```

## UI 交互设计

### 列表页卡片交互

- **激活状态的卡片**：左侧 4px 橙色竖条 + 橙色边框 + "使用中" 徽章（橙色底色标签）
- **非激活卡片**：鼠标悬停时显示"切换使用"按钮（橙色 TextButton.icon + 电源图标）
- **悬停操作**：编辑按钮（圆形）+ 删除按钮（红色）
- **卡片点击**：跳转编辑页

### Header 操作区

```
[← 返回] [供应商切换 ▼EditorSwitcher] ————spacer———— [🔄 刷新] [+ 添加]
```

- **刷新按钮**：带边框的方形按钮，位于加号按钮左边，点击调用 `refreshFromConfig()` 并弹 Toast
- **添加按钮**：橙色背景，白色 + 号

### 编辑页字段

#### API Token 字段
- 右侧眼睛图标切换密文/明文显示
- `obscureText` 状态由 `_obscureToken` 控制

#### Base URL 字段
- 非官方配置：下方显示琥珀色提示条 —— "填写兼容 Anthropic API 的服务端点地址，不要以斜杠结尾"
- 提示条样式：圆角 6px，琥珀色半透明背景，左侧灯泡图标

#### 官网链接字段
- **官方配置**：显示为可点击的链接样式（橙色文字 + 外链图标），点击打开浏览器
- **非官方配置**：显示为可编辑的 TextFormField

#### 配置预览区

**config.toml 预览**（Codex）/ **settings.json 预览**（Claude）：
- 实时跟随表单字段变化，调用 `generateCodexPreview()` 生成预览内容
- 显示标题 + 文件路径（灰色 Menlo 字体）

**auth.json 预览**（仅 Codex）：
- 实时跟随 API Token 输入框变化，调用 `generateCodexAuthPreview()` 生成预览
- 标题为 "auth.json"，旁边显示文件路径 `~/.codex/auth.json`
- 无 API Token 时显示 `{}`

#### 预设供应商快速填充
- ChoiceChip 列表，每个预设有 SVG 图标
- SVG 图标使用品牌原色（无 colorFilter），不再是单色
- 默认选中"自定义"预设（`_selectedPresetName = '_custom_'`）

### 品牌色 SVG 图标

| 供应商 | 图标文件 | 品牌色 |
|--------|---------|--------|
| DMXAPI | `assets/icons/dmxapi.svg` | D=`#17a2b8` M=`#7d5f92` X=`#d72f5a`（三色字母） |
| OpenRouter | `assets/icons/openrouter.svg` | `#6467F2`（蓝紫色） |
| SiliconFlow | `assets/icons/siliconflow.svg` | `#6E29F6`（紫色） |

预设 chip 的 `SvgPicture.asset` 不使用 `colorFilter`，让 SVG 文件内嵌的品牌色直接生效。

## 注意事项 & 踩坑记录

### 1. 缓存刷新时序（已修复）

**问题**：`toggleActive()` 中激活后立即从缓存取 profile，但缓存未刷新，导致取不到。

**修复**：激活 DB 后先调用 `_loadProfiles()` 刷新缓存，再从缓存获取 profile。

### 2. 取消激活必须清理配置文件

**问题**：最初取消激活只更新了 DB 状态，配置文件中残留的供应商字段会继续生效。

**修复**：增加 `_clearClaudeSettings()` 和 `_clearCodexConfig()`，取消时移除配置文件中的供应商字段。

### 3. 配置文件写入失败的容错

**问题**：如果配置文件写入失败（权限问题、磁盘满等），DB 中已标记为激活，导致 DB 和实际配置不一致。

**修复**：`_writeConfigFile()` 用 try-catch 包裹，失败时回滚 DB 激活状态。

### 4. macOS 红绿灯 70px 间距

所有新页面的头部左侧必须保留 **70px** 间距，给 macOS 窗口控制按钮（红绿灯）让位。

### 5. Codex TOML 写入的逐行策略

Dart 没有成熟的 TOML 写入库，采用"逐行读取 → 过滤要覆盖的行 → 追加新值"策略。**注意**：正则匹配时要同时匹配 `model =` 和 `model=`（有无空格两种写法）。

### 6. Claude settings.json 的双层字段分布

Claude 的配置中：
- `model` 在 JSON 顶层
- `ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_BASE_URL` 等在 `env` 对象内

写入和清理时要注意分别处理这两层。

### 7. API Token 安全存储

目前 API Token 以明文存储在 SQLite 中。**未来改进**：使用 `flutter_secure_storage` 加密存储敏感信息。

### 8. Drift 代码生成

修改 `database.dart` 中的表定义后，必须运行代码生成：

```bash
dart run build_runner build --delete-conflicting-outputs
```

否则 `ProviderProfile`、`ProviderProfilesCompanion` 等类型不存在，编译报错。

### 9. Codex 模型列表不要走 REPL `/model`

REPL 场景会受到交互 UI 干扰（例如升级提示弹窗、欢迎页变化、ANSI 输出变化），不适合程序化解析。

当前实现改为走 `codex app-server` 的 JSON-RPC `model/list`，协议稳定，便于结构化处理与跨版本兼容。

### 10. 子进程生命周期管理

动态获取模型列表后必须及时回收子进程，避免后台残留：

1. 先关闭 stdin，让进程自然退出
2. 超时后 `kill()`
3. 再超时后 `sigkill` 兜底

这样可以保证 UI 刷新完成后没有僵尸进程或长期占用资源。

### 11. 官方配置同步不能无脑 upsert isActive（已修复）

**问题**：`_syncClaudeOfficial` 和 `_syncCodexOfficial` 原先使用 `upsert` 并强制 `isActive: true`，导致每次启动都会把官方配置设为激活，覆盖用户手动选择的第三方配置。

**修复**：改为先 `getProfileById` 检查是否存在。已存在则只 `updateProfile` 数据字段（不动 isActive）；首次创建才设 `isActive: true`。

### 12. 配置文件与 DB 激活状态不一致（已修复）

**问题**：用户在 app 中切换到 A 配置，然后手动把 B 配置的 settings.json 粘贴回去，重新进入 app 仍然高亮 A（DB 中 A 仍为 active）。

**修复**：`_reconcileActiveFromConfig` 以配置文件为 source of truth，读取实际的 `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN`，匹配 DB 中的 profile 并修正 active 状态。匹配优先级：精确匹配 > baseUrl 模糊匹配 > 官方兜底。

### 13. SVG 图标品牌色

**问题**：预设供应商的 SVG 图标使用 `currentColor` + `colorFilter`，导致所有图标都变成同一个颜色，失去品牌辨识度。

**修复**：
- SVG 文件中直接写死品牌色（如 `fill="#6467F2"`），不使用 `currentColor`
- 预设 chip 的 `SvgPicture.asset` 移除 `colorFilter` 参数
- DMXAPI 特殊处理：三个字母 D/M/X 分别用不同品牌色

### 14. Database schema 迁移

新增 `website` 字段时 schema version 从 1 升到 2，在 `onUpgrade` 中使用 `m.addColumn`。**注意不要把 Edit 应用两次导致重复列定义**。

### 15. Codex 双文件配置（config.toml + auth.json）

**设计决策**：Codex 的 API 密钥不在 `config.toml` 中，而是在独立的 `~/.codex/auth.json` 中。auth.json 可能包含完整的 OAuth token 结构（含 `access_token`、`refresh_token`、`expires_at` 等），但用户只需配置简单的 `{"OPENAI_API_KEY": "sk-xxx"}` 格式即可。

**实现要点**：
- 启动同步时同时读取 config.toml（model/reasoning/personality）和 auth.json（OPENAI_API_KEY），统一存入 DB
- DB 的 `apiToken` 字段复用存储 Codex 的 `OPENAI_API_KEY`
- 激活时写入两个文件：`_writeCodexConfig()` → config.toml，`_writeCodexAuth()` → auth.json
- **`_writeCodexAuth` 双路径写入策略**：
  - **有 apiKey（第三方供应商）**：直接覆盖整个 auth.json 为 `{"OPENAI_API_KEY": "sk-xxx"}`，清除所有 OAuth 字段（tokens、last_refresh 等）
  - **无 apiKey（官方配置）**：合并写入，读取现有内容，仅将 `OPENAI_API_KEY` 设为 null，保留 `tokens`、`last_refresh` 等 OAuth 字段
- 取消激活时清理两个文件：config.toml 走 `_mergeCodexConfig(profile: null)`，auth.json 走 `_writeCodexAuth(null)` 合并写入
- 编辑页的 auth.json 预览：官方配置展示真实文件内容（FutureBuilder），自定义配置实时跟随 apiToken 输入

### 16. Codex config.toml 非法字段 `disable_response_storage`（已修复）

**问题**：`_mergeCodexConfig` 写入自定义供应商时添加了 `disable_response_storage = true` 顶级键，但这个字段不在 Codex 的 TOML schema 中，导致 Even Better TOML 插件大量爆红 `Additional properties are not allowed`。

**修复**：
- 从 `_mergeCodexConfig` 中移除 `disable_response_storage` 的写入逻辑
- 在方法入口处主动清理历史残留的 `disable_response_storage` 行（兼容已有的脏 config）
- 自定义供应商只需 `model_provider = "custom"` + `[model_providers.custom]` section 即可

### 17. Codex reconcile 校正逻辑（已实现）

**问题**：原先 Codex 的 `_reconcileActiveFromConfig` 只做了去重（确保不出现多个 active），没有像 Claude 那样根据配置文件内容匹配 DB profile。导致用户通过 app 切换到 DMXAPI 后，手动把 config.toml 改回官方内容，app 仍然显示 DMXAPI 为"使用中"。

**修复**：Codex 分支现在完整读取 config.toml（`model_provider` + `[model_providers.custom].base_url`）和 auth.json（`OPENAI_API_KEY`），然后走和 Claude 相同的通用匹配逻辑（精确匹配 → 模糊匹配 → 官方兜底）。

### 18. Codex auth.json 覆盖写入丢失 OAuth tokens（已修复）

**问题**：`_writeCodexAuth` 原先直接用 `{"OPENAI_API_KEY": "sk-xxx"}` 整个覆盖 auth.json，导致 OAuth 登录用户的 `tokens`（含 `access_token`、`refresh_token`、`id_token`）和 `last_refresh` 等字段丢失。

**修复**：改为双路径策略——
- **第三方供应商（有 apiKey）**：直接覆盖整个文件为 `{"OPENAI_API_KEY": "sk-xxx"}`，不保留 OAuth 字段（第三方不需要 OAuth tokens）
- **官方配置（无 apiKey）**：合并写入，读取现有内容，将 `OPENAI_API_KEY` 设为 null，保留 `tokens`、`last_refresh` 等 OAuth 字段

**设计思考**：第三方供应商使用自己的 API Key，OAuth tokens 与之无关且会造成混淆；官方配置需要 OAuth tokens 进行认证，必须保留。

## 核心代码位置

| 文件 | 说明 |
|------|------|
| `lib/data/database.dart` | Drift 数据库定义 + CRUD（schema v2） |
| `lib/data/database.g.dart` | Drift 自动生成代码 |
| `lib/services/provider_switch_service.dart` | 业务逻辑层（切换/写入/清理/同步/刷新） |
| `lib/ui/pages/provider_switch/provider_list_screen.dart` | 列表页面（卡片交互 + 刷新按钮） |
| `lib/ui/pages/provider_switch/provider_edit_screen.dart` | 编辑/新增页面（预设填充 + 眼睛图标 + Base URL 提示） |
| `lib/ui/pages/home/header_action_buttons.dart` | 入口按钮（胶囊组） |
| `lib/main.dart` | 服务初始化 + Provider 注册 |
| `lib/l10n/locales/zh.json` | 中文国际化字符串 |
| `lib/l10n/locales/en.json` | 英文国际化字符串 |
| `assets/icons/dmxapi.svg` | DMXAPI 三色品牌图标 |
| `assets/icons/openrouter.svg` | OpenRouter 品牌色图标 |
| `assets/icons/siliconflow.svg` | SiliconFlow 品牌色图标 |

## 主题色

- **主色**：`Color(0xFFd97757)`（橙色），用于激活状态边框、左侧指示条、"使用中"徽章、激活按钮
- **品牌色**：各供应商 SVG 图标使用各自品牌原色

## i18n Keys（供应商相关）

| Key | 中文 | 用途 |
|-----|------|------|
| `provider_activate` | 切换使用 | 悬停激活按钮文字 |
| `provider_in_use` | 使用中 | 激活状态徽章 |
| `provider_base_url_tip` | 填写兼容 Anthropic API... | Base URL 下方提示 |
| `provider_website_hint` | https://example.com | 官网链接输入框 placeholder |
| `refresh_config` | 刷新配置 | 刷新按钮 tooltip |
| `config_refreshed` | 配置已刷新 | 刷新成功 Toast |
| `provider_codex_auth_preview` | auth.json | auth.json 预览标题 |
| `provider_codex_auth_file_path` | ~/.codex/auth.json | auth.json 文件路径显示 |
| `provider_codex_auth_loading` | 正在读取 ~/.codex/auth.json ... | 加载中提示（已弃用） |
| `provider_codex_auth_not_found` | 未找到 ~/.codex/auth.json | 文件不存在提示 |
| `provider_codex_auth_empty` | ~/.codex/auth.json 为空 | 文件内容为空提示 |
| `provider_codex_auth_read_error` | 读取 auth.json 失败 | 读取失败提示 |

## 未来扩展点

1. **API Token 加密存储**：使用 `flutter_secure_storage`
2. **配置导入/导出**：JSON 格式的供应商配置分享
3. **更多 CLI 工具支持**：Gemini CLI、Antigravity 等
4. **文件行数拆分**：`provider_edit_screen.dart` 较长，可拆分子组件
