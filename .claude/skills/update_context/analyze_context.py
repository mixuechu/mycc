#!/usr/bin/env python3
"""
分析对话内容，判断是否需要更新三文档
注意：此脚本仅分析三文档更新，不处理CC Memory归档（由hook处理）
"""
import os
import sys
import json
from datetime import datetime
from dotenv import load_dotenv

# 加载环境变量
mycc_dir = os.getenv("MYCC_DIR", "/home/mycc/mycc")
env_file = os.path.join(mycc_dir, ".env")
if os.path.exists(env_file):
    load_dotenv(env_file)

from anthropic import AnthropicVertex

def read_file_safe(filepath):
    """安全读取文件，不存在则返回空字符串"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        return ""

def analyze_conversation(conversation_summary: str, memory_dir: str):
    """
    分析对话，判断是否需要更新三文档
    
    Args:
        conversation_summary: 对话摘要
        memory_dir: 记忆文件目录（0-System/）
    
    Returns:
        dict: 更新建议（仅三文档，不含CC Memory）
    """
    # 读取当前文档
    status_path = os.path.join(memory_dir, "status.md")
    context_path = os.path.join(memory_dir, "context.md")
    aboutme_dir = os.path.join(memory_dir, "about-me")
    
    current_status = read_file_safe(status_path)
    current_context = read_file_safe(context_path)
    
    # 读取 about-me 文件
    aboutme_files = {}
    if os.path.exists(aboutme_dir):
        for filename in os.listdir(aboutme_dir):
            if filename.endswith('.md') and filename != 'README.md':
                filepath = os.path.join(aboutme_dir, filename)
                aboutme_files[filename] = read_file_safe(filepath)
    
    # 获取当前日期和星期
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    weekday = now.strftime("%A")
    week_of_year = now.isocalendar()[1]
    
    # 获取项目配置
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("VITE_GOOGLE_CLOUD_PROJECT")
    region = os.getenv("GOOGLE_REGION") or os.getenv("VITE_GOOGLE_CLOUD_LOCATION")
    
    if not project_id or not region:
        raise ValueError(f"缺少 Google Cloud 配置: project_id={project_id}, region={region}")
    
    # 初始化 Vertex AI Client
    client = AnthropicVertex(
        project_id=project_id,
        region=region
    )
    
    # 构造分析 prompt  
    analysis_prompt = f"""你是三文档记忆系统管理员。分析对话，判断是否需要更新三文档。

**重要**：CC Memory 归档由 Stop hook 自动处理，你只需要判断三文档是否需要更新。

## 当前时间
- 日期：{today}
- 星期：{weekday}
- 第 {week_of_year} 周

## 当前三文档状态

### status.md（短期记忆 - 今日焦点）
```
{current_status if current_status else "（空文件）"}
```

### context.md（中期记忆 - 本周快照）
```
{current_context if current_context else "（空文件）"}
```

### about-me/（长期记忆 - 核心画像）
{json.dumps(aboutme_files, ensure_ascii=False, indent=2) if aboutme_files else "（无文件）"}

## 本次对话摘要
```
{conversation_summary}
```

## 你的任务

**仅判断三文档是否需要更新**（CC Memory归档由hook处理，无需关心）

判断标准：
1. **status.md** - 日期不是今天 OR 有重大进展（完成里程碑、项目状态变化）
2. **context.md** - 今天有重要进展需要记录（1-3句话概括）
3. **about-me** - 发现核心偏好/能力变化（需多次验证，不是单次提及）

**注意**：
- 普通bug修复、技术讨论 → 不更新三文档（已自动归档到CC Memory）
- 只有确实重要的进展才更新三文档
- 三文档是立即记忆，要保持精炼

## 输出格式

只返回 JSON：
```json
{{
  "update_status": true/false,
  "status_content": "完整的新 status.md 内容",
  
  "update_context": true/false,
  "context_append": "要追加的内容",
  "context_new_week": false,
  
  "update_aboutme": false,
  "aboutme_updates": [],
  
  "reasoning": "简短理由（说明为什么更新或不更新）"
}}
```
"""

    try:
        # 调用 Claude API
        response = client.messages.create(
            model="claude-sonnet-4-5@20250929",
            max_tokens=4096,
            messages=[{"role": "user", "content": analysis_prompt}]
        )
        
        # 提取返回的 JSON
        result_text = response.content[0].text.strip()
        
        # 移除可能的 markdown 代码块标记
        if result_text.startswith("```"):
            lines = result_text.split("\n")
            result_text = "\n".join(lines[1:-1]) if len(lines) > 2 else result_text
        if result_text.startswith("json"):
            result_text = result_text[4:].strip()
        
        result = json.loads(result_text)
        return result
        
    except Exception as e:
        print(f"[ERROR] 分析失败: {e}", file=sys.stderr)
        return {
            "update_status": False,
            "update_context": False,
            "update_aboutme": False,
            "reasoning": f"分析失败: {str(e)}"
        }

def main():
    if len(sys.argv) < 3:
        print("Usage: analyze_context.py <conversation_summary> <memory_dir>")
        sys.exit(1)
    
    conversation_summary = sys.argv[1]
    memory_dir = sys.argv[2]
    
    result = analyze_conversation(conversation_summary, memory_dir)
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
