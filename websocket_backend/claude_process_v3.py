"""
Claude Code CLI 进程管理器 V3
直接转发Claude CLI的所有输出，不做过多处理
"""
import asyncio
import json
import os
import uuid
from typing import Callable, Dict, Any


class ClaudeProcessV3:
    """简化版 - 直接转发Claude CLI输出"""

    def __init__(self, on_message: Callable[[Dict[str, Any]], None]):
        self.claude_session_id = str(uuid.uuid4())  # Claude CLI session ID
        self.on_message = on_message
        self.is_running = False
        self.message_count = 0  # 跟踪消息数量

    async def send_message(self, user_input: str, project_path: str = "."):
        """发送消息并转发所有输出"""
        if self.is_running:
            raise RuntimeError("Already processing a message")

        self.is_running = True
        self.message_count += 1

        # 第一条消息用 --session-id 创建会话，后续用 --resume 恢复
        if self.message_count == 1:
            cmd = [
                "claude",
                "--print",
                "--dangerously-skip-permissions",
                "--session-id", self.claude_session_id,
                "--output-format", "stream-json",
                "--verbose"
            ]
        else:
            cmd = [
                "claude",
                "--print",
                "--dangerously-skip-permissions",
                "--resume", self.claude_session_id,
                "--output-format", "stream-json",
                "--verbose"
            ]

        env = {**os.environ}
        env.pop('CLAUDECODE', None)

        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=project_path,
            env=env
        )

        print(f"[ClaudeV3] PID {process.pid}, session={self.claude_session_id[:8]}")

        # 发送消息并关闭 stdin（--print 模式需要 EOF）
        process.stdin.write(user_input.encode('utf-8') + b"\n")
        await process.stdin.drain()
        process.stdin.close()

        # 读取输出并推送
        await asyncio.gather(
            self._stream_output(process.stdout),
            self._read_stderr(process.stderr),
            process.wait()
        )

        self.is_running = False
        print(f"[ClaudeV3] Completed (message #{self.message_count})")

    async def _stream_output(self, stdout):
        """读取输出并直接转发，不做任何加工"""
        try:
            # 发送初始事件
            await self._push({"type": "system", "subtype": "processing"})

            while True:
                line = await stdout.readline()
                if not line:
                    break

                try:
                    data = json.loads(line.decode('utf-8'))

                    # 直接转发所有JSON事件
                    # Claude CLI会发送：
                    # - system 事件
                    # - stream_event 事件（工具调用等）
                    # - assistant 消息（包含thinking, text, usage等）
                    await self._push(data)

                except json.JSONDecodeError:
                    # 非JSON行，忽略
                    pass

        finally:
            # 发送完成信号
            await self._push({"type": "result", "status": "completed"})

    async def _read_stderr(self, stderr):
        """读取错误输出"""
        while True:
            line = await stderr.readline()
            if not line:
                break
            err_msg = line.decode('utf-8').strip()
            if err_msg and "using --print" not in err_msg:
                print(f"[ClaudeV3] stderr: {err_msg}")
                await self._push({"type": "error", "content": err_msg})

    async def _push(self, event: Dict[str, Any]):
        """推送到客户端"""
        try:
            result = self.on_message(event)
            if asyncio.iscoroutine(result):
                await result
        except Exception as e:
            print(f"[ClaudeV3] Push error: {e}")
