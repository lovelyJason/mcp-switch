# Claude Code 斜线命令格式规范

## 概述

Claude Code 的斜线命令分为两类：**Skills** 和 **Commands**，它们的格式不同。

## 格式区别

| 类型 | 格式 | 示例 |
|------|------|------|
| **Skills** | `/skill名称` | `/brainstorm`、`/execute-plan`、`/write-plan` |
| **Commands** | `/插件名:命令名` | `/superpowers:brainstorm`、`/superpowers:write-plan` |

## 详细说明

### Skills（技能）

Skills 是插件中定义的独立技能，通过 `SKILL.md` 文件声明。

**调用格式**：
```
/<skill-name>
```

**特点**：
- 不带插件前缀
- 直接使用技能名称
- 文件位置：`插件目录/skills/<skill-name>/SKILL.md`

**示例**：
- `/brainstorm` - 头脑风暴
- `/execute-plan` - 执行计划
- `/write-plan` - 编写计划

### Commands（命令）

Commands 是插件中定义的命令，通过 `commands/` 目录下的 `.md` 文件声明。

**调用格式**：
```
/<plugin-name>:<command-name>
```

**特点**：
- 需要带插件名前缀
- 使用冒号 `:` 分隔插件名和命令名
- 文件位置：`插件目录/commands/<command-name>.md`

**示例**：
- `/superpowers:brainstorm` - superpowers 插件的 brainstorm 命令
- `/superpowers:write-plan` - superpowers 插件的 write-plan 命令
- `/flow-next:work` - flow-next 插件的 work 命令

## 代码实现

在 `plugin_detail_dialog.dart` 中：

```dart
// Skills 格式：/skill名称（不带冒号）
Widget _buildSkillItem(Map<String, String> skill, bool isDark) {
  final skillName = skill['name'] ?? '';
  final command = '/$skillName';  // 例：/brainstorm
  // ...
}

// Commands 格式：/插件名:命令名（带冒号）
Widget _buildCommandItem(Map<String, String> cmd, bool isDark) {
  final name = cmd['name'] ?? '';
  final pluginName = widget.plugin.name.split('@').first;
  final command = '/$pluginName:$name';  // 例：/superpowers:brainstorm
  // ...
}
```

## UI 展示

在插件详情弹窗中：
- **Skills 区块**：显示 `/skill名称` 格式
- **Commands 区块**：显示 `/插件名:命令名` 格式
- 点击复制按钮会复制正确格式的命令到剪贴板

## 注意事项

1. **不要混淆**：Skills 和 Commands 虽然都是斜线命令，但格式完全不同
2. **复制时注意**：确保复制的是正确格式，否则 Claude Code 无法识别
3. **插件名提取**：从 `plugin.name` 中提取（去掉 `@scope` 后缀）