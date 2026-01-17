<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# MCP Switch 项目规范

## UI 规范

### macOS 红绿灯区域

这是一个 macOS 原生应用，窗口左上角有红绿灯按钮（关闭、最小化、最大化）。

**强制规则**：
- 所有新页面的 AppBar 返回按钮、标题、左侧内容必须与红绿灯保持足够距离
- 最小左边距：**70px**（参考 `main_window.dart` 中的 `SizedBox(width: 70)`）
- 新建页面时，AppBar 的 `leading` 或 `titleSpacing` 必须考虑红绿灯占位

**推荐写法**（带返回按钮的子页面）：
```dart
AppBar(
  automaticallyImplyLeading: false,
  titleSpacing: 0,
  title: Row(
    children: [
      const SizedBox(width: 70), // 红绿灯占位，必须！
      IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      const SizedBox(width: 8),
      Text('页面标题'),
    ],
  ),
)
```

**简单写法**（无返回按钮的页面）：
```dart
AppBar(
  titleSpacing: 70, // 为红绿灯留出空间
  title: Text('页面标题'),
)
```

### 下拉菜单样式

使用 `PopupMenuButton` 时，保持统一的现代风格：
```dart
PopupMenuButton(
  offset: const Offset(0, 8),  // 往下偏移
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  ),
  elevation: 4,
  shadowColor: Colors.black26,
)
```

### 主题色与配色规范

**主题色**：`Colors.deepPurple`（深紫色）

**图标和按钮配色规则**：
- **主操作按钮/图标**：使用 `Colors.deepPurple` 或 `Colors.deepPurple.shade300`
- **成功状态**：`Colors.green`
- **警告状态**：`Colors.orange`
- **危险/删除操作**：`Colors.red` 或 `Colors.redAccent`
- **禁用状态**：`Colors.grey.shade600`

**TextButton.icon 标准写法**：
```dart
TextButton.icon(
  onPressed: () {},
  icon: const Icon(Icons.xxx, size: 14),  // 统一使用 size: 14
  label: Text(S.get('button_text')),
  style: TextButton.styleFrom(
    foregroundColor: Colors.deepPurple,  // 必须使用主题色
    textStyle: const TextStyle(fontSize: 12),
  ),
)
```

**禁止**：
- 使用默认蓝色图标（如不指定颜色的 `Icon(Icons.open_in_new)`）
- 不同按钮使用不同的图标大小
- 在同一行按钮中混用不同颜色风格

### 确认弹窗

**禁止**直接使用原生 `AlertDialog`，必须使用封装好的 `CustomConfirmDialog`。

**位置**：`lib/ui/components/custom_dialog.dart`

**特性**：
- 支持深色/浅色模式自动切换
- 圆角卡片样式 + 阴影
- 缩放 + 淡入动画
- 返回 `Future<bool?>` 可获取用户选择结果

**用法**：
```dart
import 'components/custom_dialog.dart';

// 方式1：使用返回值
final confirmed = await CustomConfirmDialog.show(
  context,
  title: S.get('confirm_delete_title'),
  content: S.get('confirm_delete_content'),
  confirmText: S.get('delete'),
  cancelText: S.get('cancel'),
  confirmColor: Colors.red,  // 危险操作用红色
);
if (confirmed == true) {
  // 执行删除
}

// 方式2：使用回调（兼容旧代码）
CustomConfirmDialog.show(
  context,
  title: '删除',
  content: '确定要删除吗？',
  confirmColor: Colors.redAccent,
  onConfirm: () {
    // 执行删除
  },
);
```

**参数说明**：
| 参数 | 类型 | 说明 |
|------|------|------|
| `title` | String | 弹窗标题（必填） |
| `content` | String | 弹窗内容（必填） |
| `confirmText` | String | 确认按钮文字，默认 'Confirm' |
| `cancelText` | String | 取消按钮文字，默认 'Cancel' |
| `confirmColor` | Color | 确认按钮颜色，默认蓝色，危险操作用 `Colors.red` |
| `onConfirm` | VoidCallback? | 点击确认后的回调（可选） |

## 国际化

- 所有用户可见字符串必须放在 `lib/l10n/locales/zh.json` 和 `en.json`
- 通过 `S.get('key')` 访问

## 代码行数控制规范

### 文件行数限制

| 文件类型 | 最大行数 | 说明 |
|---------|---------|------|
| **Widget 文件** | 200 行 | 单个 Widget 类文件 |
| **Page 页面文件** | 标准300 行, 900多是极限，不能超过1000行 | 包含多个子 Widget 的页面 |
| **Service/Repository** | 250 行 | 业务逻辑层 |
| **Model 文件** | 150 行 | 数据模型定义 |
| **Utils 工具文件** | 200 行 | 工具函数集合 |

### 函数/方法行数限制

| 类型 | 最大行数 | 说明 |
|------|---------|------|
| **build() 方法** | 50 行 | 超过则拆分子 Widget |
| **普通方法** | 30 行 | 超过则拆分为多个私有方法 |
| **initState/dispose** | 20 行 | 初始化逻辑复杂时提取到单独方法 |

### 拆分策略

**Widget 拆分原则：**
- 单个 Widget 超过 200 行 → 拆分为多个子 Widget
- build() 方法超过 50 行 → 提取 `_buildXxx()` 私有方法或独立 Widget
- 重复 UI 出现 3 次 → 提取为独立组件

### 代码检查清单

- [ ] Widget 文件是否超过 200 行？
- [ ] build() 方法是否超过 50 行？
- [ ] 是否有超过 30 行的方法需要拆分？
- [ ] 重复代码是否已提取为独立组件？
- [ ] 业务逻辑是否与 UI 分离？

### 违规处理

当文件超出行数限制时，必须进行以下操作之一：
1. **提取子 Widget**：将 UI 片段提取为独立 Widget 类
2. **提取 Mixin**：将可复用逻辑提取到 Mixin
3. **提取 Controller/Bloc**：将业务逻辑移至状态管理层
4. **提取工具方法**：将通用方法移至 utils

### 例外情况

以下情况可适当放宽限制（需在代码中注释说明原因）：
- 自动生成的代码（如 freezed、json_serializable）
- 复杂动画序列代码
- 大量静态配置数据