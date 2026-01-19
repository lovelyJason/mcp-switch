# MCP Switch

**macOS 下的一站式 AI 编辑器 MCP 配置管理工具**

不止是MCP， 本软件旨在统一各AI编辑器的操作，提供可视化界面管理各AI编辑器的特性，目标是做一个全能的AI配置工具箱，并能用AI增强AI的能力

<img width="256" height="256" alt="logo" src="https://github.com/user-attachments/assets/92c9ff30-0898-41a8-965c-218579661a81" />

<br />

**软件界面**

<img width="900" height="600" alt="image" src="https://github.com/user-attachments/assets/3bc8ab5e-8c21-4303-98a0-1ed7fc102f3d" />

<img width="900" height="600" alt="image" src="https://github.com/user-attachments/assets/e4d7a0d2-0b43-43bd-bca3-ffa4151bce6a" />

MCP Switch 是一个专为 macOS 设计的 Flutter 应用，旨在帮助开发者高效管理多个 AI 代码编辑器的 **MCP (Model Context Protocol)** 配置文件。

在不同的 AI 辅助开发工具（如 Cursor, Windsurf, Claude Code 等）之间切换时，管理分散且格式各异的 MCP 配置往往令人头疼。MCP Switch 提供了一个统一、现代化的界面，让你能够集中管理这些配置，并只需一键即可应用到指定的编辑器中。

---

### 🌐 多语言支持

内置中文与英文界面，外观主题设置。

### 📝 可视化配置编辑

- 提供表单模式与 JSON/TOML 代码模式双向绑定，**Codex 支持自动生成 TOML**
- 内置常见 MCP Server (Figma, Chrome DevTools 等) 预设，一键添加
- 特别针对 **Claude Code** 优化，支持全局配置管理

### 📋 AI 提示词与规则管理

- **Claude Code 提示词管理**：可视化管理 System Prompts，自动同步到 `CLAUDE.md`
- **全局规则 (Rules)**：统一管理 Windsurf、Antigravity、Gemini 等编辑器规则

## 🆕 最新更新 (2026-01-17)

> **v1.1.0** 重磅更新！新增 Claude Code 插件可视化管理 + AI 智能助手

- 🏪 **插件市场**：支持添加官方/第三方市场，一键安装插件，查看文档和源码
- 🎯 **Skills 管理**：浏览已安装的社区技能，支持文档翻译
- 🤖 **AI 助手**：集成 Claude API，用自然语言管理插件（如 "帮我安装 xxx"）
- 🌐 **内置翻译**：英文文档一键翻译为中文

---

## 🎬 功能演示

### 通过界面安装插件

