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
| Gemini | `~/.gemini/.env` | KEY=VALUE | `GEMINI_API_KEY`, `GOOGLE_GEMINI_BASE_URL`, `GEMINI_MODEL` |
| Gemini | `~/.gemini/settings.json` | JSON | 只读展示，不由供应商切换管理 |

### 数据源与写入策略（v1.8.0+ SQLite 全量配置存储）

#### 核心变化：SQLite 为配置数据的唯一数据源

v1.8.0 起，`ProviderProfiles` 表新增 `configContent TEXT?` 列，存储**完整的配置文件内容**（JSON/TOML/ENV）。编辑页不再从配置文件读取，始终以 SQLite 为数据源。

```
                     ┌──────────────────┐
  编辑页 ──读取──→  │ SQLite            │
                     │ configContent     │ ←─ 完整 JSON/TOML/ENV
                     └───────┬──────────┘
                             │ 保存时
                     ┌───────▼──────────┐
                     │ 字段列 + config-  │
                     │ Content 同时写入  │
                     └───────┬──────────┘
                             │ 仅选中供应商
                     ┌───────▼──────────┐
                     │ 写入配置文件       │
                     │ (settings.json/   │
                     │  config.toml/.env) │
                     └──────────────────┘
```

| 编辑器 | configContent 内容格式 | 初始化来源 |
|--------|----------------------|-----------|
| Claude | `settings.json` 完整 JSON | `widget.profile?.configContent` → `_claudeBaseConfig` |
| Codex | `config.toml` 完整 TOML | `widget.profile?.configContent` → `_codexExistingConfigContent` |
| Gemini | `.env` 完整 KEY=VALUE | `widget.profile?.configContent` → `_geminiExistingEnvContent` |

#### 保存写入（configContent 直写）

保存时，编辑页通过 `_buildConfigContentForSave()` 构建完整配置文本，同时传入 `configContent` 参数给 Service，写入 SQLite 的 `configContent` 列和各字段列。

```
编辑页保存
  → _buildConfigContentForSave()
    → Claude: JsonEncoder.convert(_buildClaudeConfigForSave())
    → Codex:  _buildCodexTomlForSave()
    → Gemini: _buildGeminiEnvForSave()
  → service.addProfile / updateProfile(configContent: ...)
  → SQLite: 字段列 + configContent 同时写入
  → 如果是当前选中的供应商 → _writeConfigFile()
    → profile.configContent 存在 → 直接写入文件
    → configContent 为空 → 回退到读取文件 + 合并字段（迁移兼容）
```

#### 兜底策略（configContent 为空时，迁移兼容）

当 `configContent` 为 null 时（老版本数据、toggleActive 等场景），回退到读取现有文件 + 合并表单字段的策略：

- **Claude Code** 的 JSON 是结构化的，直接操作 Map 对象即可。
- **Codex** 的 TOML 采用基于 section 感知的 upsert/remove 策略（`_mergeCodexConfig`）。
- **Gemini** 的 .env 按 KEY=VALUE 行解析并合并管理字段。

**Codex auth.json** 独立于 config.toml，存储 API 密钥。格式为 `{"OPENAI_API_KEY": "sk-xxx"}`。激活时同步写入，取消激活时清理 `OPENAI_API_KEY` 键（保留其他字段如 OAuth token）。

#### 列表页一致性检测

列表页对已选中供应商做 SQLite configContent 与配置文件的比较：
- **检测时机**：页面加载、切换编辑器 tab、从编辑页返回、点击刷新按钮
- **比较策略**：Claude 深度比较 JSON 对象（忽略格式）、Codex 规范化字符串比较、Gemini 解析 env map 比较
- **不一致时**：在卡片上显示琥珀色 "配置不同步" 标识，点击跳转编辑页重新保存
- **configContent 为空**：视为不一致，提示用户编辑后保存

## 架构设计

### 数据层（Drift ORM）

```
lib/data/database.dart
├── ProviderProfiles 表定义
├── AppDatabase 单例（WAL 模式，schemaVersion = 4）
├── Migration（v1→v2: website, v2→v3: oauthData, v3→v4: configContent）
├── CRUD 方法
└── database.g.dart（代码生成）
```

**表结构**：

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT (PK) | UUID |
| editorType | TEXT | `claude` / `codex` / `gemini` |
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
| oauthData | TEXT? | Codex OAuth tokens JSON（v3 新增） |
| configContent | TEXT? | 完整配置文件内容 JSON/TOML/ENV（v4 新增） |
| createdAt | DATETIME | 创建时间 |
| updatedAt | DATETIME | 更新时间 |

**激活逻辑**：使用事务，先 `deactivateAll(editorType)` 再激活目标，保证同类型只有一个激活。

### 服务层

