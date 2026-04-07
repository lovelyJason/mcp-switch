# Codex 插件安装机制

## 概述

Codex（OpenAI CLI 工具）的插件安装机制与 Claude 不同，**没有** `codex plugin install <name>` 这样的 CLI 命令。插件安装只能通过交互式环境或 App Server 协议完成。

## 插件来源

### 1. 官方 OpenAI Curated（`openai-curated`）

- **数据文件**：`~/.codex/.tmp/plugins/.agents/plugins/marketplace.json`
- **同步机制**：Codex 启动时通过 `startup_sync.rs` 从 `openai/plugins` 仓库同步到 `~/.codex/.tmp/plugins`
- **marketplace 标识**：`openai-curated`（硬编码常量 `OPENAI_CURATED_MARKETPLACE_NAME`）
- **展示名**：`marketplace.json` 中 `interface.displayName`，通常为 `"OpenAI Curated"` 或 `"Codex official"`

### 2. OSK 第三方 Repo

- **数据目录**：`~/.osk/repos/<repo-name>/plugins/<plugin-name>/`
- **manifest 文件**：`.codex-plugin/plugin.json` 或 `plugin.json`
- **marketplace 标识**：repo 目录名

## 安装方式

### 方式 1：交互式 REPL（唯一的用户交互方式）

```
$ codex
> /plugins          # 输入斜杠命令
→ 浏览插件列表
→ 选择某个插件查看详情
→ 选择 "Install plugin"（选项 2）
```

**源码流程**：
1. `chatwidget/plugins.rs` → `add_plugins_output()` → 展示可搜索的插件列表
2. 选中插件 → `FetchPluginDetail` → 展示详情页，包含 "Install plugin" 选项
3. 点击安装 → `FetchPluginInstall { marketplace_path, plugin_name }` 事件
4. `app.rs` → `fetch_plugin_install()` → 发送 `ClientRequest::PluginInstall` RPC
5. `codex_message_processor.rs` → `plugin_install()` → `PluginsManager::install_plugin()`
6. `manager.rs` → `resolve_marketplace_plugin()` → `install_resolved_plugin()`

### 方式 2：App Server JSON-RPC（程序化调用）

连接运行中的 `codex app-server`（stdio/ws），发送 `plugin/install` 请求：

```json
{
  "method": "plugin/install",
  "params": {
    "marketplacePath": "/absolute/path/to/marketplace.json的父目录",
    "pluginName": "plugin-name",
    "forceRemoteSync": false
  }
}
```

**协议定义**：`codex-rs/app-server-protocol/schema/json/v2/PluginInstallParams.json`

### 方式 3：OSK CLI（仅限第三方 repo 插件）

```bash
osk plugin install <plugin-name>@<marketplace-repo> -t codex
```

此命令仅适用于 `~/.osk/repos/` 下注册的第三方 marketplace，**不适用于** `openai-curated` 官方插件。

## 安装本质

无论哪种方式，安装过程都包含两步：

### 1. 复制插件到缓存

```
~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/
```

- 官方插件的 version 使用 `read_curated_plugins_sha`（与同步的 SHA 一致）
- 源码位置：`codex-rs/core/src/plugins/store.rs`

### 2. 写入 config.toml

```toml
[plugins."<name>@<marketplace>"]
enabled = true
```

- 通过 `ConfigService::write_value` 写入 `~/.codex/config.toml`
- 键路径：`plugins.<plugin_id.as_key()>`，其中 `as_key()` 格式为 `{plugin_name}@{marketplace_name}`
- 示例：`[plugins."notion@openai-curated"]`
- 源码位置：`codex-rs/core/src/plugins/manager.rs` 第 558-568 行

## MCP Switch 中的处理

在 `plugin_section.dart` 中：

| 插件类型 | marketplace 值 | 点击下载按钮行为 |
|---------|---------------|----------------|
| **官方 OpenAI Curated** | `openai-curated` | Toast 提示用户去 Codex REPL 中安装（`/plugins`） |
| **OSK 第三方 Repo** | repo 目录名 | 打开侧边终端执行 `osk plugin install <name>@<repo> -t codex` |
| **已安装插件** | — | 不显示下载按钮 |

## 关键源码文件（Codex 仓库）

| 文件 | 作用 |
|------|------|
| `codex-rs/tui/src/chatwidget/plugins.rs` | `/plugins` UI、安装菜单交互 |
| `codex-rs/tui/src/app.rs` | `fetch_plugin_install()` → 发送 RPC |
| `codex-rs/app-server/src/codex_message_processor.rs` | `plugin_install()` → 调用 PluginsManager |
| `codex-rs/core/src/plugins/manager.rs` | `install_plugin()` → `install_resolved_plugin()`，核心逻辑 |
| `codex-rs/core/src/plugins/store.rs` | 插件文件复制到缓存目录 |
| `codex-rs/core/src/plugins/startup_sync.rs` | 启动时同步 `openai/plugins` 到本地 |
| `codex-rs/plugin/src/plugin_id.rs` | `as_key()` → `{plugin}@{marketplace}` 格式 |
| `codex-rs/app-server-protocol/schema/json/v2/PluginInstallParams.json` | RPC 参数定义 |
