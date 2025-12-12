# MCP Switch

**macOS 下的一站式 AI 编辑器 MCP 配置管理工具**

![Logo](assets/icon.png)

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

- **⚙️ 多配置方案 (Profiles)**
  为同一个编辑器创建多套 MCP 配置。例如，你可以有一套用于 "公司项目" 的配置（包含内部 API 的 MCP），和一套用于 "开源项目" 的配置。在列表视图中点击即可一键激活。

- **🛠 高级路径管理**
  支持自定义每个编辑器的配置文件读取/写入路径。这意味着你可以将配置指向 Dropbox 或 iCloud 同步目录，实现跨设备同步。

- **� 多语言支持**
  内置中文与英文界面，根据系统语言自动切换，或在设置中手动指定。

- **�🎨 现代 macOS 体验**
  - 精心设计的无边框窗口与自定义标题栏。
  - **深色模式支持**：完美适配 macOS 深色外观。
  - **托盘常驻**：支持最小化到菜单栏，随时快速切换配置。
  - **开机自启**：支持配置随系统启动。

- **📝 可视化配置编辑**
  - 提供表单模式与 JSON/TOML 代码模式双向绑定。
  - 内置常见 MCP Server (Figma, Chrome DevTools 等) 预设，一键添加。
  - 特别针对 **Claude Code** 优化，支持全局配置 (`~/.claude.json`) 管理。

## 📸 截图

*(此处可添加应用截图)*

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

## 🛠 技术栈
- **Framework**: Flutter (macOS)
- **State Management**: Provider
- **Storage**: SharedPreferences / JSON File System
- **Windowing**: window_manager

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