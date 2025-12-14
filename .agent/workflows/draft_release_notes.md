---
description: 准备发布说明 (Release Notes) - 中文
---

1. 获取最近变更记录
   // turbo
   # 获取上一个版本标签到当前的提交记录
   git log $(git describe --tags --abbrev=0)..HEAD --no-merges --pretty=format:"- %s"

2. 生成发布说明草稿
   # 请(Agent)根据上述日志输出的内容，智能归纳并编写一份中文发布说明。
   # 忽略仅仅是 "chore", "wip", "bump version" 等琐碎提交。
   # 格式建议：
   #
   # ## v[预测的下一个版本号]
   #
   # ### ✨ 新增特性
   # - [特性描述]
   #
   # ### 🚀 优化改进
   # - [改进描述]
   #
   # ### 🐛 问题修复
   # - [修复描述]
   #
   # 请将内容写入并保存为 `RELEASE_DRAFT.md` (临时草稿文件)。
