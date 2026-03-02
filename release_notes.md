## v1.4.0

### ✨ 新增特性

**Gemini CLI 深度支持**

- **Extension MCP 展示**：Gemini 标签页现在自动读取 `~/.gemini/extensions/` 下所有已安装扩展的 MCP 服务器配置，独立展示为 "Extension MCPs" 区块，支持 `${extensionPath}`、`${/}` 占位符自动解析
- **Context 文件管理**：新增 Gemini Context 页面，展示全局 `~/.gemini/GEMINI.md` 及各扩展的 context 文件（GEMINI.md、WORKSPACE-Context.md、SPANNER.md 等），支持展开预览、一键复制
- **全局 Context 编辑**：全局 `GEMINI.md` 支持在 App 内直接编辑，内置 Markdown 编辑器，保存后实时刷新列表
- **Gemini 顶部按钮扩展**：Gemini 页面顶部胶囊按钮新增 Context 入口（💡图标），与 Skills、Provider 并列展示

**设置 - 环境检测优化**

- 每个工具卡片新增单独刷新按钮，无需全量重新检测即可更新单个工具的版本和安装状态
- 全局刷新进行中时，所有单项刷新按钮自动置灰禁用，避免并发冲突

### 🚀 优化改进

- **Provider 编辑页重构**：将臃肿的单文件拆分为 `provider_config_preview.dart`（配置预览组件）和 `provider_edit_form_fields.dart`（表单字段组件），代码可维护性大幅提升
- **Gemini MCP 列表修复**：修复当 `~/.gemini/settings.json` 中 `mcpServers` 为空时，Gemini 标签页直接返回"暂无配置"导致 Extension MCP 区域无法显示的问题


## v1.3.0

### ✨ 新增特性

**Gemini CLI 深度支持**

- **Extension MCP 展示**：Gemini 标签页现在自动读取 `~/.gemini/extensions/` 下所有已安装扩展的 MCP 服务器配置，独立展示为 "Extension MCPs" 区块，支持 `${extensionPath}`、`${/}` 占位符自动解析
- **Context 文件管理**：新增 Gemini Context 页面，展示全局 `~/.gemini/GEMINI.md` 及各扩展的 context 文件（GEMINI.md、WORKSPACE-Context.md、SPANNER.md 等），支持展开预览、一键复制
- **全局 Context 编辑**：全局 `GEMINI.md` 支持在 App 内直接编辑，内置 Markdown 编辑器，保存后实时刷新列表
- **Gemini 顶部按钮扩展**：Gemini 页面顶部胶囊按钮新增 Context 入口（💡图标），与 Skills、Provider 并列展示

**设置 - 环境检测优化**

- 每个工具卡片新增单独刷新按钮，无需全量重新检测即可更新单个工具的版本和安装状态
- 全局刷新进行中时，所有单项刷新按钮自动置灰禁用，避免并发冲突

### 🚀 优化改进

- **Provider 编辑页重构**：将臃肿的单文件拆分为 `provider_config_preview.dart`（配置预览组件）和 `provider_edit_form_fields.dart`（表单字段组件），代码可维护性大幅提升
- **Gemini MCP 列表修复**：修复当 `~/.gemini/settings.json` 中 `mcpServers` 为空时，Gemini 标签页直接返回"暂无配置"导致 Extension MCP 区域无法显示的问题


## v1.2.0

### ✨ 新增特性

- **项目级 MCP 健康检测**：展开项目卡片时自动运行 `claude mcp list`，实时显示各 MCP Server 的连接状态（Connected / Failed / Needs auth），Needs auth 状态支持一键打开终端完成 OAuth 授权
- **智能项目类型识别**：自动检测项目框架类型（Flutter、Vue、React、Nuxt、Next.js、Rust、Go、Python 等 11 种），展示对应框架图标和品牌配色，支持自动识别项目 favicon
- **项目列表排序**：支持按时间正序/倒序切换项目配置列表的排列顺序
- **供应商官网链接**：供应商列表中如果配置了官网地址，名称旁会显示跳转图标，点击直接在浏览器中打开
- **供应商悬浮状态标签**：hover 已激活的供应商时，显示「使用中」标签，视觉更直观
- **支持任意 Git 仓库安装 Skill**：Codex Skills 自定义安装不再局限于 GitHub，支持任意 Git 仓库地址（SSH / HTTPS）
- **Marketplace 支持 Git URL**：Claude Code 插件市场添加自定义源时，除了 owner/repo 格式外，现在也支持直接输入 Git 地址

