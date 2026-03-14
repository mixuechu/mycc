#!/bin/bash
# CC Recall - 从 CC Memory 检索工作学习记忆 + 归档对话

set -e

# 读取环境变量
if [ -f "/home/mycc/mycc/.env" ]; then
  export $(grep -v '^#' /home/mycc/mycc/.env | grep -E '^CC_MEMORY_' | xargs)
fi

# 检查必需的环境变量
if [ -z "$CC_MEMORY_API_URL" ]; then
  echo "错误：未配置 CC_MEMORY_API_URL"
  echo "请在 /home/mycc/mycc/.env 文件中添加："
  echo "CC_MEMORY_API_URL=http://103.30.78.193/api/cc"
  exit 1
fi

if [ -z "$CC_MEMORY_API_KEY" ]; then
  echo "错误：未配置 CC_MEMORY_API_KEY"
  echo "请在 /home/mycc/mycc/.env 文件中添加："
  echo "CC_MEMORY_API_KEY=CCM_k9L3mN7pQ2sR5tV8wX1yZ4aB6cD"
  exit 1
fi

# 解析命令
COMMAND="${1:-stats}"

# ============================================
# 显示用法
# ============================================
show_usage() {
  echo "CC Recall - 工作学习记忆检索与归档"
  echo ""
  echo "用法："
  echo "  $0 [command] [options]"
  echo ""
  echo "命令："
  echo "  stats                     查看归档统计（默认）"
  echo "  recall <query>            检索对话（未实现）"
  echo "  archive <summary> <importance> [tags]  归档对话"
  echo ""
  echo "归档示例："
  echo "  $0 archive \"讨论了双记忆库架构\" 0.85 \"架构设计,记忆系统\""
  echo "  $0 archive \"修复了前端bug\" 0.6"
  echo ""
  echo "检索示例："
  echo "  $0 recall \"我们上次怎么整合的\""
  echo ""
  echo "统计示例："
  echo "  $0 stats"
  echo "  $0"
  exit 0
}

# 检查是否需要显示帮助
if [ "$COMMAND" = "-h" ] || [ "$COMMAND" = "--help" ] || [ "$COMMAND" = "help" ]; then
  show_usage
fi

# ============================================
# 功能 1: 查看归档统计（当前可用）
# ============================================
if [ "$COMMAND" = "stats" ] || [ -z "$COMMAND" ]; then
  echo "正在查询 CC Memory 归档统计..."
  echo ""

  RESPONSE=$(curl -s "$CC_MEMORY_API_URL/archive/stats" \
    -H "X-API-Key: $CC_MEMORY_API_KEY")

  # 检查 API 响应
  if [ -z "$RESPONSE" ]; then
    echo "错误：API 无响应"
    exit 1
  fi

  # 检查是否有错误
  ERROR=$(echo "$RESPONSE" | jq -r 'select(.detail != null) | .detail' 2>/dev/null || echo "")
  if [ -n "$ERROR" ]; then
    echo "API 错误：$ERROR"
    exit 1
  fi

  # 解析统计信息
  TOTAL=$(echo "$RESPONSE" | jq -r '.total_conversations // 0')
  TOTAL_MESSAGES=$(echo "$RESPONSE" | jq -r '.total_messages // 0')
  AVG_IMPORTANCE=$(echo "$RESPONSE" | jq -r '.avg_importance // 0')

  echo "=== CC Memory 归档统计 ==="
  echo "已归档对话：$TOTAL 条"
  echo "总消息数：$TOTAL_MESSAGES 条"
  echo "平均重要性：$AVG_IMPORTANCE"
  echo ""

  # 显示最近归档
  RECENT_COUNT=$(echo "$RESPONSE" | jq -r '.recent_archives | length')
  if [ "$RECENT_COUNT" -gt 0 ]; then
    echo "【最近归档的对话】"
    echo "$RESPONSE" | jq -r '.recent_archives[] | "- \(.summary)（重要性：\(.importance)，时间：\(.archived_at | split("T")[0])）"'
  else
    echo "暂无归档对话"
  fi

  echo ""
  echo "提示："
  echo "- 使用 $0 archive 可以归档新对话"
  echo "- 使用 $0 recall 可以检索历史对话（开发中）"
  echo ""
  exit 0
fi

