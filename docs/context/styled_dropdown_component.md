# StyledDropdown 通用下拉组件

## 概述

`StyledDropdown` 是一个封装的通用下拉选择组件，基于 `PopupMenuButton` 实现，比原生 `DropdownButton` 更紧凑美观，自动适配深色/浅色主题。

## 文件位置

```
lib/ui/components/styled_dropdown.dart
```

## 特性

- 紧凑设计，比原生 DropdownButton 更小巧
- 支持 `dense` 模式进一步压缩高度
- 自动适配深色/浅色主题
- 选中项带 ✓ 标记
- 支持可选宽度设置
- 泛型支持，可用于任意类型

## 使用方法

### 基础用法

```dart
import 'components/styled_dropdown.dart';

StyledDropdown<String>(
  value: currentValue,
  items: [
    StyledDropdownItem(value: 'option1', label: 'Option 1'),
    StyledDropdownItem(value: 'option2', label: 'Option 2'),
    StyledDropdownItem(value: 'option3', label: 'Option 3'),
  ],
  onChanged: (v) {
    setState(() => currentValue = v);
  },
)
```

### 紧凑模式

```dart
StyledDropdown<String>(
  value: currentValue,
  dense: true,  // 更紧凑的高度
  items: [...],
  onChanged: (v) => ...,
)
```

### 固定宽度

```dart
StyledDropdown<String>(
  value: currentValue,
  width: 200,  // 固定宽度 200px
  items: [...],
  onChanged: (v) => ...,
)
```

### 自适应宽度（左对齐）

```dart
Align(
  alignment: Alignment.centerLeft,
  child: StyledDropdown<String>(
    value: currentValue,
    items: [...],
    onChanged: (v) => ...,
  ),
)
```

### 枚举类型

```dart
StyledDropdown<MyEnum>(
  value: selectedEnum,
  items: MyEnum.values.map((e) {
    return StyledDropdownItem<MyEnum>(
      value: e,
      label: e.displayName,
    );
  }).toList(),
  onChanged: (v) {
    setState(() => selectedEnum = v);
  },
)
```

## API 参考

### StyledDropdown

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `value` | `T` | ✅ | - | 当前选中的值 |
| `items` | `List<StyledDropdownItem<T>>` | ✅ | - | 下拉选项列表 |
| `onChanged` | `void Function(T)` | ✅ | - | 选择变化回调 |
| `width` | `double?` | ❌ | null | 固定宽度，null 时自适应 |
| `hint` | `String?` | ❌ | null | 占位提示（预留） |
| `dense` | `bool` | ❌ | false | 紧凑模式 |

### StyledDropdownItem

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `value` | `T` | ✅ | 选项值 |
| `label` | `String` | ✅ | 显示文本 |

## 与原生 DropdownButton 对比

| 特性 | StyledDropdown | DropdownButton |
|------|----------------|----------------|
| 外观 | 紧凑圆角 | 较宽松 |
| 主题适配 | 自动 | 需手动配置 |
| 选中标记 | ✓ 图标 | 无 |
| 代码量 | 少 | 需要多层包装 |
| 弹出位置 | 下方偏移 | 覆盖在上方 |

## 相关组件

- `StyledPopupMenu` - 用于操作菜单（更多、编辑等按钮）
- `DropdownButton` - Flutter 原生下拉组件

## 变更记录

- 2024-01: 初始版本，从 settings_screen.dart 的模型选择需求中抽取封装
