# Clash Verge Rev — 配置增强（Merge/Script/Rules）机制分析

> 基于 [clash-verge-rev](https://github.com/clash-verge-rev/clash-verge-rev) `dev` 分支源码分析

## 问题现象

全局扩展覆写配置（Merge）中写了 `rules:`，导致订阅 YAML 末尾的 `- MATCH,SSRDOG` 丢失，TUN + 规则模式下无法访问 Google 等被墙网站。必须在 Merge 中手动加 `- MATCH,SSRDOG` 才行。

## 根因：`deep_merge` 对数组是替换而非合并

### 源码位置

`src-tauri/src/enhance/merge.rs`

```rust
fn deep_merge(a: &mut Value, b: Value) {
    match (a, b) {
        // Mapping（字典）→ 递归合并
        (&mut Value::Mapping(ref mut a), Value::Mapping(b)) => {
            for (k, v) in b {
                deep_merge(a.entry(k.clone()).or_insert(Value::Null), v);
            }
        }
        // 其他类型（包括 Sequence/数组）→ 直接替换
        (a, b) => *a = b,
    }
}
```

**关键行为**：

| 类型 | Merge 行为 |
|------|-----------|
| Mapping（字典，如 `profile:`, `tun:`, `dns:`） | 递归深度合并，已有 key 保留 |
| Sequence（数组，如 `rules:`, `proxies:`, `proxy-groups:`） | **整体替换** |

所以当你在 Merge 中写 `rules: [...]`，**订阅的整个 rules 数组被替换**，末尾的 `- MATCH,SSRDOG` 自然消失。

### 处理顺序

`src-tauri/src/enhance/mod.rs` 中 `enhance()` 函数的执行顺序：

```
订阅 YAML
  │
  ▼
① 全局 Merge（deep_merge）         ← rules: 会替换整个数组！
  │
  ▼
② 全局 Script（JS 变换）
  │
  ▼
③ 订阅级 Rules 扩展（prepend/append/delete）  ← 正确的 rules 扩展方式
  │
  ▼
④ 订阅级 Proxies 扩展
  │
  ▼
⑤ 订阅级 Groups 扩展
  │
  ▼
⑥ 订阅级 Merge（deep_merge）       ← 同样会替换数组
  │
  ▼
⑦ 订阅级 Script（JS 变换）
  │
  ▼
⑧ 默认 Clash 配置合并
  │
  ▼
⑨ 内置脚本（meta_guard 等）
  │
  ▼
最终配置 → 传给 mihomo 内核
```

## Clash Verge 的三种增强类型

| 类型 | 作用域 | 机制 | 对数组的行为 |
|------|--------|------|-------------|
| **Merge**（覆写） | 全局 / 订阅级 | `deep_merge` | 字典递归合并，**数组整体替换** |
| **Script**（脚本） | 全局 / 订阅级 | JS `main(config)` | 完全可控，你自己操作 config 对象 |
| **Rules**（规则） | 仅订阅级 | `SeqMap: prepend/append/delete` | prepend 插到数组前面，append 加到数组后面 |

### Rules 扩展的模板

`src-tauri/src/utils/tmpl.rs`:

```yaml
# Profile Enhancement Rules Template for Clash Verge
prepend: []
append: []
delete: []
```

### Rules 扩展的执行逻辑

`src-tauri/src/enhance/seq.rs`:

```
最终 rules = [prepend 规则...] + [原始 rules（删除 delete 匹配项）] + [append 规则...]
```

## 解决方案

### 方案 A（推荐）：全局 Merge 不碰 rules + 全局 Script 插入自定义规则

**全局扩展覆写配置（Merge）**— 只放字典类型配置，不写 `rules:`：

```yaml
# Profile Enhancement Merge Template for Clash Verge

profile:
  store-selected: true
```

**全局扩展脚本配置（Script）**— 用 JS 把自定义规则插到 rules 数组前面：

```javascript
function main(config, profileName) {
  const customRules = [
    "DOMAIN-SUFFIX,figma.com,DIRECT",
    "DOMAIN-SUFFIX,mcp.figma.com,DIRECT",
    "GEOIP,PRIVATE,DIRECT",
    "GEOIP,CN,DIRECT",
    "DOMAIN-SUFFIX,cn,DIRECT",
  ];

  if (Array.isArray(config.rules)) {
    config.rules = [...customRules, ...config.rules];
  } else {
    config.rules = customRules;
  }

  return config;
}
```

**效果**：自定义规则被 prepend 到订阅 rules 前面，订阅末尾的 `- MATCH,SSRDOG`（或任何订阅的兜底规则）保持不变。无论切换哪个订阅、分组名是什么，都不影响。

### 方案 B：每个订阅单独配 Rules 扩展

右键订阅 → 编辑规则，写入：

```yaml
prepend:
  - DOMAIN-SUFFIX,figma.com,DIRECT
  - DOMAIN-SUFFIX,mcp.figma.com,DIRECT
  - GEOIP,PRIVATE,DIRECT
  - GEOIP,CN,DIRECT
  - DOMAIN-SUFFIX,cn,DIRECT

append: []
delete: []
```

**缺点**：每个订阅都要单独配一次，不是全局的。

### 方案 C：全局 Merge 中使用 rules 但手动补兜底

```yaml
profile:
  store-selected: true

rules:
  - DOMAIN-SUFFIX,figma.com,DIRECT
  - GEOIP,PRIVATE,DIRECT
  - GEOIP,CN,DIRECT
  - DOMAIN-SUFFIX,cn,DIRECT
  - MATCH,你的代理组名
```

**缺点**：`rules:` 会替换订阅的整个 rules，订阅自带的精细规则（YouTube/Bahamut/DMM 等 RULE-SET）全部丢失。而且 `MATCH,代理组名` 是写死的，换订阅就失效。**不推荐**。

## 总结

| 在 Merge 中写 | 实际行为 | 推荐？ |
|---------------|---------|--------|
| `profile:` / `tun:` / `dns:` 等字典 | 递归深度合并，不丢失已有配置 | 推荐 |
| `rules:` / `proxies:` / `proxy-groups:` 等数组 | **整体替换**，订阅原数组被覆盖 | 不推荐 |

**黄金法则**：Merge 只用于字典类型的配置项。需要增删规则时，用 Script（全局）或 Rules 扩展（订阅级）。