# ============================================
# 功能 2: 归档对话（新功能）
# ============================================
if [ "$COMMAND" = "archive" ]; then
  SUMMARY="${2:-}"
  IMPORTANCE="${3:-0.5}"
  TAGS="${4:-}"
  
  # 验证参数
  if [ -z "$SUMMARY" ]; then
    echo "错误：缺少对话摘要"
    echo ""
    echo "用法: $0 archive <summary> <importance> [tags]"
    echo ""
    echo "示例:"
    echo "  $0 archive \"讨论了双记忆库架构\" 0.85 \"架构设计,记忆系统\""
    echo "  $0 archive \"修复了前端bug\" 0.6"
    exit 1
  fi
  
  # 验证重要性评分
  if ! echo "$IMPORTANCE" | grep -qE '^[0-9]*\.?[0-9]+$' || \
     [ "$(echo "$IMPORTANCE < 0" | bc)" -eq 1 ] || \
     [ "$(echo "$IMPORTANCE > 1" | bc)" -eq 1 ]; then
    echo "错误：重要性评分必须在 0-1 之间"
    echo "当前值：$IMPORTANCE"
    exit 1
  fi
  
  # 构造标签数组
  if [ -n "$TAGS" ]; then
    # 将逗号分隔的标签转换为JSON数组
    TAG_ARRAY=$(echo "$TAGS" | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/' )
  else
    TAG_ARRAY="[]"
  fi
  
  # 生成时间戳
  TIMESTAMP=$(date +%s)
  
  # 构造归档请求（使用占位消息）
  # 注意：理想情况下应该传入真实对话内容，这里先用摘要作为占位
  ARCHIVE_DATA=$(cat <<EOF
{
  "timestamp": $TIMESTAMP,
  "messages": [
    {
      "role": "user",
      "content": "（对话摘要：$SUMMARY）",
      "timestamp": $TIMESTAMP
    }
  ],
  "summary": "$SUMMARY",
  "tags": $TAG_ARRAY,
  "importance": $IMPORTANCE
}
EOF
)

  echo "正在归档对话..."
  echo "摘要：$SUMMARY"
  echo "重要性：$IMPORTANCE"
  if [ -n "$TAGS" ]; then
    echo "标签：$TAGS"
  fi
  echo ""
  
  # 调用归档 API
  RESPONSE=$(curl -s -X POST "$CC_MEMORY_API_URL/archive" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $CC_MEMORY_API_KEY" \
    -d "$ARCHIVE_DATA")
  
  # 检查响应
  if [ -z "$RESPONSE" ]; then
    echo "错误：API 无响应"
    exit 1
  fi
  
  # 检查是否有错误
  ERROR=$(echo "$RESPONSE" | jq -r 'select(.detail != null) | .detail' 2>/dev/null || echo "")
  if [ -n "$ERROR" ]; then
    echo "归档失败：$ERROR"
    exit 1
  fi
  
  # 解析结果
  STATUS=$(echo "$RESPONSE" | jq -r '.status // "unknown"')
  CONV_ID=$(echo "$RESPONSE" | jq -r '.conversation_id // "unknown"')
  MESSAGE=$(echo "$RESPONSE" | jq -r '.message // ""')
  
  if [ "$STATUS" = "ok" ]; then
    echo "✅ 归档成功！"
    echo ""
    echo "对话ID：$CONV_ID"
    if [ -n "$MESSAGE" ]; then
      echo "$MESSAGE"
    fi
    echo ""
    echo "提示："
    echo "- 使用 $0 stats 可以查看归档统计"
    echo "- 使用 $0 recall 可以检索这段对话（开发中）"
  else
    echo "❌ 归档失败"
    echo "$RESPONSE"
    exit 1
  fi
  
  exit 0
fi

# ============================================
# 功能 3: 检索对话（未来功能）
# ============================================
if [ "$COMMAND" = "recall" ]; then
  QUERY="${2:-}"
  TOP_K="${3:-5}"
  MIN_RELEVANCE="${4:-0.3}"
  
  if [ -z "$QUERY" ]; then
    echo "错误：缺少检索关键词"
    echo ""
    echo "用法: $0 recall <query> [top_k] [min_relevance]"
    echo ""
    echo "参数:"
    echo "  query         - 检索关键词（必填）"
    echo "  top_k         - 返回结果数量（默认: 5）"
    echo "  min_relevance - 最低相关度 0-1（默认: 0.3）"
    echo ""
    echo "示例:"
    echo "  $0 recall \"我们上次怎么整合的\""
    echo "  $0 recall \"双记忆库架构\" 3"
    echo "  $0 recall \"Phase3归档\" 5 0.4"
    exit 1
  fi
  
  # 验证top_k和min_relevance是数字
  if ! [[ "$TOP_K" =~ ^[0-9]+$ ]]; then
    echo "错误：top_k 必须是数字"
    exit 1
  fi
  
  if ! [[ "$MIN_RELEVANCE" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    echo "错误：min_relevance 必须是数字（0-1之间）"
    exit 1
  fi
  
  echo "🔍 检索中: \"$QUERY\"..."
  echo ""
  
  # 调用 CC Memory API
  RECALL_DATA=$(cat <<EOF
{
  "query": "$QUERY",
  "top_k": $TOP_K,
  "min_relevance": $MIN_RELEVANCE
}
EOF
)
  
  RESPONSE=$(curl -s -X POST "${CC_MEMORY_API_URL}/recall" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: ${CC_MEMORY_API_KEY}" \
    -d "$RECALL_DATA")
  
  # 检查是否有错误
  if echo "$RESPONSE" | grep -q '"detail"'; then
    echo "❌ 检索失败"
    echo ""
    echo "错误信息:"
    echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('detail', 'Unknown error'))" 2>/dev/null || echo "$RESPONSE"
    exit 1
  fi
  
  # 解析并显示结果
  TOTAL=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('total', 0))" 2>/dev/null)
  
  if [ "$TOTAL" -eq 0 ]; then
    echo "😔 未找到相关对话"
    echo ""
    echo "提示:"
    echo "  - 尝试调整关键词"
    echo "  - 降低相关度阈值（当前: $MIN_RELEVANCE）"
    exit 0
  fi
  
  echo "✅ 找到 $TOTAL 条相关对话:"
  echo ""
  
  # 格式化输出每条结果
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "$RESPONSE" | python3 "$SCRIPT_DIR/format_recall_results.py"
  
  exit 0
fi


# ============================================
# 未知命令
# ============================================
echo "错误：未知命令 '$COMMAND'"
echo ""
show_usage
