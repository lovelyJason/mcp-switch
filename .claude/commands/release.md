---
description: Build Release version and Publish to GitHub (Automated)
---

// turbo-all

## 版本号规则 (MAJOR.MINOR.PATCH+BUILD)
- SemVer 部分由 bump_version.py 根据 release type (patch/minor/major) 自动递增
- BUILD 号每次发版自动 +1，**绝对不能跳过或保持不变**
- 发版前必须确认 pubspec.yaml 中 version 的 +BUILD 部分已递增

1. Execute Release Script

   ./scripts/release_workflow.sh
