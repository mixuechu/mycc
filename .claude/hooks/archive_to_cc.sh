#!/bin/bash
# Auto-archive conversation to CC Memory
# Triggered by Stop hook (when Claude completes response)

set -e

# Read hook input from stdin
INPUT=$(cat)

# Extract session info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "/home/mycc/mycc"')

# Get conversation context (last few messages)
# For now, use a simple placeholder - in production, this would extract from conversation history
CONVERSATION_SUMMARY="对话已完成 (session: $SESSION_ID)"

# Only archive if there was actual conversation
# (Skip if this is just a greeting or very short exchange)
# This is a simple heuristic - could be improved

# Call cc-recall to archive
CC_RECALL_SCRIPT="/home/mycc/mycc/.claude/skills/cc-recall/recall.sh"

if [ -f "$CC_RECALL_SCRIPT" ]; then
  # Archive with default importance 0.5 and "auto" tag
  # The script will handle the actual archiving
  "$CC_RECALL_SCRIPT" archive \
    "$CONVERSATION_SUMMARY" \
    0.5 \
    "auto-archived" \
    >/dev/null 2>&1 || true  # Don't fail if archive fails
fi

# Exit 0 to allow Claude to continue
exit 0
