# MCP 预设配置系统

## 概述

2025-01-19 实现了 MCP 预设配置化系统，将原本硬编码在 `mcp_server_edit_screen.dart` 中的预设抽离到 YAML 配置文件，支持用户自定义、导入/导出。

## 设计目标

1. **配置驱动** - 预设从 YAML 文件加载，新增预设无需改代码
2. **连接类型选择** - 支持 local/http/sse 三种模式，带推荐徽章
3. **动态表单字段** - 根据配置生成 API Key 等输入框
4. **Claude CLI 命令模板** - 为每种连接类型配置对应的 CLI 命令
5. **用户可编辑** - 配置复制到用户目录，可自行修改
6. **导入/导出** - 支持分享配置给他人
7. **错误容错** - YAML 解析失败不会崩溃

## 文件结构

```
assets/config/
└── mcp_presets.yaml          # 出厂默认配置

lib/config/
└── mcp_presets_config.dart   # 配置加载器 + 数据模型

~/.mcp-switch/config/
└── mcp_presets.yaml          # 用户配置（首次运行从 assets 复制）
```

## 配置加载顺序

```
1. 检查 ~/.mcp-switch/config/mcp_presets.yaml 是否存在
   ├── 不存在 → 从 assets/config/mcp_presets.yaml 复制
   └── 存在 → 直接读取

2. 解析 YAML
   ├── 成功 → 使用解析结果
   └── 失败 → Fallback 到 assets，再失败则用硬编码默认值
```

## YAML 配置结构

```yaml
# 连接类型定义（全局）
connection_type_definitions:
  local:
    label_key: connection_type_local       # i18n key
    description_key: connection_type_local_desc
    show_command_args: true                # 是否显示 command/args 输入框

  http:
    label_key: connection_type_http
    description_key: connection_type_http_desc
    show_command_args: false

  sse:
    label_key: connection_type_sse
    description_key: connection_type_sse_desc
    show_command_args: false

# 预设列表
presets:
  - id: context7                           # 唯一标识
    name: Context7                         # 显示名称（或用 name_key 指定 i18n key）
    icon: assets/icons/context7.svg        # 图标路径，null 则不显示

    # 连接类型配置（可多个）
    connection_types:
      - type: http
        recommended: true                  # 推荐标记
        config:
          url: https://mcp.context7.com/mcp
          headers:
            CONTEXT7_API_KEY: '{{api_key}}'  # 模板变量
        # Claude Code CLI 命令模板
        claude_cli: 'claude mcp add --transport http --header "CONTEXT7_API_KEY: {{api_key}}" {{name}} https://mcp.context7.com/mcp'

      - type: local
        recommended: false
        config:
          command: npx
          args: ['-y', '@upstash/context7-mcp']
          extra_args: ['--api-key', '{{api_key}}']
        claude_cli: 'claude mcp add {{name}} -- npx -y @upstash/context7-mcp --api-key {{api_key}}'

    # 动态表单字段
    form_fields:
      - id: api_key                        # 字段 ID，用于模板插值
        label_key: api_key                 # i18n key
        sub_label_key: api_key_hint        # 副标签 i18n key
        placeholder: 'context7_...'
        required: false
        apply_mode: env                    # env | arg
        env_key: CONTEXT7_API_KEY          # apply_mode=env 时使用
        arg_key: '--api-key'               # apply_mode=arg 时使用
        arg_format: equals                 # equals: --key=value, space: --key value
```

## 模板变量

配置中使用 `{{variable}}` 语法定义模板变量：

| 变量 | 说明 |
|------|------|
| `{{name}}` | MCP 名称（用户输入的名称字段） |
| `{{field_id}}` | 对应 form_fields 中定义的字段 ID |

**示例**：
```yaml
claude_cli: 'claude mcp add --header "API_KEY: {{api_key}}" {{name}} https://example.com'
```

如果用户输入 `name=my-mcp`、`api_key=abc123`，则生成：
```
claude mcp add --header "API_KEY: abc123" my-mcp https://example.com
```

## 数据模型类

### McpPresetsConfig（静态类）

