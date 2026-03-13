## v1.8.1

### ✨ 新增特性

- **Kiro 编辑器支持**：新增 Amazon Kiro 编辑器的 MCP 配置管理，包含启动屏图标及配置路径适配
- **Atlassian MCP 预设**：新增 Atlassian（Jira / Confluence）MCP 预设，HTTP 远程连接，URL 为 `mcp.atlassian.com/v1/mcp`

### 🚀 优化改进

- **MCP Tools 描述浮层可复制**：Tool chip 的描述文字从 Tooltip 改为悬浮浮层，支持鼠标移入选中和复制，且自动限制在窗口边界内
- **图标目录重构**：统一编辑器图标管理结构

### 🐛 问题修复

- **Cursor 远程配置字段名修正**：Cursor/Kiro 的 HTTP 远程配置从错误的 `serverUrl` 改为 `url`，并补充缺失的 `type` 字段
- **自定义配置草稿泄漏**：修复从预设切换到自定义配置时，预设数据残留在配置预览中的问题


## v1.8.0

### ✨ 新增特性

- **MCP Tools 查询与展示**：在 MCP 配置列表中，已启用的 MCP Server 可以展开查看其提供的 Tools 列表，支持三种查询方式：
  - Codex：通过 `codex app-server` JSON-RPC 接口批量获取所有 MCP 的 tools
  - Cursor (command 型)：直接启动 MCP 进程，通过 stdio NDJSON 协议发送 `tools/list` 请求
  - Cursor (url 型)：通过 HTTP POST JSON-RPC 查询（需 OAuth 授权的 MCP 会显示友好提示）
- **配置冲突 Diff 高亮**：配置冲突横幅中的左右对比面板现在基于 LCS 算法高亮差异行，并显示行号，更容易识别具体变更位置
- **Node.js 版本诊断**：环境检测页在 MCP Server 启动失败时，若检测到 `SyntaxError` 或 `Invalid regular expression flags`，会智能提示当前 Node.js 版本过低（< v20），引导用户升级

### 🚀 优化改进

- **ConfigService 拆分重构**：将原本 1409 行的单文件 `config_service.dart` 拆分为 `config/` 目录下 4 个文件（主类 280 行 + Settings Mixin + Sync Mixin + CodexConfigHelper 工具类），提升可维护性
- **Toast 防重叠**：连续触发多个 Toast 时，新 Toast 会自动移除上一个，避免多条提示在屏幕上堆叠
- **ProfileCard 插槽扩展**：ProfileCard 组件新增 `descriptionTrailing` 和 `footer` 插槽，支持嵌入 Tools 展示等自定义内容

### 🧪 测试

- 新增 `codex_config_helper_test.dart`（20 个用例），覆盖 TOML 解析/生成、CLI 输出解析、工具方法等


## v1.7.3

### 🐛 问题修复

- **Codex MCP 状态修复**：修复新增 MCP 后 Auth 状态不显示及终端登录后列表不刷新的问题


## v1.7.2

### ✨ 新增特性

- **Codex MCP Auth 状态检测** — Codex MCP 列表现在通过 `codex mcp list` 命令异步获取每个 MCP 服务器的授权状态
  - 需要登录的 MCP 显示橙色 "Need Auth" 标签
  - 已授权的 MCP 显示绿色状态标签
  - 不支持授权的 MCP（stdio 类型）不显示标签
- **Codex MCP 终端登录** — 需要授权的 MCP 卡片上新增登录图标，点击自动打开侧边终端执行 `codex mcp login <name>`
- **MCP 名称去重校验** — 新增/编辑 Claude Code 和 Codex 的 MCP 配置时，自动检查名称是否与已有配置冲突，重复时阻止保存并提示

### 🚀 优化改进

- **新增供应商智能合并** — 新增 Claude/Codex/Gemini 供应商时，自动合并本地已有配置文件中的非表单字段，避免切换供应商时丢失自定义配置
- **MCP 编辑器名称字段** — Claude MCP 编辑界面的名称输入框不再置灰，支持重命名
- **Debug 模式跳过更新检查** — Debug 包启动时不再自动检查 GitHub 版本更新，避免开发时频繁请求 API

### 🐛 问题修复

- **Codex MCP 开关生效** — 修复 Codex MCP 服务器 toggle 开关无法正确写入 `enabled = false` 到 config.toml 的问题
- **Codex 切换提示** — 切换 Codex MCP 启用状态时 Toast 提示"请重启 Codex 以使配置生效"


## v1.7.1

### 🐛 问题修复

- **Cursor MCP 编辑限制解除**：移除 Cursor 添加/编辑 MCP 服务器时的拦截提示，现在可以直接在应用内配置 Cursor 的 MCP，无需跳转到 Cursor 客户端
- **Workspace 项目图标错位修复**：修复新增 MCP 配置后返回首页时，Cursor Workspace 列表中项目图标显示错乱的问题


## v1.7.0

### ✨ 新增特性

- **会话管理器** — 全新三栏布局，支持浏览和管理 Claude Code / Codex 本地会话记录
  - 左栏：项目列表（自动合并重复项目，显示最近更改时间）
  - 中栏：所选项目的会话列表，支持按 Provider 筛选
  - 右栏：会话详情，查看完整对话内容
  - 支持恢复会话（macOS Terminal / iTerm2，Windows PowerShell / CMD / Windows Terminal）
  - 支持删除会话、复制恢复命令