```
lib/services/provider_switch_service.dart
├── 内存缓存（_claudeProfiles, _codexProfiles, _geminiProfiles）
├── 官方配置同步（_syncClaudeOfficial, _syncCodexOfficial, _syncGeminiOfficial）
├── 配置文件↔DB 激活状态校正（_reconcileActiveFromConfig）
├── configContent 迁移补偿（_migrateConfigContent）
├── 手动刷新（refreshFromConfig）
├── CRUD 操作（委托给 Database，含 configContent 字段）
├── 激活/取消（toggleActive）
├── 配置文件写入（_writeClaudeSettings, _writeCodexConfig, _writeCodexAuth, _writeGeminiEnv）
│   └── 优先使用 profile.configContent 直接写入，为空时回退到字段合并
├── 配置文件清理（_clearClaudeSettings, _clearCodexConfig, _clearGeminiEnv）
├── 一致性检测（checkConfigSync — 对比 SQLite configContent 与配置文件）
├── Codex TOML 合并引擎（_mergeCodexConfig, _upsertTopLevelKey, _upsertProviderSection 等）
├── Codex 模型动态拉取（codex app-server model/list）
├── Codex 模型缓存（内存 + ~/.mcp-switch/cache/codex_models.json）
├── 配置预览生成（generateCodexPreview, generateGeminiPreview, generateCodexAuthPreview）
├── 配置文件读取（readClaudeConfigFile, readCodexConfigFile, readCodexAuthFile, readGeminiEnvFile）
└── 静态模型列表（claudeModels, codexModels, geminiModels）
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
    → _syncGeminiOfficial()   // upsert Gemini 官方配置
    → _reconcileActiveFromConfig('claude')  // 以配置文件为准校正激活
    → _reconcileActiveFromConfig('codex')
    → _reconcileActiveFromConfig('gemini')
    → _loadProfiles()         // 刷新缓存
  → _migrateConfigContent()  // v4 迁移：已激活且 configContent 为空的 profile，从配置文件补充
  → _loadProfiles()          // 再次刷新
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
- **v1.5.1 起**：预设数据从 `assets/config/provider_presets.yaml` 动态加载，新增供应商无需改代码，只需编辑 YAML + 提供图标

### 供应商预设 YAML 管理（v1.5.1+）

预设数据从硬编码 Dart 常量迁移至 YAML 文件：

```
assets/config/provider_presets.yaml   # 所有供应商预设定义
lib/config/provider_presets_config.dart  # 加载器 + ProviderPreset 数据模型
```

**YAML 字段说明：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 唯一标识，用于 `_selectedPresetName` 匹配 |
| `name` | String | 显示名称 |
| `description` | String | 描述 |
| `base_url` | String | API 代理地址，空字符串表示使用官方地址 |
| `website` | String? | 官方网站 |
| `icon` | String? | SVG 图标路径 |
| `is_official` | bool | 为 true 时隐藏 apiToken/baseUrl 输入框 |

**数据按 editorType 分组：**

```yaml
presets:
  claude:
    - id: anthropic
      is_official: true
    - id: deepseek
      base_url: https://api.deepseek.com/anthropic
  codex:
    - id: openai
      is_official: true
  gemini:
    - id: google
      is_official: true
```

**加载流程：**

```
main.dart: await ProviderPresetsConfig.init()
    ↓ rootBundle.loadString('assets/config/provider_presets.yaml')
    ↓ 解析 YAML → Map<String, List<ProviderPreset>>
    ↓ 静态缓存

编辑页打开:
    ↓ ProviderPresetsConfig.presetsFor(editorType) → 预设列表
    ↓ 追加 _customPreset（id='_custom_'）
    ↓ 渲染 ChoiceChip
```

**`_isOfficialPreset` 判断：** 从 YAML `is_official` 字段读取，不再硬编码供应商名称。

### 品牌色 SVG 图标

| 供应商 | 图标文件 | 品牌色 |
|--------|---------|--------|
| DMXAPI | `assets/icons/dmxapi.svg` | D=`#17a2b8` M=`#7d5f92` X=`#d72f5a`（三色字母） |
| OpenRouter | `assets/icons/openrouter.svg` | `#6467F2`（蓝紫色） |
| SiliconFlow | `assets/icons/siliconflow.svg` | `#6E29F6`（紫色） |
| DeepSeek | `assets/icons/deepseek.svg` | `#4D6BFE`（蓝色） |
| MiniMax | `assets/icons/minimax.svg` | `#1A1A2E`（深色） |
| Zhipu GLM | `assets/icons/zhipu.svg` | `#1461FF`（蓝色） |
| Kimi | `assets/icons/kimi.svg` | `#1B1B1B`（深色） |
| PackyCode | `assets/icons/packycode.svg` | `#FF6B35`（橙色） |

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

