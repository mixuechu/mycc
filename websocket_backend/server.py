"""
MyCC WebSocket 服务器
提供实时流式 Claude Code CLI 交互
"""
import os
import json
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
from dotenv import load_dotenv
from pathlib import Path

from session_manager_v3 import get_session_manager


# 加载环境变量
load_dotenv()

# 创建 FastAPI 应用
app = FastAPI(
    title="MyCC WebSocket Backend",
    description="WebSocket服务器，连接萌二前端与Claude Code CLI",
    version="1.0.0",
)

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 获取全局 Session Manager
session_manager = get_session_manager()


# ============ Message Parser ============

class ClaudeMessageParser:
    """解析Claude Code保存的JSONL消息"""

    def __init__(self, project_path: str = "/home/mycc/mycc", home_dir: str = "/home/mycc"):
        self.project_path = project_path
        # Claude项目目录格式：~/.claude/projects/<encoded-path>/
        encoded_path = project_path.replace("/", "-")
        self.claude_project_dir = Path(home_dir) / ".claude" / "projects" / encoded_path

    def get_session_file(self, session_id: str) -> Optional[Path]:
        """获取session的JSONL文件路径"""
        session_file = self.claude_project_dir / f"{session_id}.jsonl"
        if session_file.exists():
            return session_file
        return None

    def parse_messages(
        self,
        session_id: str,
        offset: int = 0,
        limit: int = 20
    ) -> dict:
        """分页解析session的消息"""
        session_file = self.get_session_file(session_id)
        if not session_file:
            return {
                "session_id": session_id,
                "total": 0,
                "offset": offset,
                "limit": limit,
                "messages": []
            }

        # 读取所有行
        lines = []
        with open(session_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        # 解析消息
        messages = []
        for line in lines:
            try:
                data = json.loads(line.strip())
                msg = self._parse_message(data)
                if msg:
                    messages.append(msg)
            except json.JSONDecodeError:
                continue

        # 分页
        total = len(messages)
        paginated = messages[offset:offset + limit]

        return {
            "session_id": session_id,
            "total": total,
            "offset": offset,
            "limit": limit,
            "messages": paginated
        }

    def _parse_message(self, data: dict) -> Optional[dict]:
        """解析单条消息"""
        msg_type = data.get("type")

        # 只处理user和assistant消息
        if msg_type not in ["user", "assistant"]:
            return None

        message_content = data.get("message", {})
        role = message_content.get("role")

        if not role:
            return None

        # 基础信息
        result = {
            "uuid": data.get("uuid"),
            "role": role,
            "timestamp": data.get("timestamp"),
            "content": "",
            "thinking": None,
            "tool_calls": [],
            "tool_results": []
        }

        # 解析content
        content_items = message_content.get("content", [])
        if isinstance(content_items, str):
            result["content"] = content_items
        elif isinstance(content_items, list):
            text_parts = []
            for item in content_items:
                if isinstance(item, dict):
                    item_type = item.get("type")

                    if item_type == "text":
                        text_parts.append(item.get("text", ""))

                    elif item_type == "thinking":
                        result["thinking"] = item.get("thinking")

                    elif item_type == "tool_use":
                        result["tool_calls"].append({
                            "id": item.get("id"),
                            "name": item.get("name"),
                            "input": item.get("input", {})
                        })

                    elif item_type == "tool_result":
                        result["tool_results"].append({
                            "tool_use_id": item.get("tool_use_id"),
                            "content": item.get("content"),
                            "is_error": item.get("is_error", False)
                        })
                elif isinstance(item, str):
                    text_parts.append(item)

            result["content"] = "".join(text_parts)

        # 过滤掉没有实际文本内容的assistant消息
        if not result["content"].strip():
            return None
        
        return result


# 创建全局parser实例
message_parser = ClaudeMessageParser()


# ============ API Endpoints ============

@app.get("/")
async def root():
    """根路径"""
    return {
        "message": "MyCC WebSocket Backend API",
        "version": "1.0.0",
        "websocket_endpoint": "ws://host:port/ws",
        "history_endpoint": "http://host:port/api/session/{session_id}/messages"
    }


@app.get("/health")
async def health():
    """健康检查"""
    return {
        "status": "healthy",
        "active_sessions": len(session_manager.sessions)
    }


@app.get("/api/sessions")
async def get_sessions():
    """获取所有活跃会话（调试用）"""
    return {
        "sessions": session_manager.get_all_sessions(),
        "total": len(session_manager.sessions)
    }


@app.get("/api/session/{session_id}/messages")
async def get_session_messages(
    session_id: str,
    offset: int = Query(0, ge=0, description="分页偏移量"),
    limit: int = Query(20, ge=1, le=100, description="每页消息数量")
):
    """
    获取session的历史消息（分页）

    Args:
        session_id: Claude session ID
        offset: 分页偏移量（默认0）
        limit: 每页消息数量（默认20，最大100）

    Returns:
        {
            "session_id": "xxx",
            "total": 50,
            "offset": 0,
            "limit": 20,
            "messages": [...]
        }
    """
    try:
        result = message_parser.parse_messages(session_id, offset, limit)

        if result["total"] == 0:
            raise HTTPException(
                status_code=404,
                detail=f"Session {session_id} not found or has no messages"
            )

        return result

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to parse messages: {str(e)}"
        )


