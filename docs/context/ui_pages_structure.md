# UI Pages 目录结构

## 概述

2025-01-19 重构了 UI 目录结构，将所有页面（Screen）文件按功能分类到 `lib/ui/pages/` 目录下，实现了更清晰的代码组织。

## 重构前

所有 screen 文件平铺在 `lib/ui/` 目录下，`main_window.dart` 包含 912 行代码（头部 UI 内联）。

## 重构后

### 目录结构

```
lib/ui/
├── main_window.dart              # 主窗口（165 行）- 仅包含窗口管理、托盘、退出逻辑
├── components/                   # 通用组件
├── widgets/                      # Widget 组件
└── pages/                        # 页面目录
    ├── home/                     # 首页
    │   ├── home_page.dart        # 首页容器（管理 CLI 状态检测、组合 Header + Banners + Content）
    │   ├── home_header.dart      # 首页头部（标题、设置、编辑器选择器、终端、刷新、添加按钮）
    │   └── header_action_buttons.dart  # 胶囊按钮组（根据编辑器类型显示不同按钮）
    │
    ├── mcp_config/               # MCP 配置
    │   ├── config_list_screen.dart     # 配置列表
    │   ├── mcp_server_edit_screen.dart # MCP 服务器编辑
    │   └── project_detail_screen.dart  # 项目详情
    │
    ├── plugins/                  # 插件页（各编辑器 Skills）
    │   ├── claude_code_skills_screen.dart
    │   ├── codex_skills_screen.dart
    │   ├── gemini_skills_screen.dart
    │   ├── antigravity_skills_screen.dart
    │   ├── claude_code_skills/   # Claude Skills 子目录
    │   │   ├── components/       # 组件（如 hover_popover.dart）
    │   │   └── dialogs/          # 弹窗（part 文件）
    │   ├── codex_skills/dialogs/
    │   ├── gemini_skills/dialogs/
    │   └── antigravity_skills/dialogs/
    │
    ├── settings/                 # 设置页
    │   └── settings_screen.dart
    │
    ├── rules/                    # Rules 页
    │   ├── rules_screen.dart
    │   └── rule_edit_screen.dart
    │
    └── prompts/                  # Prompts 页
        ├── claude_prompts_screen.dart
        └── claude_prompt_edit_screen.dart
```

### 关键改动

#### 1. main_window.dart 精简

**改动前**：912 行（包含完整的头部 UI 内联代码）

**改动后**：165 行，仅保留：
- 窗口管理（WindowListener）
- 托盘管理（TrayListener）
- 退出逻辑（_attemptAppExit）
- 渲染 `HomePage` 组件

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    key: _scaffoldKey,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: HomePage(scaffoldKey: _scaffoldKey),
  );
}
```

#### 2. 首页组件拆分

| 组件 | 职责 |
|------|------|
| `HomePage` | 管理 CLI 安装状态检测、组合 Header + Banners + Content |
| `HomeHeader` | 渲染头部 UI（标题、设置、编辑器选择器、操作按钮、终端、刷新、添加） |
| `HeaderActionButtons` | 根据编辑器类型渲染不同的胶囊按钮组 |

#### 3. HeaderActionButtons 按钮逻辑

| 编辑器 | 显示的按钮 |
|--------|-----------|
| Claude | Skills + Prompt + More（Rules 在下拉菜单） |
| Codex | Skills only |
| Gemini | Skills only |
| Antigravity | Skills + Rules |
| Others (Cursor, Windsurf) | Rules only |

#### 4. global_keys.dart 提取

将 `globalScaffoldKey` 和 `globalNavigatorKey` 从 `main.dart` 提取到 `lib/utils/global_keys.dart`，避免 UI 组件反向依赖入口文件。

```dart
// lib/utils/global_keys.dart
import 'package:flutter/material.dart';

final GlobalKey<ScaffoldState> globalScaffoldKey = GlobalKey<ScaffoldState>();
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();
```

### Import 路径规则

从 `pages/xxx/` 目录引用其他模块：

| 目标 | 路径 |
|------|------|
| models | `../../../models/xxx.dart` |
| services | `../../../services/xxx.dart` |
| l10n | `../../../l10n/s.dart` |
| utils | `../../../utils/xxx.dart` |
| components | `../../components/xxx.dart` |
| widgets | `../../widgets/xxx.dart` |
| 同级 pages | `../xxx/xxx_screen.dart` |
| 同目录文件 | `xxx.dart` |

### 行数统计

| 目录 | 总行数 |
|------|--------|
| main_window.dart | 165 |
| pages/home/ | 758 |
| pages/mcp_config/ | 1,631 |
| pages/plugins/ | 11,666 |
| pages/settings/ | 1,775 |
| pages/rules/ | 676 |
| pages/prompts/ | 687 |

### 后续扩展

1. **动态内容切换**：`HomePage` 的 `_buildContent()` 可扩展为根据 state 渲染不同页面
2. **components 整理**：后续可将 components 按功能分子目录（banners/、terminal/、chat/、cards/、common/）
3. **新增页面**：在 `pages/` 下创建对应目录，遵循相同的组织规范