![可视化安装插件](https://github.com/user-attachments/assets/10e9648e-e939-4a10-8ad2-fc97d838e571)

> 点击浏览插件市场，选择心仪的插件一键安装，支持查看文档和源码。

### 通过 AI 助手安装插件

![chatbot安装插件](https://github.com/user-attachments/assets/9e08a749-b1c3-48fb-9421-a219eb08492b)

> 在 AI 助手中用自然语言描述需求，如 "帮我安装 lua-lsp 插件"，助手自动执行安装。

## ✨ 核心功能

### 🏪 Claude Code 插件市场 (New!)

**一站式插件与 Skills 管理中心**，让 Claude Code 如虎添翼：

- **插件市场 (Marketplace)**
  - 支持添加官方及第三方插件市场
  - 一键浏览、安装、卸载插件
  - 查看插件文档和源码
  - 内置翻译功能，轻松阅读英文文档
 
<img width="900" height="600" alt="image" src="https://github.com/user-attachments/assets/bc40c758-0b54-4023-8f2c-b4d09c70eb01" />

- **社区 Skills 管理**
  - 浏览已安装的社区技能
  - 查看 Skills 使用说明与配置方法
  - 支持文档内容一键翻译

- **使用文档与源码查看**
  - 插件/Skills 详情页展示完整 README
  - 一键跳转 GitHub 查看源码
  - 内置 Markdown 渲染，阅读体验绝佳
 
内部集成了几个免费的翻译引擎，在预览plugin, skill的文档的同时支持对其进行翻译并缓存，这样更方便阅读

<img width="900" height="600" alt="image" src="https://github.com/user-attachments/assets/32e5b5f7-206b-4a5f-80c1-48eb427d4f6d" />



### 🤖 AI 智能助手 (New!)

集成 Claude API 的对话式助手，用自然语言管理你的 Claude Code：

- **对话式操作**：不用记命令，直接说 "帮我安装 xxx 插件"
- **插件安装/卸载**：通过聊天完成插件管理
- **信息查询**：询问已安装插件、市场列表、Skills 信息等
- **Tool Use 支持**：查看命令执行过程，结果可折叠展示
- **历史记录**：聊天记录自动保存，支持导出

## 🗺️ 路线图 (Roadmap)

我们致力于打造 AI 时代最强的**编辑器伴侣**，不仅限于 MCP 管理。

### Phase 1: 核心增强 ✅ Complete
- [x] **MCP 深度适配**：支持 Local/Remote 模式切换与 JSON/TOML 智能生成
- [x] **Claude Code Prompt 管理**：可视化管理 `CLAUDE.md`
- [x] **Claude Code 插件市场**：一键安装/卸载插件，支持文档查看与翻译
- [x] **社区 Skills 管理**：浏览已安装 Skills，查看使用文档
- [x] **AI 智能助手**：集成 Claude API，对话式管理插件和配置

### Phase 2: 生态互联 (In Progress)
- [ ] **多配置方案 (Profiles)**
  - 为同一个编辑器创建多套 MCP 配置（如 "公司项目" vs "个人项目"），一键秒切
- [ ] **配置云同步**
  - 支持 iCloud / GitHub Gist 同步配置，换电脑无缝衔接
- [ ] **AI 提示词中心 (Prompts Hub)**
  - 社区共享优质 System Prompts（如 "爆栈侠"、"代码审计员"）
  - 一键下载并应用到当前项目规则

### Phase 3: AI 编辑器增强工具箱
- [ ] **项目规则生成器 (Rules Generator)**
  - 基于 AI 分析当前项目结构（Vue/React/Flutter），自动生成最佳实践的 `.cursorrules` 或 `CLAUDE.md`
- [ ] **本地知识库索引 (Local RAG)**
  - 提供轻量级工具，将本地文档/代码库索引为 MCP Server，供编辑器直接调用查询
- [ ] **模型与密钥管理**
  - 统一管理 OpenAI/Anthropic/DeepSeek API Keys
  - 本地代理转发，实现一次配置，所有 AI 编辑器共享 Key
- [ ] **环境健康检查**
  - 自动检测本地 `npx`、`node`、`python` 环境
  - 诊断 MCP Server 连接状态与延迟

## 🤖 AI 助手配置

使用 AI 智能助手需要配置 Claude API Key：

1. 打开 **设置** → **AI** 选项卡
2. 输入你的 Claude API Key（获取地址：[console.anthropic.com](https://console.anthropic.com)）
3. 可选：配置自定义 API Base URL（适用于代理场景）
4. 点击界面右下角的 AI 助手悬浮图标开始对话

**支持的命令示例**：
- "帮我安装 lua-lsp 插件"
- "列出所有已安装的插件"
- "有哪些可用的市场？"
- "查看 xxx 插件的信息"

## 📄 许可证

[MIT License](LICENSE)

## 🙌 贡献

欢迎提交 Issue 和 Pull Request！

如果这个项目对你有帮助，请给个 ⭐️ Star 支持一下！

## 📞 联系作者

- GitHub: [@lovelyJason](https://github.com/lovelyJason)
- 即刻: @Jasonhuang

---

## 📦 开发相关

### 图标生成

自动读取指定图片，裁剪为 macOS 标准圆角矩形 (Squircle) + 调整尺寸到 1024x1024：

```bash
pip install -r scripts/requirements.txt
python3 scripts/update_icon.py <您的新图片路径>
```

### 版本发布

```bash
# 自动递增版本号
python3 scripts/bump_version.py

# 构建 Release
flutter build macos --release
```