### 19. 未保存变更检测的坑（Dirty Check）

#### 坑 1：编辑模式切换导致误报

**问题**：进入编辑页，点"编辑"按钮切换到编辑模式（不做任何修改），再返回就弹"未保存更改"。

**原因**：初始快照中 `editedConfig` 用的是 `_generateClaudePreviewText()`（只读模式），点编辑后 `_editedConfigData` 从 `null` 变为非 `null`，如果快照用 `_editedConfigData != null ? serialize(_editedConfigData) : _generateClaudePreviewText()`，两种路径生成的 JSON 文本可能不一致（序列化格式差异）。

**修复**：两种路径统一使用 `JsonEncoder.withIndent('  ')` 格式化。`_editedConfigData` 初始化时就是从 `_claudeBaseConfig + 表单覆盖` 生成，内容与 `_generateClaudePreviewText()` 一致，序列化后字符串相同 → 无误报。

#### 坑 2：初始快照拍早了

**问题**：`initState` 中立即拍的快照可能在 `_claudeBaseConfig` 还是空 Map 时就拍了，导致 `editedConfig = null`。后续加载完成后，配置有了实际值 → 任何操作都算"有变更"。

**修复**：`_configPreviewFuture.then()` + `addPostFrameCallback()` 延迟拍最终快照，确保异步加载完成 + 首帧渲染完成后才拍。

#### 坑 3：TextEditingController 的空格差异

**问题**：前后空格差异导致快照不一致。比如 apiToken 显示为 `"sk-xxx "` 但 trim 后变化。

**修复**：所有 TextEditingController 值统一 `.trim()` 后再入快照。

### 20. 源码编辑不实时同步的坑（Raw JSON Editor）

#### 坑 1：编辑后表单不更新

**问题**：在源码编辑 Tab 修改了 `ANTHROPIC_BASE_URL`，表单的 Base URL 输入框没有同步更新。

**原因**：原设计中 `onTextChanged` 只做 JSON 校验和 `_rawDirty = true`，不调用 `onChanged`。变更只有点"应用更改"按钮才同步。

**修复**：`onTextChanged` 中 JSON 合法时直接调用 `widget.onChanged(parsed)`，实时同步。"应用更改"按钮因此不再有实际作用，已删除。

#### 坑 2：编辑后返回无弹窗

**问题**：源码编辑修改了字段，但返回/取消时不弹"未保存更改"。

**原因**：与坑 1 同源。`_editedConfigData` 没被更新（`onChanged` 未调用），快照比较时看不到差异。

**修复**：同坑 1，实时同步后 `_editedConfigData` 始终是最新值。

### 21. Autocomplete 内部 controller 不随外部状态更新

#### 坑 1：源码编辑改 model，CLI 模型输入框不更新

**问题**：在源码编辑中把 `"model": "opus"` 改为 `"model": "opus33"`，表单的 CLI 模型输入框仍显示 "opus"。

**原因**：Flutter `Autocomplete` 的 `initialValue` 只在初始化时生效（`initState`），后续 rebuild 不更新内部 controller 的 text。`_syncFromConfig` 只更新了 `_selectedModel`（状态变量），但 Autocomplete 内部 controller 不知道。

**修复**：在 `_buildAutocompleteModelField` 的 `fieldViewBuilder` 中通过 `onControllerReady` 回调捕获 Autocomplete 的内部 controller 引用（`_cliModelController`），在 `_syncFromConfig` 中同步更新：`_cliModelController?.text = model`。

#### 坑 2：controller 引用被覆盖到错误字段

**问题**：修复后，源码编辑改 model 却更新到了"VSCode 插件模型"输入框，CLI 模型仍不变。

**原因**：`_buildAutocompleteModelField` 被 CLI 模型和 VSCode 插件模型共用。之前在方法内部无条件赋值 `_cliModelController = controller`，VSCode 字段在 Row 中排后面、后构建，覆盖了 CLI 的引用。

**修复**：移除方法内的无条件赋值，改为 `onControllerReady` 可选回调参数。只有 CLI 模型的调用传入回调来捕获 controller，VSCode 不传。

### 22. 设置页「应用到 Claude Code 插件」联动开关（新增）

**位置**：设置页 `通用` 面板。  
**配置键**：`enable_claude_plugin_integration`（SharedPreferences）。

**核心行为**：
- 开关开启后，会联动 `~/.claude/config.json` 的 `primaryApiKey`
- 切到 Claude 非官方供应商时，写入 `"primaryApiKey": "any"`
- 切到 Claude 官方供应商，或关闭联动，或取消 Claude 激活时，删除 `primaryApiKey`
- 对 `~/.claude/settings.json` 无直接影响，`settings.json` 仍由 Claude 供应商切换主流程维护

