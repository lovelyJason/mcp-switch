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