- **全局出站代理** — 设置 → 高级，配置 HTTP / SOCKS5 代理用于访问 GitHub 等外部服务
  - 支持扫描本地常见代理端口（Clash、ClashX Pro 等）
  - 支持一键测试代理连通性
  - 可选配置用户名/密码认证
- **首页更新横幅** — 应用启动时自动检测新版本，首页顶部显示更新提示横幅
  - 点击「更新」按钮直接触发自动更新流程
  - 可手动关闭横幅
- **更新进度遮罩** — 自动更新时显示全屏遮罩弹窗，圆环进度指示器实时显示下载百分比
- **MCP 诊断优化** — MCP 失败诊断弹窗改为生成 Clash Verge JS 脚本，支持一键导入规则

### 🚀 优化改进

- 更新检测支持代理：配置了出站代理后，检查更新和下载更新均通过代理访问 GitHub
- 更新检测改为每次启动应用时自动检测，无需等待 24 小时间隔
- 更新下载改为流式传输，实时显示下载进度而非一次性加载到内存
- 检查更新 Toast 提示增加代理配置引导文案
- 调试工具箱新增「更新进度 UI 演示」和「伪造新版本横幅」调试按钮
- 终端启动支持检测本地已安装的终端应用（iTerm2 / Windows Terminal 等）

### 📝 文档

- 新增会话管理功能设计文档
- 新增代理配置功能设计文档
- 新增 Clash Verge 合并机制原理文档
- 更新自动更新机制文档（补充代理支持、流式下载、进度 UI 原理）


## v1.6.0

### ✨ 新增特性

- **SQLite 全量配置存储**：Provider 配置从配置文件迁移至 SQLite，新增 `configContent` 列存储完整配置文件内容（JSON/TOML/ENV），解决非选中供应商编辑数据错误问题
- **配置冲突解决 UI**：编辑已激活供应商时自动检测 SQLite 与本地配置文件是否一致，不一致时显示双栏对比界面，支持"使用本地文件"或"使用已保存数据"
- **项目级 MCP 失败诊断**：新增项目级 MCP 失败诊断弹窗，检测到失败时提供一键导入 Clash 代理规则
- **Claude 配置编辑器**：新增可视化 Claude settings.json 编辑器组件，支持结构化+源码双模式
- **Remote Claw 通知模式**：AskUserQuestion 改为仅通知模式，不再阻塞等待用户确认

### 🚀 优化改进

- **供应商预设 YAML 化**：供应商预设配置迁移至 YAML 格式管理
- **Remote Claw 外部处理检测**：新增外部处理检测机制
- **Codex 环境检测增强**：检测到 Codex 从 fnm 安装时，额外显示当前 Node 版本号
- **端口复用优化**：RemoteClawService 支持 Hot Restart 跨重启的优雅端口复用

### 🐛 问题修复

- 修复 Flutter run 在交互式 shell 中的 tty 输入挂起问题
- 修复 Codex reconcile 硬编码 `model_provider != 'custom'` 导致非 custom 供应商重载后被重置
- 修复配置文件二次合并导致预览与文件不一致
- 修复 Gemini 配置预览不显示已有 .env 内容
- 修复 Codex auth.json 异步加载导致滚动跳动


## v1.5.0

### ✨ 新增特性

- **Remote Claw 远程审批**：全新功能模块，在本机启动 HTTP 服务接收 Claude Code Hook 的权限请求，转发到手机端进行远程审批
  - 支持钉钉机器人和 Telegram Bot 两种通知渠道
  - 支持 Tailscale 内网穿透，从任意网络审批
  - 一键安装/卸载 Hook 脚本，自动配置 `~/.claude/settings.json`
  - 首页新增 Remote Claw 快捷入口

- **Cursor Workspace 级 MCP 管理**：适配 Cursor 将 MCP 启用/禁用状态迁移至 workspace 级 SQLite 数据库的变更
  - 自动检测本机 Cursor 版本，智能判断 MCP 禁用管理机制（mcp.json / SQLite）
  - MCP 列表页新增「Workspace 项目级配置」分区，展示 `~/.cursor/projects` 下的所有项目
  - 支持逐项目查看和切换各 MCP 服务的启用/禁用状态
  - 开关操作弹窗解释正反向同步差异，提供「在此操作」和「在 Cursor 中设置」两种路径
  - 「在 Cursor 中设置」包含双步骤漫游引导图，倒计时自动关闭后打开对应项目窗口

- **编辑器版本兼容框架**：新增 `editor_features.yaml` 数据驱动配置，按编辑器和版本区间记录功能机制变更，便于后续扩展

- **插件开关修复**：新增一键修复功能，解决插件已安装但无法以 slash command 调用的问题

### 🚀 优化改进

- 新增 `.claude/commands` 发版命令和 release notes 草拟命令，标准化发布流程
- 新增编辑器版本变更文档目录 `docs/editor-changes/`，按编辑器分类记录配置机制变更

### 🐛 问题修复

- 修复设置页 API 测速按钮国际化 key 引用错误


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