```dart
// 初始化
await McpPresetsConfig.init();

// 获取所有预设
List<McpPreset> presets = McpPresetsConfig.presets;

// 根据 ID 获取预设
McpPreset? preset = McpPresetsConfig.getPresetById('context7');

// 获取连接类型定义
Map<String, ConnectionTypeDef> defs = McpPresetsConfig.connectionTypeDefinitions;

// 导入/导出
await McpPresetsConfig.importConfig('/path/to/file.yaml');
await McpPresetsConfig.exportConfig('/path/to/file.yaml');

// 重置为默认
await McpPresetsConfig.resetToDefault();
```

### McpPreset

```dart
class McpPreset {
  final String id;
  final String? nameKey;           // i18n key
  final String? name;              // 直接字符串
  final String? icon;
  final bool isCustom;             // 是否为自定义模式
  final List<McpConnectionType> connectionTypes;
  final List<McpFormField> formFields;

  String get displayName;          // 获取显示名称（优先 i18n）
  McpConnectionType? get recommendedConnectionType;  // 获取推荐的连接类型
}
```

### McpConnectionType

```dart
class McpConnectionType {
  final String type;               // local | http | sse
  final bool recommended;
  final Map<String, dynamic> config;
  final String? claudeCli;         // CLI 命令模板

  String? get command;             // local 模式
  List<String> get args;           // local 模式
  List<String> get extraArgs;      // local 模式额外参数
  String? get url;                 // http/sse 模式
  Map<String, String> get headers; // http/sse 模式

  // 生成 Claude CLI 命令
  String? generateClaudeCliCommand(String name, Map<String, String> fieldValues);
}
```

### McpFormField

```dart
class McpFormField {
  final String id;
  final String? labelKey;
  final String? subLabelKey;
  final String? placeholder;
  final bool required;
  final String applyMode;          // env | arg
  final String? envKey;
  final String? argKey;
  final String? argFormat;         // equals | space

  String get displayLabel;
  String get displaySubLabel;
}
```

## UI 集成

### mcp_server_edit_screen.dart 改动

1. **预设 Chip 按钮** - 从 `McpPresetsConfig.presets` 读取
2. **连接类型 Radio 选择器** - 根据 `preset.connectionTypes` 动态渲染
3. **动态表单字段** - 根据 `preset.formFields` 生成输入框
4. **导入/导出按钮** - 顶部工具栏

### 关键方法

```dart
// 预设选中
void _onPresetSelected(McpPreset preset) {
  _selectedPresetId = preset.id;
  final recommended = preset.recommendedConnectionType;
  if (recommended != null) {
    _selectedConnectionType = recommended.type;
    _applyConnectionTypeConfig(preset, recommended);
  }
}

// 连接类型切换
void _onConnectionTypeChanged(McpPreset preset, String connectionType) {
  _selectedConnectionType = connectionType;
  final config = preset.connectionTypes.firstWhere((c) => c.type == connectionType);
  _applyConnectionTypeConfig(preset, config);
}

// 动态字段变化
void _onDynamicFieldChanged(McpPreset preset, McpFormField field) {
  if (_selectedConnectionType == 'local') {
    // 根据 apply_mode 更新 env 或 args
  } else {
    // 重新生成 remote 配置
  }
}
```

## 国际化字符串

新增以下 i18n key（zh.json / en.json）：

```json
{
  "connection_type": "连接类型",
  "connection_type_local": "本地 (stdio)",
  "connection_type_local_desc": "通过本地进程通信",
  "connection_type_http": "HTTP 远程",
  "connection_type_http_desc": "通过 HTTP 协议远程调用",
  "connection_type_sse": "SSE 远程",
  "connection_type_sse_desc": "通过 Server-Sent Events 远程调用",
  "figma_access_token": "Access Token",
  "is_required": "是必填项",
  "import_presets": "导入预设",
  "export_presets": "导出预设",
  "import_success": "导入成功",
  "import_failed": "导入失败",
  "export_success": "导出成功",
  "export_failed": "导出失败",
  "recommended": "推荐"
}
```

## 错误处理

1. **YAML 语法错误** - 捕获 `YamlException`，显示具体错误位置
2. **字段缺失** - 使用默认值，不崩溃
3. **文件不存在** - 从 assets 复制或使用硬编码默认值
4. **导入验证** - 导入前验证 YAML 格式和必要字段

## 后续扩展

1. **新增预设** - 直接编辑 `~/.mcp-switch/config/mcp_presets.yaml`
2. **分享预设** - 导出 YAML 发给他人
3. **在线预设库** - 未来可从 GitHub 等加载社区预设
