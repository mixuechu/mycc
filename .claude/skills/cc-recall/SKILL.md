---
name: cc-recall
description: 从 CC Memory 检索你和 CC 的工作学习对话记忆。触发词："/cc-recall"、"我们上次讨论过"、"之前怎么解决的"、"这个问题聊过吗"
layer: 应用层
authorization: A区（自动执行，无需人类介入）
output_levels: L2（过程+结论）
status: active
created: 2026-03-13
origin: 双记忆库架构 - 生活记忆（WeMemory）与工作记忆（CC Memory）分离
---

# cc-recall

> 从 CC Memory 检索你和 CC 的工作、学习、技术讨论对话记忆。

## 数据来源

| 类型 | 规模 | 说明 |
|------|------|------|
| **对话记忆** | 动态增长<br>当前 16+ 条归档 | 你与 CC 的历史对话（自动归档） |
| **知识图谱** | 待构建 | 从重要对话提取的知识三元组 |

## 适用场景

### 工作技术查询
- "我们上次怎么整合 WeMemory 的？"
- "之前讨论的架构方案是什么？"
- "这个 bug 我们解决过吗？"

### 学习知识回顾
- "之前学过的 React Hooks 怎么用？"
- "我们讨论过哪些设计模式？"
- "FastAPI 的最佳实践是什么？"

### 项目历史追溯
- "Meng 前端是怎么开发的？"
- "CC Memory 服务配置步骤"
- "上次的部署流程"

## 与 wechat-recall 的区别

| 维度 | wechat-recall | cc-recall |
|------|--------------|-----------|
| **数据源** | 微信聊天记录 | CC 对话记录 |
| **内容类型** | 生活、社交、家人朋友 | 工作、学习、技术 |
| **数据规模** | 138对话，53,732条记忆 | 动态增长（从0开始） |
| **写入方式** | 批量导入（WeFlow） | 实时归档（API） |
| **触发场景** | "我老婆是谁"、"和谁聊过" | "我们讨论过"、"怎么解决的" |

## 触发词

- `/cc-recall`
- "我们上次讨论过"
- "之前怎么解决的"
- "这个问题聊过吗"
- "CC 记得"
- "回忆一下"

## 执行步骤

### 1. 判断是否需要调用

根据用户问题判断：
- ✅ 工作、技术、学习相关 → 调用 cc-recall
- ✅ 询问历史对话、项目经验 → 调用 cc-recall
- ❌ 生活、社交、家人朋友 → 不调用（用 /wechat-recall）

### 2. 调用 CC Memory API

**注意**: 当前 CC Memory 处于 **archive-only 模式**，检索功能待实现。现阶段只能查看统计信息。

#### 未来的检索接口（待实现）

```bash
curl -X POST "http://103.30.78.193/api/cc/recall" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${CC_MEMORY_API_KEY}" \
  -d '{
    "query": "用户的查询",
    "top_k": 5,
    "min_relevance": 0.3
  }'
```

#### 当前可用接口

```bash
# 查看归档统计
curl "http://103.30.78.193/api/cc/archive/stats" \
  -H "X-API-Key: ${CC_MEMORY_API_KEY}"
```

**参数说明**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `query` | string | 搜索查询 |
| `top_k` | number | 返回对话数量，默认 5 |
| `min_relevance` | number | 最低相关度，0-1，默认 0.3 |

### 3. 处理响应

**未来的响应格式**（待实现）：

```json
{
  "conversations": [
    {
      "id": "cc_xxxxxxxxxxxx",
      "summary": "讨论了双记忆库架构设计",
      "timestamp": 1710331200,
      "importance": 0.85,
      "relevance_score": 0.72,
      "tags": ["架构设计", "WeMemory", "记忆系统"],
      "messages": [
        {"role": "user", "content": "..."},
        {"role": "assistant", "content": "..."}
      ]
    }
  ],
  "total": 5
}
```

**当前统计响应**：

```json
{
  "total_conversations": 16,
  "total_messages": 14,
  "avg_importance": 0.35,
  "recent_archives": [
    {
      "id": "persistence_test_001",
      "summary": "数据持久化验证",
      "importance": 0.8,
      "archived_at": "2026-03-13T14:13:05.646902"
    }
  ]
}
```

### 4. 格式化输出

**当前输出模板** (archive-only 模式)：

```
CC Memory 当前状态：Archive-only 模式
- 已归档对话：{total_conversations} 条
- 平均重要性：{avg_importance}

最近归档的对话：
1. {summary}（重要性：{importance}，时间：{archived_at}）
...

注：检索功能正在开发中，现阶段只支持查看归档统计。
```

**未来输出模板** (检索功能上线后)：

```
找到 {total} 条相关对话

【对话 1】（相关度：{relevance_score}）
时间：{timestamp 格式化}
摘要：{summary}
标签：{tags}
重要性：{importance}

内容预览：
{messages 前3轮}
...
---
```

## 环境变量