### 🚀 优化改进

- **检查更新体验优化**：点击检查更新时立即显示提示信息，并新增 Releases 按钮作为手动下载的后备方案
- **命令执行支持工作目录**：`PlatformUtils.runCommand` 新增 `workingDirectory` 参数，支持在指定目录下执行命令
- **国际化文案更新**：技能安装和市场相关提示文案不再绑定 GitHub，统一为通用仓库链接描述
- **OAuth 授权定时器延长**：MCP OAuth 授权终端的自动退出时间从 1 分钟延长至 2 分钟，给用户更充裕的操作时间

### 🐛 问题修复

- **修复官方供应商数据被污染**：`official-claude` 预设记录不再从 `settings.json` 同步第三方中转数据，官方配置始终保持干净（name=Official, baseUrl=空）
- **修复切换官方供应商时残留第三方配置**：激活官方供应商后，`settings.json` 中的 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN` 等第三方字段会被正确清除
- **修复 Codex 系统技能可被删除**：内置系统技能的详情弹窗中不再显示删除按钮


## v1.1.0

### ✨ 新增特性
- **自动更新**: 新增应用自动更新检测服务 (Auto Update Check)。
- **OAuth 引导**: 新增 MCP OAuth 半自动化授权引导功能，简化鉴权流程。
- **数据管理**: 支持 Skills 配置的导入与导出功能，便于数据迁移与备份。
- **新预设 (Presets)**:
    - 新增 **OSS MCP Plus** 预设。
    - 新增 **MySQL MCP** 预设。

### 🚀 优化改进
- **Prompt**: 优化 Prompt 同步逻辑。
- **UI**: 优化编辑器图标 (Editor Icons) 显示效果。

### 🐛 问题修复
- 无


## v1.0.8

### ✨ 新增特性
- **Skill Usage**: 新增技能调用统计功能。
    - 在插件页面新增 "Skill Usage" 入口，点击可查看技能/指令的调用记录。
    - 展示每个 Skill 的累积调用次数 (Usage Count) 及最后使用时间 (Last Used)。
    - 数据直接从 `~/.claude.json` 读取，与 Claude CLI 共享统计信息。

### 🚀 优化改进
- **UI**: 优化插件详情页 (`PluginDetailDialog`) 及插件列表页 (`ClaudeCodeSkillsScreen`) 的视觉体验。
- **i18n**: 更新中英文翻译文案，支持新功能的国际化显示。

### 🐛 问题修复
- 无


## v1.0.7

### ✨ 新增特性
- **Health Check**: 新增 MCP 服务器健康检查功能。
    - 集成 `claude mcp list` 命令，实时检测服务器连接状态。
    - 支持状态缓存及防抖（5分钟内不重复检测），避免频繁调用。
    - 在项目卡片及主界面展示服务器健康状况。

### 🚀 优化改进
- **CI/CD**: 修复 Windows 构建工作流权限问题 (`contents: write`)，确保能成功上传 Release Assets。
- **UI**: 优化主窗口及项目卡片 (`ProjectCard`) 布局，适配健康状态显示。
- **i18n**: 更新中英文翻译文案。

### 🐛 问题修复
- 无


## v1.0.6

### ✨ 新增特性
- **Plugins**: 新增 Claude Code Skills 预设市场列表，支持快速添加官方及社区精选插件库 (e.g., Official, Superpowers, mcp-switch author's collection)。

### 🚀 优化改进
- **Workflow**: 发布脚本优化
- **CI/CD**: 优化 Windows 构建流程，自动生成并上传安装包 
- **i18n**: 更新部分界面文案 (Based on staged locale files)。

### 🐛 问题修复
- 无


## v1.0.5

### ✨ 新增特性
- 重构 MCP 服务器编辑界面

### 🚀 优化改进
- skills页面优化

### 🐛 问题修复
- 无


## v1.0.4

### ✨ 新增特性
- **主页与配置管理**：新增了应用主页，支持 MCP 预设配置的查看与编辑功能。针对claude code增加了cli优化

### 🚀 优化改进
- **界面重构**：重构了 MCP 服务器编辑界面，优化了交互体验。

### 🐛 问题修复
- （暂无显著修复记录）


## v1.0.3

### ✨ 新增特性
- **终端 AI 助手**：实现了 Command+I 快捷呼出的终端助手，包含模型切换及 Anthropic API 的完整集成。
- **Windows 平台支持**：正式添加对 Windows 操作系统的支持，扩展了应用的适用范围。
- **聊天功能增强**：聊天机器人现在支持发送和处理图片消息功能。
- **技能管理系统**：引入了 Gemini、Codex 和 Antigravity 的技能（Skill）与工作流管理能力，增强了系统的扩展性。

### 🚀 优化改进
- （暂无显著优化记录）

### 🐛 问题修复
- （暂无显著修复记录）


## v1.0.1

### ✨ 新增特性 (New Features)
- **内置终端 (Terminal Integration)**
  - 深度集成了 Claude Code 终端，支持交互式输入。
  - 基于 xterm.dart 重构，提供原生的终端体验。
  - 支持终端状态持久化，抽屉关闭后仍保持会话。
  - 增加了 REPL 进程检测与退出保护，防止意外关闭正在运行的任务 (python, claude, etc.)。
  - 首次启动展示独特的 Cat ASCII Art 欢迎动画。
- **规则管理 (Rules Management)**
  - 新增规则快速查看与编辑功能 (`RulesScreen`)。
  - 支持 Windsurf, Cursor, Antigravity/Gemini 等多种编辑器的规则文件管理。
  - 智能识别编辑器模式，动态切换显示的规则内容。
- **提示词管理 (Prompt Management)**
  - 重构了 Claude Code 提示词配置结构。
  - 提供了可视化的提示词管理界面，支持 Markdown 预览与编辑。

### 🚀 优化改进 (Improvements)
- **自动化工作流 (Workflows)**
  - 新增 `release` 工作流：实现一键自动构建、打包、发版到 GitHub。
  - 新增 `draft_release_notes` 工作流：自动生成发布说明草稿。
  - 优化 `bump_version.py`：版本号构建位 (Build Number) 现在基于 GitHub Release 总数自动计算，确保唯一性和递增性。

### 🐛 问题修复 (Bug Fixes)
- 修复了版本号生成脚本无法正确解析 GitHub Tag (v1.0.0) 的问题。
- 修复了 Release 模式下日志过滤器配置不生效的问题。
- 移除了一些冗余的控制台警告信息。


## MCP Switch v1.0.0 发布说明

### 🎉 核心功能 (Features)
- **⚡️ 一站式配置管理**
  支持 Claude Code, Codex, Cursor, Windsurf, Antiravity, Gemini 等多个主流 AI 编辑器的 MCP (Model Context Protocol) 配置文件管理。
- **🔄 灵活场景切换**
  默认集成Figma, Chrome Devtool预设，一键激活，无需手动修改 JSON 文件。
- **🖥 macOS 原生体验**
  极致适配 macOS 设计规范，支持深色模式/浅色模式自动切换，支持中英文切换提供沉浸式使用体验。
- **🧩 插件化架构**
  系统设计易于扩展，未来可轻松添加更多编辑器支持。
- **📥 托盘常驻 (Tray)**
  支持最小化到系统托盘，后台静默运行，随时快速调出。

### 🛠 变更日志 (Changelog)
- Initial Release (首次发布)。
- 集成 macOS 原生文件系统和权限管理。
- 修复托盘图标在 Release 模式下的显示问题。
