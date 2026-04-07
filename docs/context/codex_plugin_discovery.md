# Codex 插件发现机制

## 概述

Codex Skills 管理页的 Marketplace Plugins 区域，通过**纯文件读取**发现所有可用插件及其安装状态，不依赖任何 CLI 命令。插件按 marketplace 来源分组展示，每个插件标注"已安装"或"可用"状态。

## 数据源

### 来源 1：OpenAI 官方 marketplace

- **文件**：`~/.codex/.tmp/plugins/.agents/plugins/marketplace.json`
- **产生时机**：Codex CLI 首次运行或 `codex plugin list` 时自动拉取
- **结构**：

```json
{
  "name": "openai-curated",
  "interface": { "displayName": "Codex official" },
  "plugins": [
    {
      "name": "linear",
      "category": "Productivity",
      "policy": { "installation": "AVAILABLE" }
    }
  ]
}
```

- **解析逻辑**：读取 `plugins[]` 数组，取 `name` 和 `category`，`displayName` 由 kebab-case 转 Title Case

### 来源 2：osk 注册的 marketplace repos

- **目录**：`~/.osk/repos/<repo-name>/plugins/<plugin-name>/`
- **产生时机**：用户通过 `openskills marketplace add <git-url>` 注册后，仓库 clone 到此
- **manifest 路径**（按优先级）：
  1. `<plugin-dir>/.codex-plugin/plugin.json` — Codex 标准 manifest
  2. `<plugin-dir>/plugin.json` — 兜底

```json
{
  "name": "fe-workflow",
  "version": "3.1.1",
  "description": "...",
  "interface": {
    "displayName": "FE Workflow",
    "shortDescription": "...",
    "category": "Coding",
    "brandColor": "#0F766E"
  }
}
```

- **解析逻辑**：遍历 `~/.osk/repos/` 下每个目录的 `plugins/` 子目录，逐个读取 manifest

### 来源 3：已安装状态（config.toml）

- **文件**：`~/.codex/config.toml`
- **格式**：每个已安装的插件对应一个 TOML section：

```toml
[plugins."notion@openai-curated"]
[plugins."tsai-claude-marketplace--fe-workflow@openskills-local"]
```

- **解析逻辑**：正则 `^\[plugins\."([^"]+)"\]` 提取所有条目，截取 `@` 前的部分作为插件名，构成 `Set<String>`
- **匹配**：对于官方插件直接匹配 `name`；对于 osk 插件同时匹配 `<marketplace>--<name>` 和裸 `name`

## 数据流

```
loadGroupedPlugins()
  │
  ├─ _loadInstalledPluginNames()      → Set<String> installed
  │     读取 ~/.codex/config.toml
  │     正则提取 [plugins."xxx@yyy"]
  │
  ├─ _loadOfficialPlugins()           → groups["Codex official"]
  │     读取 marketplace.json
  │     每个 plugin 与 installed 集合比对
  │
  └─ _loadOskRepoPlugins()            → groups["tsai-claude-marketplace"] 等
        遍历 ~/.osk/repos/*/plugins/*/
        读取 plugin.json manifest
        与 installed 集合比对
  │
  └─ 按 marketplace 分组排序返回 Map<String, List<CodexPlugin>>
```

## UI 展示

- **分组头部**：左侧紫色边框 + marketplace 名称 + 插件总数 + 已安装数
- **插件卡片**：3 列网格布局
  - 图标 + displayName + 状态标签（绿色"已安装" / 灰色"可用"）
  - 描述文本
  - 底部：分类标签 + 版本号 + marketplace 来源

## 相关文件

| 文件 | 职责 |
|------|------|
| `lib/services/codex_plugins_service.dart` | 数据发现与聚合 |
| `lib/models/codex_plugin.dart` | CodexPlugin 数据模型 |
| `lib/ui/pages/plugins/codex_skills/sections/plugin_section.dart` | 分组 UI + 卡片渲染 |
| `lib/ui/pages/plugins/codex_skills_screen.dart` | 页面状态管理与加载 |
| `lib/l10n/locales/{zh,en}.json` | i18n 文案 |

## 注意事项

1. **不依赖 CLI**：所有数据通过读取文件系统获取，app 启动即可展示，无需等待 shell 命令
2. **marketplace.json 可能不存在**：用户从未运行过 Codex 时该文件不存在，此时官方组为空
3. **osk repos 可能为空**：用户未注册任何 marketplace 时 `~/.osk/repos/` 不存在或为空
4. **config.toml 格式**：安装名遵循 `<name>@<marketplace>` 约定，其中 osk 安装的插件名会带 `<repo>--` 前缀