**为什么有时看起来“没改文件”**：
- 开关没开
- 文件已是目标状态（例如已经是 `"any"`）
- 当前不是 Claude 供应商切换
- 联动异常被保护性捕获（不阻断主流程）

详细说明见：
- `docs/context/claude_plugin_integration_toggle.md`

### 23. Codex 配置编辑器（v1.7.0+）

Codex 的配置编辑器与 Claude 不同，采用**纯文本编辑**模式（无结构化树视图），因为 TOML 格式无法像 JSON 那样用 Map 操作。

**核心组件**：
- `codex_config_editor.dart`：TextField + maxLines: null，实时回调 `onChanged`
- `provider_config_preview.dart`：编辑/预览模式切换 + 正向/反向双向同步

**双向同步**：
- **正向同步**（表单 → 编辑器）：`_syncFormToCodexPreview()` 用 `_upsertTomlValue`（顶级键）和 `_upsertSectionTomlValue`（section 键）更新 TOML 文本
- **反向同步**（编辑器 → 表单）：`_syncFromCodexToml()` 用 `_parseTomlValue`（顶级键）和 `_parseSectionTomlValue`（section 键）解析 TOML 更新表单控件
- 同步的字段：`model`、`model_reasoning_effort`、`personality`（顶级）、`base_url`（`[model_providers.custom]` section）

**TOML 行级工具方法**（`provider_config_preview.dart` 中的 static 方法）：
| 方法 | 作用 |
|------|------|
| `_parseTomlValue(toml, key)` | 从第一个 [section] 之前解析顶级 key |
| `_parseSectionTomlValue(toml, section, key)` | 从指定 [section] 内解析 key |
| `_upsertTomlValue(toml, key, value)` | 更新/插入顶级 key |
| `_upsertSectionTomlValue(toml, section, key, value)` | 更新/插入指定 section 内的 key |

### 24. Codex 编辑器 `_dirty` 标志导致外部更新被忽略（已修复）

**问题**：`CodexConfigEditor` 的 `didUpdateWidget` 中用 `if (!_dirty)` 判断，`_dirty` 在用户打字后永远为 `true`。之后表单字段变化 → `_syncFormToCodexPreview()` 更新了 `_editedCodexText` → 传入新的 `initialText` → 但 `didUpdateWidget` 因 `_dirty` 跳过 → 编辑器不更新。

**修复**：移除 `_dirty` 标志，改为比较 `widget.initialText != _controller.text`。Flutter `TextField` 的 `onChanged` 只在用户输入时触发，`controller.text =` 赋值不会触发 → 无循环风险。

### 25. Codex auth.json FutureBuilder 导致滚动跳动（已修复）

**问题**：Codex 编辑页切换编辑/预览模式时，滚动条会跳到顶部。Claude 无此问题。

**根因**：`_buildOfficialAuthContent` 中每次 build 都调用 `ProviderSwitchService.readCodexAuthFile()` 创建**新 Future**，FutureBuilder 重新进入 `waiting` 状态显示 `"..."`（高度极小），然后文件读取完成显示完整 JSON（高度变大）。这个异步高度跳动发生在 `_keepScrollPosition` 恢复之后，破坏了滚动位置。

**修复**：在 `initState` 中一次性加载 auth 内容到 `_codexAuthContent`，`_buildOfficialAuthContent` 改为同步渲染，彻底消除 build 中的异步高度跳动。

### 26. Codex 编辑/预览模式高度不一致（已修复）

**问题**：切换编辑/预览模式时，auth.json 的可见范围不同。

**根因**：
1. `CodexConfigEditor`（编辑模式）：maxHeight: 400, contentPadding: 12
2. `_buildPreviewText`（预览模式）：maxHeight: 300, 外层 Container padding: 16

**修复**：统一 maxHeight: 300、padding: 16、暗色模式背景色 `0xFF2C2C2E`。

### 27. 编辑选中供应商保存后配置文件未更新（已修复）

**问题**：编辑当前使用中的 Codex 供应商并保存后，`~/.codex/config.toml` 没有更新。

**修复**：`updateProfile` 中增加判断：
```dart
final updatedProfile = await _db.getProfileById(id);
if (updatedProfile != null && (wasActive || updatedProfile.isActive)) {
  await _writeConfigFile(editorType, updatedProfile);
}
```

### 28. 配置文件二次合并导致预览与文件不一致（已修复）

**问题**：保存时 `_writeClaudeSettings` / `_writeCodexConfig` 在 `_pending*Extra` 存在时仍然二次合并表单值，虽然结果通常相同，但概念上不正确且可能引入边界不一致。

