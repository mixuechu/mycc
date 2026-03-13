---
name: wechat-recall
description: 从 WeMemory 检索微信聊天记忆和人际关系。触发词："/wechat-recall"、"查一下微信"、"我之前和谁说过"、"我的家人"、"某某是谁"
layer: 应用层
authorization: A区（自动执行，无需人类介入）
output_levels: L2（过程+结论）
status: active
created: 2026-03-13
origin: 双记忆库架构 - 生活记忆（WeMemory）与工作记忆（CC Memory）分离
---

# wechat-recall

> 从 WeMemory 检索你的微信聊天记录和人际关系图谱。

## 数据来源

| 类型 | 规模 | 说明 |
|------|------|------|
| **对话记忆** | 138 个精选对话<br>53,732 条记忆片段 | 微信聊天历史（通过 WeFlow 导出） |
| **关系图谱** | 159 条核心关系 | 手动审核的人际关系三元组 |

## 适用场景

### 人际关系查询
- "我老婆是谁？"
- "赵萌是谁？"
- "我的家人有谁？"
- "我的同事有哪些？"

### 历史对话检索
- "我和某某聊过 AI 吗？"
- "我上次和朋友聚会是什么时候？"
- "我之前说过要做什么吗？"

### 生活事件回忆
- "最近的聚会活动"
- "我去年去过哪里旅游？"
- "我和家人的对话"

## 触发词

- `/wechat-recall`
- "查一下微信"
- "我之前和谁说过"
- "某某是谁"
- "我的家人"
- "微信里有没有"

## 执行步骤

### 1. 判断是否需要调用

根据用户问题判断：
- ✅ 涉及微信聊天、生活、社交、家人朋友 → 调用
- ✅ 询问人际关系 → 调用
- ❌ 工作、技术、学习问题 → 不调用（用 /cc-recall）

### 2. 调用 WeMemory API

```bash
curl -X POST "http://103.30.78.193/api/comprehensive/search" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${WEMORY_API_KEY}" \
  -d '{
    "query": "用户的查询",
    "recall_type": "auto",
    "top_k_memories": 5,
    "top_k_triplets": 5,
    "min_memory_relevance": 0.3,
    "min_triplet_score": 0.3
  }'
```

**参数说明**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `query` | string | 搜索查询 |
| `recall_type` | enum | `auto`（自动）/ `semantic`（语义）/ `temporal`（时间）/ `people`（人物） |
| `top_k_memories` | number | 返回对话片段数量，默认 5 |
| `top_k_triplets` | number | 返回三元组数量，默认 5 |
| `min_memory_relevance` | number | 对话最低相关度，0-1，默认 0.3 |
| `min_triplet_score` | number | 三元组最低分数，0-1，默认 0.3 |

### 3. 处理响应

**响应格式**：

```json
{
  "memories": [
    {
      "memory_id": "4ec62d75edbf2cbf",
      "content": "对话内容",
      "conversation_name": "对话对象",
      "timestamp": 1735553174,
      "relevance_score": 0.67,
      "recall_reason": "关键词匹配 + 相关人物",
      "participants": ["米雪川（男）", "对话对象"]
    }
  ],
  "triplets": [
    {
      "text": "米雪川是萌萌姐的配偶",
      "type": "relationship",
      "score": 0.82,
      "metadata": {
        "subject": "萌萌姐",
        "relation_type": "HAS_SPOUSE",
        "object": "米雪川",
        "source": "core_relationships_manual_reviewed"
      }
    }
  ],
  "total_memories": 5,
  "total_triplets": 3
}
```

### 4. 格式化输出

**输出模板**：

```
找到 {total_memories} 条对话记忆，{total_triplets} 条关系信息

【人际关系】（如果有 triplets）
- {text}（来源：{metadata.source}，相关度：{score}）

【对话记忆】
与 {conversation_name} 的对话（{timestamp 格式化}，相关度：{relevance_score}）：
{content}
召回原因：{recall_reason}
---
```

## 环境变量

需要在 `.env` 中配置：

```bash
WEMORY_API_URL=http://103.30.78.193
WEMORY_API_KEY=your-api-key
```

## 关键说明

- **只读接口**：wechat-recall 只检索，不写入
- **生活记忆**：专注于微信聊天、社交、家人朋友
- **工作记忆**：技术、工作、学习内容用 `/cc-recall`
- **API 超时**：默认 30 秒，复杂查询可能需要更长时间

## 边界

- 资源预算：单次查询 ≤ 30 秒
- 产出格式：结构化展示，包含来源和时间戳
- 相关度过滤：只返回分数 ≥ 0.3 的结果

## 不做的事

- 不写入数据到 WeMemory（只读）
- 不处理工作学习记忆（那是 cc-recall 的事）
- 不调用 PersonaAgent（那是独立功能）
- 不修改三元组（手动维护）

## 遇到问题？

**常见问题**：
- **API 连接失败**：检查 `WEMORY_API_URL` 和网络
- **API Key 错误**：检查 `.env` 中的 `WEMORY_API_KEY`
- **搜索结果为空**：尝试调整 `min_memory_relevance` 降低阈值
- **响应超时**：复杂查询可能需要时间，耐心等待

---

**注**：WeMemory 服务部署在 103.30.78.193，API 文档参考 `/root/wechat_memory/README.md`
