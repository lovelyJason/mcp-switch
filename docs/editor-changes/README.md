# AI 编辑器版本更迭兼容记录

本目录按编辑器分类，记录各 AI 编辑器在版本更新过程中涉及 MCP 配置机制的变更，用于指导 MCP Switch 做出相应的功能兼容。

## 目录结构

```
docs/editor-changes/
├── cursor/          # Cursor 编辑器相关变更
├── claude/          # Claude Code 相关变更（待补充）
├── windsurf/        # Windsurf 相关变更（待补充）
├── codex/           # Codex 相关变更（待补充）
├── gemini/          # Gemini CLI 相关变更（待补充）
└── README.md        # 本文件
```

## 文档格式

每个变更记录使用独立的 `.md` 文件，命名格式：`<简要描述>.md`

文件内容模板：

```markdown
# [日期/季度] 变更标题

**影响版本**: xxx
**变更内容**: ...
**对 MCP Switch 的影响**: ...
**兼容方案**: ...
```