**修复**：当 `_pending*Extra` 存在时直接写入文件，跳过二次合并：
- `_writeClaudeSettings`：`extra != null` → `encoder.convert(extra)` 直接写入 → return
- `_writeCodexConfig`：`extra != null` → 直接 `tomlFile.writeAsString(extra)` → 跳过 `generateCodexPreview`
- `_writeGeminiEnv`：`extra != null` → 直接 `envFile.writeAsString(extra)` → return

### 29. Gemini 配置预览不显示已有 .env 内容（已修复）

**问题**：Gemini 的 `generateGeminiPreview` 只生成 3 个管理字段（GEMINI_API_KEY、GOOGLE_GEMINI_BASE_URL、GEMINI_MODEL），不读取已有 `.env` 文件中的自定义环境变量。新增供应商时用户看不到自己的自定义配置。

**修复**：
1. `generateGeminiPreview` 新增 `existingEnvContent` 参数，解析已有 `.env` 键值对后合并管理字段
2. `initState` 中缓存 `.env` 内容到 `_geminiExistingEnvContent`
3. 预览改为同步生成（加载完成后），与 Claude/Codex 一致
4. 新增 `_buildGeminiEnvForSave()` 返回完整预览文本
5. 新增 `_pendingGeminiExtra` 机制，保存选中供应商时直写预览数据

### 30. SQLite 全量配置存储重构（v1.8.0）— _pending*Extra → configContent

**背景**：v1.7.x 使用 `_pendingClaudeExtra` / `_pendingCodexExtra` / `_pendingGeminiExtra` 临时变量在内存中传递配置预览数据。非选中的供应商点击编辑时，仍然从配置文件读取（而非从 SQLite），导致以下问题：

1. **非选中供应商编辑页数据错误**：配置预览显示的是当前配置文件的内容（属于其他选中的供应商），而不是该供应商自己保存的配置
2. **选中供应商外部修改后无感知**：用户在 CLI 或其他工具修改了配置文件，app 内无法检测到与 SQLite 的不一致
3. **临时变量生命周期短**：`_pending*Extra` 在服务重启后丢失

**解决方案**：在 `ProviderProfiles` 表新增 `configContent TEXT?` 列，schema v3 → v4，统一存储完整配置。

**涉及的核心改动**：

| 模块 | 改动 |
|------|------|
| `database.dart` | 新增 `configContent` 列 + v4 迁移 |
| `provider_switch_service.dart` | 移除 3 个 `_pending*Extra` 临时变量；`addProfile/updateProfile` 接受 `configContent` 参数；`_write*` 方法优先使用 `profile.configContent` 直写；新增 `checkConfigSync()` + `_migrateConfigContent()` |
| `provider_edit_screen.dart` | `initState` 从 `widget.profile?.configContent` 同步初始化，不再调用 `read*ConfigFile()`；新增 `_buildConfigContentForSave()` 构建完整配置字符串 |
| `provider_config_preview.dart` | `_buildReadonlyPreview` 移除 `FutureBuilder` 异步加载，改为同步渲染 |
| `provider_list_screen.dart` | 新增 `_isConfigSynced` 状态 + 琥珀色 "配置不同步" 警告标识 |

**checkConfigSync 比较策略**：

| 编辑器 | 比较方法 | 原因 |
|--------|---------|------|
| Claude | `_jsonEquals` — 深度比较 JSON 对象 | JSON 格式化差异（缩进、键序）不影响语义 |
| Codex | `_normalizedEquals` — trim + 规范化空白 | TOML 尾行换行等无语义差异 |
| Gemini | `_envEquals` — 解析为 Map 后比较 | env 行顺序和空行不影响语义 |

**_migrateConfigContent 一次性迁移**：
- 时机：`init()` 启动时执行
- 条件：已激活 profile 的 `configContent == null`
- 行为：读取对应配置文件内容，回写到 SQLite 的 `configContent` 字段
- 目的：确保老版本升级后的已激活供应商也有完整配置数据

**踩坑**：
- `_migrateConfigContent` 中 `fileContent` 变量声明为 `String?` 时，后续的 `fileContent != null` 检查会被 lint 报警（所有分支均已赋值，不可能为 null），需改为 `String` 非空类型
- `build_runner` 需要在非沙箱环境运行（macOS 沙箱会阻止文件 IO）

### 31. Codex reconcile 硬编码 `model_provider != 'custom'` 导致非 custom 供应商重载后被重置（已修复）

**问题**：Codex 供应商使用 `model_provider = "OpenAI"` + `[model_providers.OpenAI].base_url` 配置自定义 base_url 时，重载应用后 Official 被激活，用户选择的供应商丢失。

