#!/bin/bash
# WeChat Recall - 从 WeMemory 检索微信记忆

set -e

# 读取环境变量
if [ -f ".env" ]; then
  export $(grep -v '^#' .env | grep -E '^WEMORY_' | xargs)
fi

# 检查必需的环境变量
if [ -z "$WEMORY_API_URL" ]; then
  echo "错误：未配置 WEMORY_API_URL"
  echo "请在 .env 文件中添加：WEMORY_API_URL=http://103.30.78.193"
  exit 1
fi

if [ -z "$WEMORY_API_KEY" ]; then
  echo "错误：未配置 WEMORY_API_KEY"
  echo "请在 .env 文件中添加：WEMORY_API_KEY=your-api-key"
  exit 1
fi

# 解析参数
QUERY="${1:-}"
RECALL_TYPE="${2:-auto}"
TOP_K="${3:-5}"

if [ -z "$QUERY" ]; then
  echo "用法: $0 <查询内容> [recall_type] [top_k]"
  echo ""
  echo "参数："
  echo "  查询内容      必填，搜索关键词"
  echo "  recall_type   可选，auto/semantic/temporal/people，默认 auto"
  echo "  top_k         可选，返回结果数量，默认 5"
  echo ""
  echo "示例："
  echo "  $0 \"我老婆是谁\""
  echo "  $0 \"和赵萌聊过什么\" semantic 10"
  exit 1
fi

# 调用 API
echo "正在搜索：$QUERY"
echo ""

RESPONSE=$(curl -s -X POST "$WEMORY_API_URL/api/comprehensive/search" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $WEMORY_API_KEY" \
  -d "{
    \"query\": \"$QUERY\",
    \"recall_type\": \"$RECALL_TYPE\",
    \"top_k_memories\": $TOP_K,
    \"top_k_triplets\": $TOP_K,
    \"min_memory_relevance\": 0.3,
    \"min_triplet_score\": 0.3
  }")

# 检查 API 响应
if [ -z "$RESPONSE" ]; then
  echo "错误：API 无响应"
  exit 1
fi

# 检查是否有错误
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
  echo "API 错误：$ERROR"
  exit 1
fi

# 解析结果
TOTAL_MEMORIES=$(echo "$RESPONSE" | jq -r '.total_memories // 0')
TOTAL_TRIPLETS=$(echo "$RESPONSE" | jq -r '.total_triplets // 0')

if [ "$TOTAL_MEMORIES" -eq 0 ] && [ "$TOTAL_TRIPLETS" -eq 0 ]; then
  echo "没有找到相关记忆"
  echo ""
  echo "建议："
  echo "- 尝试换个说法"
  echo "- 降低相关度阈值（修改脚本中的 min_memory_relevance）"
  exit 0
fi

echo "=== 搜索结果 ==="
echo "找到 $TOTAL_MEMORIES 条对话记忆，$TOTAL_TRIPLETS 条关系信息"
echo ""

# 展示三元组（人际关系）
if [ "$TOTAL_TRIPLETS" -gt 0 ]; then
  echo "【人际关系】"
  echo "$RESPONSE" | jq -r '.triplets[] | "- \(.text)（来源：\(.metadata.source // "未知")，相关度：\(.score | tonumber | . * 100 | round / 100)）"'
  echo ""
fi

# 展示对话记忆
if [ "$TOTAL_MEMORIES" -gt 0 ]; then
  echo "【对话记忆】"
  echo "$RESPONSE" | jq -r '.memories[] | "
与 \(.conversation_name) 的对话（\(.timestamp | strftime("%Y-%m-%d"))，相关度：\(.relevance_score | tonumber | . * 100 | round / 100)）：
\(.content)
召回原因：\(.recall_reason)
---"'
fi

echo ""
echo "=== 搜索完成 ==="
