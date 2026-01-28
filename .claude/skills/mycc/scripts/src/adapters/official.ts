/**
 * 官方 Claude Code SDK 实现
 */

import { query } from "@anthropic-ai/claude-code";
import type { CCAdapter, SSEEvent } from "./interface.js";
import type { ChatParams, ConversationSummary, ConversationHistory } from "../types.js";
import { getConversationList, getConversation } from "../history.js";
import { detectClaudeCliPath, isWindows } from "../platform.js";

// 检测 Claude CLI 路径（跨平台）
const { executable: CLAUDE_EXECUTABLE, cliPath: CLAUDE_CLI_PATH } = detectClaudeCliPath();

/**
 * 官方 Claude Code SDK Adapter
 */
export class OfficialAdapter implements CCAdapter {
  /**
   * 发送消息，返回 SSE 事件流
   */
  async *chat(params: ChatParams): AsyncIterable<SSEEvent> {
    const { message, sessionId, cwd } = params;

    // 构造 SDK 选项（Windows 不指定 executable，使用 native binary）
    const sdkOptions: Parameters<typeof query>[0]["options"] = {
      pathToClaudeCodeExecutable: CLAUDE_CLI_PATH,
      cwd: cwd || process.cwd(),
      resume: sessionId || undefined,
      permissionMode: "bypassPermissions",
    };

    // 如果检测到需要用 node 执行（npm 全局安装），设置 executable
    if (CLAUDE_EXECUTABLE === "node") {
      sdkOptions.executable = "node" as const;
    }

    for await (const sdkMessage of query({
      prompt: message,
      options: sdkOptions,
    })) {
      yield sdkMessage as SSEEvent;
    }
  }

  /**
   * 获取历史记录列表
   */
  async listHistory(cwd: string, limit?: number): Promise<{
    conversations: ConversationSummary[];
    total: number;
    hasMore: boolean;
  }> {
    let conversations = getConversationList(cwd);
    const total = conversations.length;

    // 如果 limit > 0，只返回前 limit 条
    if (limit && limit > 0) {
      conversations = conversations.slice(0, limit);
    }

    return {
      conversations,
      total,
      hasMore: conversations.length < total,
    };
  }

  /**
   * 获取单个对话详情
   */
  async getHistory(cwd: string, sessionId: string): Promise<ConversationHistory | null> {
    return getConversation(cwd, sessionId);
  }
}
