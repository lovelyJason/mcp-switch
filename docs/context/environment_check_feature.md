# 环境检查功能

> 本文档记录 MCP Switch 设置页中「环境检查」Tab 的设计与实现。

---

## 一、功能特性

| 特性 | 说明 |
|------|------|
| **AI 工具检测** | 检测 Claude Code、Codex、Gemini CLI、Antigravity、Cursor、Windsurf |
| **版本获取** | CLI 工具通过 `--version` 获取版本号 |
| **路径显示** | CLI 工具通过 `which` 获取可执行文件路径，IDE 显示 .app 路径 |
| **Node 运行时识别** | Codex 若从 `fnm` 安装路径启动，额外显示当前 Node 版本号 |
| **内存缓存** | 检测结果缓存在模块级静态变量，再次打开 Tab 不重复检测 |
| **手动刷新** | 提供"重新检测"按钮，清除缓存重新执行全部检测 |

---

## 二、文件结构

| 文件 | 职责 |
|------|------|
| `lib/ui/pages/settings/environment_check_tab.dart` | 环境检查 Tab 组件（UI + 检测逻辑） |
| `lib/ui/pages/settings/settings_screen.dart` | 宿主页面，TabController 管理 5 个 Tab |
| `lib/utils/platform_utils.dart` | 底层命令执行工具（`runCommand`） |

---

## 三、检测工具列表

| 工具 | 类型 | 检测方式 | 图标 |
|------|------|---------|------|
| Claude Code | CLI | `claude --version` + `which claude` | `assets/icons/editors/claude.svg` |
| Codex | CLI | `codex --version` + `which codex` | `assets/icons/editors/chatgpt.svg` |
| Gemini CLI | CLI | `gemini --version` + `which gemini` | `assets/icons/editors/gemini.svg` |
| Antigravity | CLI | `antigravity --version` + `which antigravity` | `assets/icons/editors/antigravity.svg` |
| Cursor | macOS App | `Directory('/Applications/Cursor.app').exists()` | `assets/icons/editors/cursor.svg` |
| Windsurf | macOS App | `Directory('/Applications/Windsurf.app').exists()` | `assets/icons/editors/windsurf.svg` |

---

## 四、核心流程

```
EnvironmentCheckTab.initState()
        │
        ├── 有缓存？──── 是 ──→ 直接使用 _cachedResults
        │
        └── 无缓存 ──→ _runChecks()
                         │
                         ├── Future.wait([...]) 并行检测 6 个工具
                         │    ├── _checkCliTool('Claude Code', 'claude')
                         │    ├── _checkCliTool('Codex', 'codex')
                         │    ├── _checkCliTool('Gemini CLI', 'gemini')
                         │    ├── _checkCliTool('Antigravity', 'antigravity')
                         │    ├── _checkAppInstalled('Cursor', '/Applications/Cursor.app')
                         │    └── _checkAppInstalled('Windsurf', '/Applications/Windsurf.app')
                         │
                         ├── 结果写入 _cachedResults（模块级静态变量）
                         └── setState() 刷新 UI
```

---

## 五、缓存策略

- **缓存位置**：模块级顶层变量 `List<_ToolCheckResult>? _cachedResults`
- **缓存生命周期**：应用进程存活期间一直有效
- **缓存失效**：点击"重新检测"按钮时清除并重新执行检测
- **不持久化**：不写入磁盘，应用重启后自动重新检测

---

## 六、Tab 位置

设置页 Tab 顺序：**通用 | AI设置 | 高级 | 环境检查 | 关于**

`TabController(length: 5)`，环境检查为第 4 个 Tab（index=3）。

---

## 七、UI 结构

每个工具渲染为一张卡片，包含：

```
┌─────────────────────────────────────────────────────┐
│  [SVG图标]  名称                    [版本号]  [状态] │
│             /usr/local/bin/claude                    │
│             Node v18.20.0 · fnm                      │
└─────────────────────────────────────────────────────┘
```

- **图标**：28x28 SVG，Claude 使用品牌橙色 `#d97757`，暗色模式其他图标使用白色
- **名称**：14px 加粗
- **路径**：11px Menlo 等宽字体，灰色
- **Node 运行时**：Codex 若检测到 `fnm` 安装来源，额外显示 `Node vX.Y.Z · fnm`
- **版本号**：灰色圆角背景标签，11px Menlo
- **状态标签**：绿色「已安装」/ 红色「未安装」

---

## 八、国际化 Key

| Key | 中文 | 英文 |
|-----|------|------|
| `env_check` | 环境检查 | Environment |
| `env_check_title` | AI 工具环境检查 | AI Tools Environment Check |
| `env_check_desc` | 检测本地已安装的 AI 编辑器和 CLI 工具 | Detect locally installed AI editors and CLI tools |
| `env_check_refresh` | 重新检测 | Re-check |
| `env_checking` | 正在检测环境... | Checking environment... |
| `env_installed` | 已安装 | Installed |
| `env_not_installed` | 未安装 | Not Installed |
