/**
 * Tunnel Provider 接口抽象
 *
 * 为未来支持多种隧道方案预留接口：
 * - CloudflareProvider（当前实现）
 * - SSHProvider（待实现）
 */

import type { ChildProcess } from "child_process";
import { spawn } from "child_process";
import { detectCloudflaredPath, NULL_DEVICE, killPortProcess } from "./platform.js";

// ============ 接口定义 ============

export interface TunnelResult {
  url: string;
  proc?: ChildProcess;
}

export interface TunnelProvider {
  /**
   * 启动隧道
   * @param localPort 本地服务端口
   * @returns 隧道 URL 和进程引用
   */
  start(localPort: number): Promise<TunnelResult>;

  /**
   * 停止隧道
   */
  stop(): void;

  /**
   * 健康检查
   * @returns true 表示隧道正常
   */
  healthCheck(): Promise<boolean>;

  /**
   * 获取 Provider 名称
   */
  getName(): string;
}

// ============ CloudflareProvider 实现 ============

export class CloudflareProvider implements TunnelProvider {
  private proc: ChildProcess | null = null;
  private tunnelUrl: string | null = null;
  private startTimeout: number;
  private localPort: number = 0;

  /**
   * @param startTimeout 启动超时时间（毫秒），默认 15 秒
   */
  constructor(startTimeout: number = 15000) {
    this.startTimeout = startTimeout;
  }

  async start(localPort: number): Promise<TunnelResult> {
    this.localPort = localPort;  // 保存端口号用于后续清理
    return new Promise((resolve, reject) => {
      // 获取 cloudflared 路径
      const cloudflaredPath = detectCloudflaredPath();
      // Windows: 路径加引号防止空格问题，shell: true 让系统 shell 解析命令
      const cmd = `"${cloudflaredPath}" tunnel --config ${NULL_DEVICE} --url http://localhost:${localPort}`;
      const proc = spawn(cmd, [], {
        stdio: ["ignore", "pipe", "pipe"],
        shell: true,
        windowsHide: true,
      });

      this.proc = proc;
      let resolved = false;
      const urlPattern = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/;

      const handleOutput = (data: Buffer) => {
        const output = data.toString();
        const match = output.match(urlPattern);
        if (match && !resolved) {
          resolved = true;
          this.tunnelUrl = match[0];
          resolve({ url: match[0], proc });
        }
      };

      proc.stdout?.on("data", handleOutput);
      proc.stderr?.on("data", handleOutput);

      proc.on("error", (err) => {
        if (!resolved) {
          resolved = true;
          this.proc = null;
          reject(new Error(`Tunnel 启动失败: ${err.message}`));
        }
      });

      setTimeout(() => {
        if (!resolved) {
          resolved = true;
          // 超时，杀掉进程
          try {
            proc.kill();
          } catch {}
          this.proc = null;
          reject(new Error("Tunnel 启动超时"));
        }
      }, this.startTimeout);
    });
  }

  stop(): void {
    if (this.proc) {
      try {
        // 直接强杀，不搞优雅那套
        this.proc.kill("SIGKILL");
      } catch {}
      this.proc = null;
    }

    // 使用跨平台的端口清理（替代 pkill，支持 Windows）
    if (this.localPort) {
      killPortProcess(this.localPort).catch(() => {
        // 静默处理失败，不影响主流程
      });
    }

    this.tunnelUrl = null;
    this.localPort = 0;
  }

  async healthCheck(): Promise<boolean> {
    if (!this.tunnelUrl) {
      return false;
    }

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 10000);

      const response = await fetch(`${this.tunnelUrl}/health`, {
        signal: controller.signal,
      });

      clearTimeout(timeoutId);
      return response.ok;
    } catch {
      return false;
    }
  }

  getName(): string {
    return "cloudflare";
  }

  /**
   * 获取当前隧道 URL
   */
  getUrl(): string | null {
    return this.tunnelUrl;
  }

  /**
   * 获取进程引用（用于外部监控）
   */
  getProc(): ChildProcess | null {
    return this.proc;
  }
}