需要在 `/home/mycc/mycc/.env` 中配置：

```bash
CC_MEMORY_API_URL=http://103.30.78.193/api/cc
CC_MEMORY_API_KEY=CCM_k9L3mN7pQ2sR5tV8wX1yZ4aB6cD
```

## 关键说明

- **Archive-only 模式**：当前只支持归档，检索功能待向量化完成后上线
- **自动归档**：重要对话会被自动归档到 CC Memory
- **工作记忆**：专注于工作、技术、学习内容
- **生活记忆**：生活、社交内容用 `/wechat-recall`

## 开发路线图

### ✅ Phase 1-2: 已完成
- [x] CC Memory 服务搭建
- [x] Archive API 实现
- [x] Systemd 服务配置
- [x] Nginx 反向代理
- [x] 全面测试（100% 通过）

### ⏳ Phase 3: 进行中
- [x] cc-recall skill 创建
- [ ] 环境变量配置
- [ ] 测试统计查询
- [ ] 文档完善

### 📋 Phase 4: 待开始
- [ ] 向量化已归档对话
- [ ] 实现 recall API
- [ ] 集成归档判断机制
- [ ] /sync_memory skill

## 边界

- 资源预算：单次查询 ≤ 30 秒
- 产出格式：结构化展示，包含时间戳和相关度
- 相关度过滤：只返回分数 ≥ 0.3 的结果（未来）

## 不做的事

- 不处理生活社交记忆（那是 wechat-recall 的事）
- 不修改已归档对话（只读）
- 不自动归档（需要判断机制触发）
- 在 archive-only 模式下不提供语义检索

## 遇到问题？

**常见问题**：
- **"检索功能不可用"**：当前处于 archive-only 模式，需要完成向量化后才能检索
- **API 连接失败**：检查 `CC_MEMORY_API_URL` 和网络
- **API Key 错误**：检查 `.env` 中的 `CC_MEMORY_API_KEY`
- **统计信息为空**：说明还没有归档任何对话

**查看服务状态**：
```bash
# 健康检查
curl http://103.30.78.193/api/cc/health

# 查看归档统计
curl http://103.30.78.193/api/cc/archive/stats \
  -H "X-API-Key: CCM_k9L3mN7pQ2sR5tV8wX1yZ4aB6cD"
```

---

**注**：CC Memory 服务部署在 103.30.78.193:8003，通过 nginx 反向代理访问 /api/cc/

---

## 归档功能（已实现）⭐

### 使用方法

**归档对话**:
```bash
/cc-recall archive <summary> <importance> [tags]
```

**参数说明**:
- `summary`: 对话摘要（必填）
- `importance`: 重要性评分 0-1（必填）
- `tags`: 标签，逗号分隔（可选）

**示例**:
```bash
# 带标签归档
/cc-recall archive "讨论了双记忆库架构" 0.85 "架构设计,记忆系统"

# 不带标签归档
/cc-recall archive "修复了前端bug" 0.6

# 高重要性归档
/cc-recall archive "完成了Phase3的归档功能" 0.9 "milestone,skill"
```

### 归档判断指南

**重要性评分建议**:

| 评分 | 类型 | 示例 |
|------|------|------|
| 0.9-1.0 | 重大突破 | 架构设计、关键决策、重要里程碑 |
| 0.7-0.9 | 重要讨论 | 问题解决方案、技术深入讨论 |
| 0.5-0.7 | 一般对话 | 功能实现、常规bug修复 |
| 0.3-0.5 | 参考价值 | 简单问答、配置说明 |
| 0-0.3 | 低价值 | 临时测试、琐碎问题 |

**自动归档触发条件**（未来）:
- 知识沉淀（重要性 ≥ 0.8）
- 问题解决（对话轮数 > 5）
- 重要决策（明确的决策点）
- 深度讨论（对话时长 > 10分钟）

### 归档后操作

归档成功后会返回：
```
✅ 归档成功！

对话ID：cc_xxxxxxxxxxxx
对话已归档到 /root/cc_memory/data/conversations/cc_xxxxxxxxxxxx.json

提示：
- 使用 /cc-recall stats 可以查看归档统计
- 使用 /cc-recall recall 可以检索这段对话（开发中）
```

### 当前限制

1. **占位消息内容**: 当前归档时使用摘要作为占位消息，未来需要传入真实对话内容
2. **手动触发**: 需要手动调用归档命令，自动归档判断需要在 MyCC 核心代码中实现
3. **无检索功能**: 归档后暂时只能通过统计查看，检索功能待向量化完成后实现

### 未来增强

- [ ] 传入真实对话内容（JSON格式）
- [ ] 自动生成摘要（LLM）
- [ ] 自动评估重要性（规则引擎 + LLM）
- [ ] 自动提取标签
- [ ] 自动归档判断（集成到对话流程）
- [ ] 归档确认提示（"要我存入记忆吗？"）

---

**更新**: 2026-03-13 - 添加归档功能（Phase 3.3 完成）
