#!/bin/bash
# MyCC 后端启动脚本（干净环境，不继承 CLAUDECODE）

cd /root/mycc

# 清除 CLAUDECODE 环境变量
unset CLAUDECODE
unset CLAUDE_CODE_ENTRYPOINT

# 设置必要的环境变量
export CLAUDE_PATH="/usr/lib/node_modules/@anthropic-ai/claude-code/cli.js"

# 启动后端
echo "=== $(date) ===" >> .claude/skills/mycc/mycc.log
nohup .claude/skills/mycc/scripts/node_modules/.bin/tsx .claude/skills/mycc/scripts/src/index.ts start >> .claude/skills/mycc/mycc.log 2>&1 &

echo "后端已启动，PID: $!"
