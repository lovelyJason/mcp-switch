# MCP Switch

**macOS 下的一站式 AI 编辑器 MCP 配置管理工具**

<img width="256" height="256" alt="logo" src="https://github.com/user-attachments/assets/92c9ff30-0898-41a8-965c-218579661a81" />

<br />

**软件界面**

<img width="900" height="600" alt="image" src="https://github.com/user-attachments/assets/3bc8ab5e-8c21-4303-98a0-1ed7fc102f3d" />

<img width="900" height="600" alt="image" src="https://github.com/user-attachments/assets/e4d7a0d2-0b43-43bd-bca3-ffa4151bce6a" />

MCP Switch 是一个专为 macOS 设计的 Flutter 应用，旨在帮助开发者高效管理多个 AI 代码编辑器的 **MCP (Model Context Protocol)** 配置文件。

在不同的 AI 辅助开发工具（如 Cursor, Windsurf, Claude Code 等）之间切换时，管理分散且格式各异的 MCP 配置往往令人头疼。MCP Switch 提供了一个统一、现代化的界面，让你能够集中管理这些配置，并只需一键即可应用到指定的编辑器中。

## ✨ 核心功能

- **🔌 多编辑器支持**
  完美支持主流 AI 编辑器和工具，包括：
  - Cursor
  - Windsurf
  - Claude Code
  - Codex
  - Antigravity
  - Gemini



- **🛠 高级路径管理**
  支持自定义每个编辑器的配置文件读取/写入路径。这意味着你可以将配置指向 Dropbox 或 iCloud 同步目录，实现跨设备同步。

- **🌐 多语言支持**
  内置中文与英文界面，根据系统语言自动切换，或在设置中手动指定。

- **🎨 现代 macOS 体验**
  - 精心设计的无边框窗口与自定义标题栏。
  - **深色模式支持**：完美适配 macOS 深色外观。
  - **托盘常驻**：支持最小化到菜单栏，随时快速切换配置。
  - **开机自启**：支持配置随系统启动。

- **📝 可视化配置编辑**
  - 提供表单模式与 JSON/TOML 代码模式双向绑定，**Codex 支持自动生成 TOML**。
  - 内置常见 MCP Server (Figma, Chrome DevTools 等) 预设，一键添加。
  - **Context7 深度集成**：支持本地 (`npx`) 与远程 (`serverUrl`) 双模式切换，自动适配 API Key 配置。
  - 特别针对 **Claude Code** 优化，支持全局配置 (`~/.claude.json`) 管理。

- **🤖 AI 提示词与规则管理 (New)**
  - **Claude Code 提示词管理**：可视化管理 System Prompts，自动同步到 `CLAUDE.md`，支持开关与版本回退。
  - **全局规则 (Rules)**：统一管理 windsurf,antigravity,gemini 等编辑器规则文

## 🚀 快速开始

### 运行环境
- macOS
- Flutter SDK

### 安装与运行
```bash
# 克隆项目
git clone https://github.com/lovelyJason/mcp-switch.git

# 进入目录
cd mcp-switch

# 安装依赖
flutter pub get

# 运行应用
# 运行应用 (Debug)
flutter run -d macos

# 打包发布 (Release)
flutter build macos --release
# 生成的应用位于: build/macos/Build/Products/Release/mcp_switch.app
```

### 自动化发布
内置版本管理脚本，自动从 GitHub 获取最新 Release 并递增版本号：
```bash
python3 scripts/bump_version.py
```

## 🛠 技术栈
- **Framework**: Flutter (macOS)
- **State Management**: Provider
- **Storage**: SharedPreferences / JSON File System
- **Windowing**: window_manager

## 🗺️ 路线图 (Roadmap)

我们致力于打造 AI 时代最强的**编辑器伴侣**，不仅限于 MCP 管理。

### Phase 1: 核心增强 (In Progress)
- [x] **自动化构建流**：`bump_version.py` 自动版本递增与常量生成
- [x] **Context7 深度适配**：支持 Local/Remote 模式切换与 JSON/TOML 智能生成
- [x] **Claude Code Prompt 管理**：可视化管理 `CLAUDE.md`
- [ ] **多配置方案 (Profiles)**
  - 为同一个编辑器创建多套 MCP 配置（如 "公司项目" vs "个人项目"），一键秒切。

### Phase 2: 生态互联
- [ ] **配置云同步**
  - 支持 iCloud / GitHub Gist 同步配置，换电脑无缝衔接。
- [ ] **MCP Server 市场**
  - 内置精选 MCP Server 列表，一键 `npx` 安装与配置。
- [ ] **AI 提示词中心 (Prompts Hub)**
  - 社区共享优质 System Prompts（如 "爆栈侠"、"代码审计员"）。
  - 一键下载并应用到当前项目规则。

### Phase 3: AI 编辑器增强工具箱
- [ ] **项目规则生成器 (Rules Generator)**
  - 基于 AI 分析当前项目结构（Vue/React/Flutter），自动生成最佳实践的 `.cursorrules` 或 `CLAUDE.md`。
- [ ] **本地知识库索引 (Local RAG)**
  - 提供轻量级工具，将本地文档/代码库索引为 MCP Server，供编辑器直接调用查询。
- [ ] **模型与密钥管理**
  - 统一管理 OpenAI/Anthropic/DeepSeek API Keys。
  - 本地代理转发，实现一次配置，所有 AI 编辑器共享 Key。
- [ ] **环境健康检查**
  - 自动检测本地 `npx`、`node`、`python` 环境。
  - 诊断 MCP Server 连接状态与延迟。

## 📄 许可证
[MIT License](LICENSE)


## 图标生成

自动读取您指定的图片，并将其裁剪为 macOS 标准圆角矩形 (Squircle) + 调整尺寸到 1024x1024。
覆盖项目中的 assets/images/logo.png。
自动运行 flutter pub run flutter_launcher_icons 更新原生图标配置。

```bash
pip install -r scripts/requirements.txt

python3 scripts/update_icon.py <您的新图片路径>
```
