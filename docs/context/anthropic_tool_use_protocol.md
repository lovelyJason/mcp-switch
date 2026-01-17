# Anthropic Tool Use 协议要点

## 概述

使用 Anthropic API 的 Tool Use 功能时，消息序列必须严格遵循协议规范，否则会返回 400 错误。

## 核心规则

### 1. tool_use 必须紧跟 tool_result

**错误信息示例**：
```
invalid_request_error: messages.13: tool_use ids were found without
tool_result blocks immediately after: toolu_01PLz4xG69h1SFRGMCKroY4F.
Each tool_use block must have a corresponding tool_result block in the next message.
```

**正确的消息序列**：
```
user: "请列出所有插件"
assistant: [text: "好的"] + [tool_use: id=xxx, name=list_plugins]
user: [tool_result: tool_use_id=xxx, content="插件列表..."]    <-- 必须紧跟！
assistant: "根据查询结果，你有以下插件..."
```

**错误的消息序列**：
```
user: "请列出所有插件"
assistant: [tool_use: id=xxx]
user: "其他问题"           <-- 错误！tool_use 后面不是 tool_result
assistant: ...
```

### 2. 代码实现要点

在构建消息历史发送给 API 时，遍历本地消息列表，**每当添加一个带 tool_use 的 assistant 消息后，必须立即添加对应的 tool_result**。

**错误写法**（之前的 bug）：
```dart
// 遍历所有消息
for (final m in _messages) {
  if (m.role == ChatRole.assistant && m.toolCalls != null) {
    // 添加 assistant 消息（含 tool_use）
    apiMessages.add(assistantMessage);
    // 错误：没有立即添加 tool_result！
  }
}
// 最后才添加 tool_result - 这样中间轮次的 tool_result 就丢了！
apiMessages.add(toolResultMessage);
```

**正确写法**：
```dart
for (final m in _messages) {
  if (m.role == ChatRole.assistant && m.toolCalls != null) {
    // 1. 添加 assistant 消息（含 tool_use blocks）
    apiMessages.add(Message(
      role: MessageRole.assistant,
      content: MessageContent.blocks([
        Block.text(text: m.content),
        ...m.toolCalls!.map((tc) => Block.toolUse(
          id: tc.id,
          name: tc.name,
          input: tc.input,
        )),
      ]),
    ));

    // 2. 立即添加对应的 tool_result！
    apiMessages.add(Message(
      role: MessageRole.user,
      content: MessageContent.blocks(
        m.toolCalls!.map((tc) => Block.toolResult(
          toolUseId: tc.id,
          content: ToolResultBlockContent.text(tc.result ?? ''),
        )).toList(),
      ),
    ));
  }
}
```

### 3. 多轮 Tool Use 场景

当对话中有多轮工具调用时：

```
user: "问题1"
assistant: [tool_use: id=A]
user: [tool_result: id=A]      <-- A 的结果
assistant: "回答1"
user: "问题2"
assistant: [tool_use: id=B]
user: [tool_result: id=B]      <-- B 的结果
assistant: "回答2"
```

每一对 `tool_use` 和 `tool_result` 都必须保持相邻。

## 相关文件

- [ai_chat_service.dart](../../lib/services/ai_chat_service.dart) - `_continueWithToolResults` 方法

## 参考文档

- [Anthropic Tool Use Documentation](https://docs.anthropic.com/en/docs/build-with-claude/tool-use)

## 变更记录

- 2024-01: 修复多轮 tool_use 时 tool_result 位置不正确的 bug
