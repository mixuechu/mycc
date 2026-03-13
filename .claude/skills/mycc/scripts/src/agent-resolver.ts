/**
 * Agent 目录解析器
 * 用于 Agent Teams 功能
 */

import { existsSync, readdirSync, statSync } from "fs";
import { join } from "path";

/**
 * 根据 agentId 解析 Agent 目录
 * @param agentId - Agent ID
 * @param agentsDir - Agents 根目录
 * @returns Agent 目录路径，如果不存在返回 null
 */
export function resolveAgentDir(agentId: string, agentsDir: string): string | null {
  const agentPath = join(agentsDir, agentId);
  if (existsSync(agentPath) && statSync(agentPath).isDirectory()) {
    return agentPath;
  }
  return null;
}

/**
 * 列出所有可用的 Agents
 * @param agentsDir - Agents 根目录
 * @returns Agent 列表
 */
export function listAgents(agentsDir: string): Array<{ id: string; name: string }> {
  if (!existsSync(agentsDir)) {
    return [];
  }

  try {
    const entries = readdirSync(agentsDir);
    return entries
      .filter((entry) => {
        const fullPath = join(agentsDir, entry);
        return statSync(fullPath).isDirectory();
      })
      .map((entry) => ({
        id: entry,
        name: entry,
      }));
  } catch {
    return [];
  }
}