@app.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    session_id: Optional[str] = Query(None),
    project_path: Optional[str] = Query(None)
):
    """
    WebSocket 端点：实时流式对话

    Args:
        websocket: WebSocket 连接
        session_id: 可选的会话ID（用于恢复会话）
        project_path: Claude Code 工作目录（默认为 MyCC workspace）
    """
    await websocket.accept()

    # 默认工作目录为 MyCC workspace
    if project_path is None:
        project_path = os.getenv("CLAUDE_WORKSPACE", "/home/mycc/mycc")

    print(f"[WebSocket] New connection, session_id={session_id}, project_path={project_path}")

    # 创建或恢复会话
    session = session_manager.create_session(
        websocket=websocket,
        session_id=session_id,
        project_path=project_path
    )

    try:
        # 发送会话ID给客户端
        await websocket.send_json({
            "type": "session_started",
            "session_id": session.session_id,
            "timestamp": session.created_at.isoformat(),
            "project_path": project_path
        })

        # 如果是恢复会话，重放历史消息
        if session_id and len(session.message_buffer) > 0:
            await session_manager.replay_messages(session.session_id, websocket)

        # 不要在连接时启动Claude，等待第一次消息时再启动
        # Claude CLI需要stdin输入，空启动会失败
        # 主循环：处理客户端消息
        while True:
            # 接收客户端消息
            data = await websocket.receive_text()

            try:
                message = json.loads(data)
                await handle_client_message(session, message)

            except json.JSONDecodeError:
                # 如果不是 JSON，直接当作用户输入
                await session.send_to_claude(data)

    except WebSocketDisconnect:
        print(f"[WebSocket] Client disconnected: {session.session_id}")
        await session_manager.disconnect_session(session.session_id, delay=5.0)

    except Exception as e:
        print(f"[WebSocket] Error: {e}")
        await session_manager.disconnect_session(session.session_id, delay=0)

        # 发送错误消息给客户端（如果连接仍然活跃）
        try:
            await websocket.send_json({
                "type": "error",
                "content": str(e)
            })
        except:
            pass


async def handle_client_message(session, message: dict):
    """
    处理客户端消息

    支持的消息类型：
    - { "type": "input", "text": "..." } - 用户输入
    - { "type": "stop" } - 停止生成
    - { "type": "ping" } - 心跳
    """
    msg_type = message.get("type", "input")

    if msg_type == "input":
        # 用户输入
        text = message.get("text", "")
        if text:
            # 确保 Claude manager 已初始化（首次消息时）
            if not session.claude_manager:
                await session.start_claude()

            await session.send_to_claude(text)

    elif msg_type == "stop":
        # 停止生成（Claude CLI --print 模式下，进程在消息完成后自动退出）
        # TODO: 如果需要中断正在运行的进程，可以添加 process.terminate()

        # 发送停止确认
        await session.websocket.send_json({
            "type": "stopped",
            "timestamp": session.last_activity.isoformat()
        })

    elif msg_type == "ping":
        # 心跳
        await session.websocket.send_json({
            "type": "pong",
            "timestamp": session.last_activity.isoformat()
        })

    else:
        print(f"[WebSocket] Unknown message type: {msg_type}")


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("WS_HOST", "0.0.0.0")
    port = int(os.getenv("WS_PORT", "8005"))

    print(f"🚀 Starting MyCC WebSocket Backend on {host}:{port}")
    print(f"   WebSocket: ws://{host}:{port}/ws")
    print(f"   Health: http://{host}:{port}/health")
    print(f"   Sessions: http://{host}:{port}/api/sessions")
    print(f"   History: http://{host}:{port}/api/session/{{session_id}}/messages")

    uvicorn.run(app, host=host, port=port)
