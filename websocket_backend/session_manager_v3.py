"""
WebSocket Session 管理器 V3
使用简化的Claude进程管理器
"""
import asyncio
from typing import Dict, Optional, List, Any
from datetime import datetime
from fastapi import WebSocket

from claude_process_v3 import ClaudeProcessV3


class WebSocketSession:
    """单个 WebSocket 会话"""

    def __init__(self, session_id: str, websocket: WebSocket, project_path: str = "."):
        self.session_id = session_id
        self.websocket = websocket
        self.project_path = project_path
        self.claude_manager: Optional[ClaudeProcessV3] = None
        self.created_at = datetime.now()
        self.last_activity = datetime.now()
        self.status = "active"
        self.message_buffer: List[Dict[str, Any]] = []
        self.cleanup_task: Optional[asyncio.Task] = None

    async def start_claude(self):
        """创建 Claude 管理器"""
        if self.claude_manager:
            return  # 已存在

        self.claude_manager = ClaudeProcessV3(
            on_message=self._on_claude_message
        )
        print(f"[Session:{self.session_id}] Claude manager created")

    async def _on_claude_message(self, event: Dict[str, Any]):
        """Claude 消息回调"""
        self.last_activity = datetime.now()

        # 缓存消息
        self.message_buffer.append(event)
        if len(self.message_buffer) > 100:
            self.message_buffer = self.message_buffer[-100:]

        # 转发给 WebSocket
        if self.websocket and self.status == "active":
            try:
                await self.websocket.send_json(event)
            except Exception as e:
                print(f"[Session:{self.session_id}] Send failed: {e}")
                self.status = "disconnected"

    async def send_to_claude(self, user_input: str):
        """发送消息到 Claude"""
        if not self.claude_manager:
            raise RuntimeError("Claude manager not initialized")

        self.last_activity = datetime.now()

        # 直接调用，Claude CLI 自己维护 session 上下文
        await self.claude_manager.send_message(user_input, self.project_path)

    def is_processing(self) -> bool:
        """是否正在处理消息"""
        return self.claude_manager and self.claude_manager.is_running


class WebSocketSessionManager:
    """全局 Session 管理器"""

    def __init__(self):
        self.sessions: Dict[str, WebSocketSession] = {}

    def create_session(
        self,
        websocket: WebSocket,
        session_id: Optional[str] = None,
        project_path: str = "."
    ) -> WebSocketSession:
        """创建或恢复会话"""
        # 默认使用固定session ID，让二萌永远记得所有对话
        if session_id is None:
            session_id = "mycc-main-session"

        if session_id in self.sessions:
            # 恢复现有会话
            existing = self.sessions[session_id]
            existing.websocket = websocket
            existing.status = "active"
            existing.last_activity = datetime.now()

            if existing.cleanup_task and not existing.cleanup_task.done():
                existing.cleanup_task.cancel()
                existing.cleanup_task = None

            print(f"[SessionManager] Resumed: {session_id}")
            return existing

        # 创建新会话
        session = WebSocketSession(
            session_id=session_id,
            websocket=websocket,
            project_path=project_path
        )

        self.sessions[session_id] = session
        print(f"[SessionManager] Created: {session_id}")

        return session

    def get_session(self, session_id: str) -> Optional[WebSocketSession]:
        """获取会话"""
        return self.sessions.get(session_id)

    async def disconnect_session(self, session_id: str, delay: float = 5.0):
        """标记会话断开，延迟清理"""
        session = self.sessions.get(session_id)
        if not session:
            return

        print(f"[SessionManager] Disconnected: {session_id}, cleanup in {delay}s")
        session.status = "disconnected"

        async def cleanup():
            await asyncio.sleep(delay)

            if session.status == "disconnected":
                print(f"[SessionManager] Cleaning up: {session_id}")
                # TODO: 归档到 CC Memory
                self.sessions.pop(session_id, None)
            else:
                print(f"[SessionManager] {session_id} reconnected, skip cleanup")

        session.cleanup_task = asyncio.create_task(cleanup())

    async def replay_messages(self, session_id: str, websocket: WebSocket):
        """重放消息缓存"""
        session = self.sessions.get(session_id)
        if not session:
            return

        print(f"[SessionManager] Replaying {len(session.message_buffer)} messages")

        for event in session.message_buffer:
            try:
                await websocket.send_json(event)
            except Exception as e:
                print(f"[SessionManager] Replay failed: {e}")
                break

    def get_all_sessions(self) -> Dict[str, Dict[str, Any]]:
        """获取所有会话状态"""
        return {
            sid: {
                "status": s.status,
                "created_at": s.created_at.isoformat(),
                "last_activity": s.last_activity.isoformat(),
                "message_count": len(s.message_buffer),
                "is_processing": s.is_processing()
            }
            for sid, s in self.sessions.items()
        }


# 全局单例
_session_manager = WebSocketSessionManager()


def get_session_manager() -> WebSocketSessionManager:
    """获取全局 Session Manager"""
    return _session_manager
