#!/bin/bash
# sync_memory - 自动同步三文档记忆系统

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MYCC_DIR="/home/mycc/mycc"
MEMORY_DIR="$MYCC_DIR/0-System"

# 读取环境变量
if [ -f "$MYCC_DIR/.env" ]; then
  export $(grep -v '^#' "$MYCC_DIR/.env" | grep -E '^(GOOGLE_|VITE_|CC_MEMORY_)' | xargs)
fi

# ============================================
# 获取对话摘要
# ============================================
get_conversation_summary() {
  # 这里需要从某个地方获取最近的对话内容
  # 简化版：使用传入的参数或默认值
  SUMMARY="${1:-本次对话内容}"
  echo "$SUMMARY"
}

# ============================================
# 分析对话
# ============================================
analyze() {
  CONVERSATION_SUMMARY="$1"
  
  echo "[sync_memory] 分析对话中..." >&2
  
  # 调用 Python 分析脚本
  ANALYSIS_RESULT=$(python3 "$SCRIPT_DIR/analyze_memory.py" "$CONVERSATION_SUMMARY" "$MEMORY_DIR" 2>/dev/null)
  
  if [ $? -ne 0 ]; then
    echo "[ERROR] 分析失败" >&2
    return 1
  fi
  
  echo "$ANALYSIS_RESULT"
}

# ============================================
# 更新 status.md
# ============================================
update_status() {
  CONTENT="$1"
  
  echo "[sync_memory] 更新 status.md..." >&2
  
  # 确保目录存在
  mkdir -p "$MEMORY_DIR"
  
  # 写入新内容
  echo "$CONTENT" > "$MEMORY_DIR/status.md"
  
  echo "✓ status.md 已更新" >&2
}

# ============================================
# 更新 context.md
# ============================================
update_context() {
  APPEND_CONTENT="$1"
  NEW_WEEK="$2"
  
  echo "[sync_memory] 更新 context.md..." >&2
  
  # 确保目录存在
  mkdir -p "$MEMORY_DIR"
  
  if [ "$NEW_WEEK" = "true" ]; then
    # 新建本周（清空重开）
    echo "# Context（中期记忆）" > "$MEMORY_DIR/context.md"
    echo "" >> "$MEMORY_DIR/context.md"
    echo "## 本周概览" >> "$MEMORY_DIR/context.md"
    echo "" >> "$MEMORY_DIR/context.md"
    echo "## 每日快照" >> "$MEMORY_DIR/context.md"
    echo "" >> "$MEMORY_DIR/context.md"
  fi
  
  # 追加内容
  echo "$APPEND_CONTENT" >> "$MEMORY_DIR/context.md"
  
  echo "✓ context.md 已更新" >&2
}

# ============================================
# 更新 about-me
# ============================================
update_aboutme() {
  UPDATES_JSON="$1"
  
  echo "[sync_memory] 更新 about-me/..." >&2
  
  # 确保目录存在
  mkdir -p "$MEMORY_DIR/about-me"
  
  # 解析 JSON 并更新文件
  echo "$UPDATES_JSON" | python3 -c "
import sys
import json

try:
    updates = json.load(sys.stdin)
    for update in updates:
        filename = update['file']
        content = update['content']
        filepath = '$MEMORY_DIR/about-me/' + filename
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'✓ {filename} 已更新', file=sys.stderr)
except Exception as e:
    print(f'[ERROR] 更新失败: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# ============================================
# 归档到 CC Memory
# ============================================
archive_cc_memory() {
  CC_DATA_JSON="$1"
  
  echo "[sync_memory] 归档到 CC Memory..." >&2
  
  # 解析 JSON
  SUMMARY=$(echo "$CC_DATA_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('summary', ''))")
  IMPORTANCE=$(echo "$CC_DATA_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('importance', 0.5))")
  TAGS=$(echo "$CC_DATA_JSON" | python3 -c "import sys, json; print(','.join(json.load(sys.stdin).get('tags', [])))")
  
  # 调用 cc-recall archive
  CC_RECALL_SCRIPT="/home/mycc/mycc/.claude/skills/cc-recall/recall.sh"
  
  if [ -f "$CC_RECALL_SCRIPT" ]; then
    "$CC_RECALL_SCRIPT" archive "$SUMMARY" "$IMPORTANCE" "$TAGS" >/dev/null 2>&1
    echo "✓ CC Memory 已归档" >&2
  else
    echo "[WARNING] cc-recall 未安装，跳过归档" >&2
  fi
}

# ============================================
# 主函数
# ============================================
main() {
  CONVERSATION_SUMMARY="${1:-}"
  
  if [ -z "$CONVERSATION_SUMMARY" ]; then
    echo "用法: $0 <conversation_summary>"
    echo ""
    echo "示例:"
    echo "  $0 \"完成了 Phase 4 的实现\""
    exit 1
  fi
  
  # 1. 分析对话
  ANALYSIS=$(analyze "$CONVERSATION_SUMMARY")
  
  if [ -z "$ANALYSIS" ]; then
    echo "❌ 分析失败"
    exit 1
  fi
  
  # 2. 提取分析结果
  UPDATE_STATUS=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('update_status', False))")
  UPDATE_CONTEXT=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('update_context', False))")
  UPDATE_ABOUTME=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('update_aboutme', False))")
  ARCHIVE_CC=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('archive_cc_memory', False))")
  REASONING=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('reasoning', ''))")
  
  # 3. 执行更新
  UPDATED=()
  
  if [ "$UPDATE_STATUS" = "True" ]; then
    STATUS_CONTENT=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status_content', ''))")
    update_status "$STATUS_CONTENT"
    UPDATED+=("status.md")
  fi
  
  if [ "$UPDATE_CONTEXT" = "True" ]; then
    CONTEXT_APPEND=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('context_append', ''))")
    CONTEXT_NEW_WEEK=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('context_new_week', False))")
    update_context "$CONTEXT_APPEND" "$CONTEXT_NEW_WEEK"
    UPDATED+=("context.md")
  fi
  
  if [ "$UPDATE_ABOUTME" = "True" ]; then
    ABOUTME_UPDATES=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin).get('aboutme_updates', [])))")
    update_aboutme "$ABOUTME_UPDATES"
    UPDATED+=("about-me")
  fi
  
  if [ "$ARCHIVE_CC" = "True" ]; then
    CC_DATA=$(echo "$ANALYSIS" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin).get('cc_memory_data', {})))")
    archive_cc_memory "$CC_DATA"
    UPDATED+=("CC Memory")
  fi
  
  # 4. 输出结果
  if [ ${#UPDATED[@]} -gt 0 ]; then
    echo ""
    echo "💾 已更新：${UPDATED[*]}"
    if [ -n "$REASONING" ]; then
      echo "   理由：$REASONING"
    fi
  else
    echo ""
    echo "ℹ️  无需更新"
    if [ -n "$REASONING" ]; then
      echo "   理由：$REASONING"
    fi
  fi
}

# 执行主函数
main "$@"
