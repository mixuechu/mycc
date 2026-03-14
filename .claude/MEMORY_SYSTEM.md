# 双记忆库架构 - 完整说明

## 📚 系统概览

MyCC 现在拥有完整的双记忆库系统：

```
┌─────────────────────────────────────────┐
│  立即记忆（三文档）                      │
│  ─────────────────────────               │
│  • status.md   - 今日焦点                │
│  • context.md  - 本周快照                │
│  • about-me/   - 核心画像                │
│                                          │
│  触发：Skill (update_context)            │
│  频率：低（10-20% 对话）                  │
│  特点：自动注入，精炼核心                 │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  长期记忆（CC Memory）                    │
│  ─────────────────────────               │
│  • 向量知识库                             │
│  • 可无限增长                             │
│                                          │
│  触发：Hook (Stop事件)                    │
│  频率：高（100% 对话）                    │
│  特点：按需检索，完整详细                 │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  社交记忆（WeMemory）                     │
│  ─────────────────────────               │
│  • 微信聊天记录                           │
│  • 知识图谱                               │
│                                          │
│  触发：Skill (wechat-recall)              │
│  频率：按需                               │
│  特点：只读检索                           │
└─────────────────────────────────────────┘
```

---

## 🔧 技术实现

### 1. CC Memory 归档（自动、频繁）

**机制**：Hook（Stop 事件）

**配置**：
```json
// .claude/settings.local.json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/archive_to_cc.sh"
      }]
    }]
  }
}
```

**流程**：
```
每次对话结束（Claude完成响应）
   ↓
Stop hook 自动触发
   ↓
.claude/hooks/archive_to_cc.sh
   ↓
调用 cc-recall archive
   ↓
LLM 分析：生成摘要、评分、标签
   ↓
存入 CC Memory 向量库
```

**特点**：
- ✅ 100% 可靠（每次都执行）
- ✅ 不依赖 Claude 判断
- ✅ 几乎 0 token 消耗

---

### 2. CC Memory 检索（按需、智能）

**机制**：Skill（cc-recall）

**配置**：
```yaml
# .claude/skills/cc-recall/SKILL.md
---
name: cc-recall
description: 从 CC Memory 检索工作学习记忆。当用户问"我们上次讨论过"时使用
---
```

**流程**：
```
用户问问题："我们上次讨论过什么？"
   ↓
Claude 识别 description 匹配
   ↓
自动调用 cc-recall skill
   ↓
向量检索相关对话
   ↓
返回结果
```

**特点**：
- ✅ 智能触发（语义理解）
- ✅ 按需执行（不是每次都检索）
- ✅ 用户无感知

---

### 3. 三文档更新（选择性、严格）

**机制**：Skill（update_context）

**配置**：
```yaml
# .claude/skills/update_context/SKILL.md
---
name: update_context
description: 更新三文档。仅在重大进展、完成里程碑、核心偏好变化时调用
---
```

**流程**：
```
对话中完成重要任务
   ↓
Claude 判断：这是重大进展
   ↓
调用 update_context skill
   ↓
LLM 分析：是否需要更新三文档
   ↓
更新 status.md / context.md / about-me
```

**特点**：
- ✅ 严格判断（只记录核心信息）
- ✅ 低频率（10-20% 对话）
- ✅ 不污染三文档

---

### 4. WeMemory 检索（社交记忆）

**机制**：Skill（wechat-recall）

**配置**：
```yaml
# .claude/skills/wechat-recall/SKILL.md
---
name: wechat-recall
description: 检索微信聊天记忆。当用户问生活、家人、朋友相关问题时使用
---
```

**特点**：
- ✅ 只读（不写入）
- ✅ 按需检索
- ✅ 与工作记忆分离

---

## 📊 完整的记忆流

### 对话进行时

```
用户与 CC 对话
   ↓
Claude 处理并响应
   ↓
【触发点1】Claude 完成响应
   ↓
Stop Hook 自动执行
   ↓
归档到 CC Memory（100%）
```

### 对话结束后

```
【触发点2】Claude 判断重要性
   ↓
如果是重大进展/偏好变化
   ↓
调用 update_context skill
   ↓
更新三文档（10-20%）
```

### 用户提问时

```
用户："我们上次讨论过双记忆库吗？"
   ↓
Claude 识别触发词
   ↓
调用 cc-recall skill
   ↓
检索 CC Memory
   ↓
返回相关对话
```

```
用户："我老婆是谁？"
   ↓
Claude 识别触发词
   ↓
调用 wechat-recall skill
   ↓
检索 WeMemory
   ↓
返回社交信息
```

---

## 🎯 设计原则

### 职责分离

| 系统 | 职责 | 触发 | 频率 |
|------|------|------|------|
| **CC Memory 归档** | 记录所有对话 | Hook | 100% |
| **CC Memory 检索** | 召回工作记忆 | Skill | 按需 |
| **三文档更新** | 精炼核心信息 | Skill | 10-20% |
| **WeMemory 检索** | 召回社交记忆 | Skill | 按需 |

### 严格分流

**立即记忆（三文档）**：
- 只记录最核心的东西
- 自动注入每次对话
- 必须保持精炼

**长期记忆（CC Memory）**：
- 记录所有有价值的对话
- 需要时才检索
- 可以无限增长

---

## 📁 文件结构

```
.claude/
├── hooks/
│   └── archive_to_cc.sh          # CC Memory 自动归档 hook
│
├── skills/
│   ├── cc-recall/                # CC Memory 检索 skill
│   │   ├── SKILL.md
│   │   └── recall.sh
│   │
│   ├── update_context/           # 三文档更新 skill
│   │   ├── SKILL.md
│   │   ├── update.sh
│   │   └── analyze_context.py
│   │
│   └── wechat-recall/            # WeMemory 检索 skill
│       ├── SKILL.md
│       └── recall.sh
│
├── settings.local.json           # Hook 配置
│
└── (原有的 sync_memory/ 已弃用)
```

```
0-System/                         # 三文档目录
├── status.md                     # 今日焦点
├── context.md                    # 本周快照
└── about-me/                     # 核心画像
    ├── preferences.md
    ├── strengths.md
    └── goals.md
```

---

## ✅ 完成的 Phases

| Phase | 功能 | 状态 |
|-------|------|------|
| **Phase 1** | wechat-recall skill | ✅ 完成 |
| **Phase 2** | CC Memory 服务 | ✅ 完成 |
| **Phase 3** | cc-recall skill | ✅ 完成 |
| **Phase 4** | 记忆自动化（Hook + Skill） | ✅ 完成 |

---

**维护者**: Claude Sonnet 4.5  
**最后更新**: 2026-03-14  
**版本**: 2.0（重构版）
