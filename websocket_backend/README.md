# MyCC WebSocket Backend

WebSocket 服务器，连接萌二前端与 Claude Code CLI

## 🚀 部署状态

- **状态**: ✅ 运行中
- **服务**: systemd (mycc-websocket)
- **端口**: 8005
- **工作目录**: /home/mycc/mycc/websocket_backend

## 📡 端点

### HTTP 端点
- **根路径**: http://103.30.78.193:8005/
- **健康检查**: http://103.30.78.193:8005/health
- **会话列表**: http://103.30.78.193:8005/api/sessions

### WebSocket 端点
- **主端点**: ws://103.30.78.193:8005/ws

## 🔧 管理命令

### 查看状态
```bash
sudo systemctl status mycc-websocket
```

### 启动/停止/重启
```bash
sudo systemctl start mycc-websocket
sudo systemctl stop mycc-websocket
sudo systemctl restart mycc-websocket
```

### 查看日志
```bash
sudo journalctl -u mycc-websocket -f
```

## 🧪 测试

### 浏览器控制台
```javascript
const ws = new WebSocket('ws://103.30.78.193:8005/ws')
ws.onmessage = (e) => console.log(JSON.parse(e.data))
ws.send(JSON.stringify({ type: 'input', text: '你好' }))
```

### 健康检查
```bash
curl http://103.30.78.193:8005/health
```

## 📂 文件结构

```
websocket_backend/
├── claude_process_manager.py  # Claude CLI 进程管理
├── session_manager.py         # WebSocket 会话管理
├── memory_archiver.py         # CC Memory 归档
├── server.py                  # 主服务器
├── requirements.txt           # 依赖
├── .env                       # 配置
└── start.sh                   # 启动脚本
```

## ⚙️ 配置 (.env)

```bash
CLAUDE_WORKSPACE=/home/mycc/mycc
CC_MEMORY_API_URL=http://103.30.78.193:8003/api/archive
CC_MEMORY_API_KEY=CCM_k9L3mN7pQ2sR5tV8wX1yZ4aB6cD
WS_HOST=0.0.0.0
WS_PORT=8005
```

---

**版本**: 1.0.0
**部署时间**: 2026-03-15
**状态**: ✅ 生产环境运行中