**根因**：`_reconcileActiveFromConfig` 中硬编码了 `if (fileModelProvider != 'custom') { fileBaseUrl = null; }`。虽然代码已正确从 `[model_providers.OpenAI]` 提取了 `base_url`，但因为 `"OpenAI" != "custom"` 立即将其清空。随后 `fileBaseUrl == null` 走到兜底匹配官方 profile。

**修复**：移除硬编码判断。如果 TOML 中的 `[model_providers.X]` section 没有 `base_url` 键，变量自然保持 null，不需要额外清空。用户可以使用任意 `model_provider` 名称搭配自定义 `base_url`。

### 32. 配置冲突解决 UI（v1.8.1+）

编辑已选中（active）的供应商时，`initState` 自动异步检测 SQLite `configContent` 与本地配置文件是否一致。若不一致，显示冲突解决界面。

**触发条件**：编辑模式 + profile.isActive + configContent != null

**UI 组成**：
1. **顶部琥珀色横幅**：提示"本地配置文件与已保存数据不一致"，右侧关闭按钮（= 使用已保存数据）
2. **左右双栏对比**：替换配置预览区域，左栏"本地文件"、右栏"已保存数据"，各有"使用此版本"按钮

**操作响应**：
- "使用本地文件"：用文件内容替换 SQLite 数据（更新 `_claudeBaseConfig` / `_codexExistingConfigContent` / `_geminiExistingEnvContent`），反向同步表单字段，用户保存后写入 SQLite + 文件
- "使用已保存数据"：保留 SQLite 数据，用户保存后覆盖文件
- 选择任一版本后恢复正常编辑流程，用户可继续手动修改

**涉及文件**：
| 文件 | 改动 |
|------|------|
| `config_conflict_banner.dart` | 新建：横幅 + 双栏对比 StatelessWidget |
| `provider_edit_screen.dart` | `_hasConfigConflict`/`_localFileContent` 状态 + `_checkConfigConflict()` + `_resolveConflict()` + build 中插入横幅 |
| `provider_config_preview.dart` | `_buildConfigPreview` 冲突时显示 `ConfigConflictDiff`；新增 `_syncFormFromGeminiEnv`；`_hasConfigConflict`/`_localFileContent` 抽象成员 |
| `provider_switch_service.dart` | `_jsonEquals` / `_normalizedEquals` / `_envEquals` → 公开 static 方法（`jsonEquals` / `normalizedEquals` / `envEquals`） |

### 33. i18n — 供应商一致性检测 + 冲突解决相关

| Key | 中文 | 英文 | 用途 |
|-----|------|------|------|
| `provider_config_out_of_sync` | 配置不同步 | Config Out of Sync | 列表页警告标签 |
| `provider_config_sync_hint` | 本地配置文件与保存的数据不一致，点击编辑后重新保存以同步 | Local config file differs from saved data. Edit and re-save to sync. | 警告 tooltip |
| `config_conflict_banner` | 本地配置文件与已保存数据不一致，请选择保留的版本 | Local config file differs from saved data. Choose which version to keep. | 冲突横幅文字 |
| `config_conflict_local_file` | 本地文件 | Local File | 左栏标题 |
| `config_conflict_saved_data` | 已保存数据 | Saved Data | 右栏标题 |
| `config_conflict_use_this` | 使用此版本 | Use This Version | 对比栏按钮 |

## 核心代码位置

| 文件 | 说明 |
|------|------|
| `lib/data/database.dart` | Drift 数据库定义 + CRUD（schema v4） |
| `lib/data/database.g.dart` | Drift 自动生成代码 |
| `lib/services/provider_switch_service.dart` | 业务逻辑层（切换/写入/清理/同步/刷新/configContent 直写/一致性检测） |
| `lib/services/claude_plugin_integration_service.dart` | Claude 插件联动（`~/.claude/config.json` 的 `primaryApiKey` 写入/清理） |
| `lib/constants/claude_config_schema.dart` | Claude settings.json 配置键定义 |
| `lib/ui/pages/provider_switch/provider_list_screen.dart` | 列表页面（卡片交互 + 刷新按钮 + 一致性检测标识） |
| `lib/ui/pages/provider_switch/provider_edit_screen.dart` | 编辑/新增页面主状态 |
| `lib/ui/pages/provider_switch/components/provider_edit_form_fields.dart` | 表单字段 mixin |
| `lib/ui/pages/provider_switch/components/provider_config_preview.dart` | 配置预览 mixin（编辑/预览切换 + 双向同步 + TOML 工具方法） |
| `lib/ui/pages/provider_switch/components/config_conflict_banner.dart` | 配置冲突横幅 + 双栏对比组件 |
| `lib/ui/pages/provider_switch/components/claude_config_editor.dart` | Claude settings.json 编辑器（结构化 + 源码双模式） |
| `lib/ui/pages/provider_switch/components/codex_config_editor.dart` | Codex config.toml 纯文本编辑器 |
| `lib/ui/pages/settings/settings_screen.dart` | 设置页通用面板开关 UI（应用到 Claude Code 插件） |
| `lib/ui/pages/home/header_action_buttons.dart` | 入口按钮（胶囊组） |
| `lib/main.dart` | 服务初始化 + Provider 注册 |
| `lib/l10n/locales/zh.json` | 中文国际化字符串 |
| `lib/l10n/locales/en.json` | 英文国际化字符串 |

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

