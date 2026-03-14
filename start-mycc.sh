#!/bin/bash
# MyCC 后端启动脚本（mycc用户专用）

cd /home/mycc/mycc

# 清除 CLAUDECODE 环境变量
unset CLAUDECODE
unset CLAUDE_CODE_ENTRYPOINT

# 设置必要的环境变量
export CLAUDE_PATH="/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js"

# 设置 Google Cloud Vertex AI 环境变量
export GOOGLE_APPLICATION_CREDENTIALS="/home/mycc/vertex-sa.json"
export ANTHROPIC_VERTEX_PROJECT_ID="g-alpha-1680510686959"
export ANTHROPIC_MODEL="claude-sonnet-4-5@20250929"
export ANTHROPIC_SMALL_FAST_MODEL="claude-haiku-4-5@20251001"

# 启动后端
echo "=== $(date) ===" >> .claude/skills/mycc/mycc.log
nohup .claude/skills/mycc/scripts/node_modules/.bin/tsx .claude/skills/mycc/scripts/src/index.ts start >> .claude/skills/mycc/mycc.log 2>&1 &

echo "后端已启动，PID: $!"