## Claude settings.json 配置编辑器（v1.6.0+）

### 概述

在 Claude 供应商编辑页的「配置预览」区域，新增了交互式编辑能力。用户可以在预览区域点击"编辑"按钮，进入可编辑模式，通过结构化编辑或源码编辑两种方式，为 `~/.claude/settings.json` 添加表单中不包含的额外配置项（如 `language`、`alwaysThinkingEnabled`、`outputStyle` 等）。

### 架构设计

```
lib/constants/claude_config_schema.dart       # 配置键定义（root 层级 + env 层级）
lib/ui/pages/provider_switch/components/
├── claude_config_editor.dart                 # 独立 Widget：编辑器主体
└── provider_config_preview.dart              # mixin：编辑/预览模式切换 + 反向同步
```

### 配置键定义（ClaudeConfigSchema）

所有支持的配置键定义在 `lib/constants/claude_config_schema.dart` 常量中，分为两个层级：

| 层级 | 说明 | 示例键 |
|------|------|--------|
| `rootKeys` | JSON 根层级键 | `model`, `language`, `outputStyle`, `alwaysThinkingEnabled`, `cleanupPeriodDays`, `autoUpdatesChannel` 等 |
| `envKeys` | `env` 对象内的环境变量键 | `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, `CLAUDE_CODE_ENABLE_TELEMETRY`, `HTTP_PROXY` 等 |

每个键包含：
- **type**：`string` / `number` / `boolean`，决定编辑器中的输入方式
- **presets**：预设值列表，显示为 ChoiceChip 供快速选择

**表单管理标记**：
- `formManagedRootKeys`：被上方表单直接管理的 root 键（如 `model`），编辑器中显示链接图标
- `formManagedEnvKeys`：被上方表单直接管理的 env 键（如 `ANTHROPIC_AUTH_TOKEN`）

**后续扩展**：Claude Code 新增配置项时，只需在此文件中添加键定义，无需改动 UI 代码。

### 交互设计

#### 1. 编辑/预览切换

- 配置预览标题栏右侧显示"编辑"按钮（Claude 类型专属）
- 点击进入编辑模式，按钮变为橙色"预览"按钮
- 非 Claude 类型仍显示原有的"格式化"按钮

#### 2. 结构化编辑模式（Tab 1）

- JSON 渲染为缩进的键值对树，带语法高亮（键名蓝色，字符串值红色，数字/布尔绿色）
- 每行 hover 时显示操作按钮：
  - **表单管理的字段**：显示链接图标 + tooltip "此字段由上方表单管理"
  - **自定义字段**：显示红色 × 删除按钮
- 每个层级末尾有橙色 **"+ 添加字段"** 按钮
- 点击"+"弹出对话框：
  - 顶部：可选键列表（ChoiceChip 形式），已存在的键自动过滤
  - 底部：根据键的类型显示不同输入：
    - `boolean`：true / false 切换 chip
    - 有 presets 的：预设值 chip + 自由输入框
    - 纯 string/number：自由输入框
  - 确认后一次性添加键值对

#### 3. 源码编辑模式（Tab 2）

- TextField 直接编辑 JSON 文本
- 实时校验 JSON 格式，错误时红色边框 + 错误提示
- **实时自动同步**：JSON 合法时自动调用 `onChanged` 同步到数据层和表单（无需手动"应用更改"按钮）
- Tab 切换时自动同步两种模式的数据
- `_rawDirty` 标记防止 `didUpdateWidget` 覆盖用户正在编辑的文本

#### 4. 双向同步

**正向同步**（表单 → 编辑器）：
- 编辑模式：`_syncFormToClaudePreview()` 将表单值覆盖到 `_editedConfigData`
- 只读模式：`_generateClaudePreviewText()` 同步生成预览文本（避免 FutureBuilder 异步导致滚动跳动）

**反向同步**（编辑器 → 表单）：编辑器中修改表单管理字段时，通过 `_syncFromConfig()` 自动同步回表单控件：
- `env.ANTHROPIC_AUTH_TOKEN` → `_apiTokenController`
- `env.ANTHROPIC_BASE_URL` → `_baseUrlController`
- `env.CLAUDE_CODE_MAX__OUTPUT_TOKENS` → `_maxOutputTokensController`
- `env.MAX_THINKING_TOKENS` → `_maxThinkingTokensController`
- `model` → `_selectedModel` + `_cliModelController`（Autocomplete 内部 controller）

#### 5. 未保存变更检测（Dirty Check）

编辑页在返回/取消时，检测是否有未保存的更改，有则弹窗提示。

**实现机制：快照对比**

```
initState():
  → _initialSnapshot = _takeSnapshot()    // 立即拍一个初始快照
  → _configPreviewFuture.then((_) {       // 等异步配置加载完成
      addPostFrameCallback(() {
        _initialSnapshot = _takeSnapshot() // 拍最终稳定快照
      })
    })

返回/取消时:
  → _hasUnsavedChanges()
    → _takeSnapshot() 拍当前快照
    → 逐 key 对比当前 vs 初始快照
    → 有差异则弹出 CustomConfirmDialog
```

**`_takeSnapshot()` 采集的字段：**

| 字段 | 来源 | 处理 |
|------|------|------|
| name, description, apiToken, baseUrl, website | TextEditingController | `.text.trim()` |
| maxOutputTokens, maxThinkingTokens | TextEditingController | `.text.trim()` |
| model | `_selectedModel` | `.trim()` |
| reasoningEffort, personality | 下拉值 | 直接比较 |
| editedConfig | **预览 JSON 文本** | 见下方说明 |

**`editedConfig` 快照策略（核心）：直接取预览显示的 JSON**

```dart
'editedConfig': _isClaude && _claudeBaseConfig.isNotEmpty
    ? (_isPreviewEditing && _editedConfigData != null
        ? JsonEncoder.withIndent('  ').convert(_editedConfigData)  // 编辑模式
        : _generateClaudePreviewText())                           // 只读模式
    : null,
```

- **只读模式**：取 `_generateClaudePreviewText()`（`_claudeBaseConfig` + 表单覆盖）
- **编辑模式**：直接序列化 `_editedConfigData`
- 两者在内容未修改时生成一致的 JSON 字符串（相同的 `JsonEncoder.withIndent` 格式化）

### 保存写入逻辑（三个编辑器统一，v1.8.0+ configContent）

保存时将配置预览数据通过 `configContent` 参数同时写入 SQLite 和配置文件：

```
_save()
  → _buildConfigContentForSave()
    → Claude: JsonEncoder.convert(_buildClaudeConfigForSave()) → 完整 JSON 字符串
    → Codex:  _buildCodexTomlForSave()                        → 完整 TOML 字符串
    → Gemini: _buildGeminiEnvForSave()                        → 完整 .env 字符串
  → service.addProfile / updateProfile(configContent: ...)
    → SQLite: 各字段列 + configContent 同时写入
    → 如果是当前选中的供应商 → _writeConfigFile()
      → profile.configContent 存在 → 直接写入（不二次合并）
      → configContent 为空 → 读取文件 + 合并（迁移兼容兜底）
```

**关键设计**：`configContent` 存在时直接写入，不再二次合并。预览数据已经是完整的配置，二次合并是冗余的且可能引入不一致。v1.8.0 前的 `_pendingClaudeExtra` / `_pendingCodexExtra` / `_pendingGeminiExtra` 临时变量机制已移除。

### i18n Keys（配置编辑器相关）

| Key | 中文 | 用途 |
|-----|------|------|
| `config_editor_structured` | 结构化编辑 | Tab 标签 |
| `config_editor_raw_json` | 源码编辑 | Tab 标签 |
| `config_editor_edit_mode` | 编辑 | 切换按钮文字 |
| `config_editor_preview_mode` | 预览 | 切换按钮文字 |
| `config_editor_add_field` | 添加字段 | "+"按钮文字 |
| `config_editor_add_title` | 添加配置项 | 弹窗标题 |
| `config_editor_select_key` | 选择配置键 | 弹窗内标签 |
| `config_editor_value` | 值 | 弹窗内标签 |
| `config_editor_confirm_add` | 添加 | 弹窗确认按钮 |
| `config_editor_apply` | 应用更改 | ~~源码编辑应用按钮~~（已删除，源码编辑改为实时同步） |
| `config_editor_json_error` | 格式错误 | JSON 校验失败提示 |
| `config_editor_no_more_keys` | 当前层级所有可用键已添加 | 无可用键时提示 |
| `config_editor_form_managed` | 此字段由上方表单管理 | hover tooltip |

## 未来扩展点

1. **API Token 加密存储**：使用 `flutter_secure_storage`
2. **配置导入/导出**：JSON 格式的供应商配置分享
3. **更多 CLI 工具支持**：Antigravity 等
4. **Gemini 配置编辑器**：当前 Gemini 仅预览模式，可扩展为支持 .env 内联编辑
