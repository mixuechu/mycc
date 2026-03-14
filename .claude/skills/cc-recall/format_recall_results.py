#!/usr/bin/env python3
import sys
import json
from datetime import datetime

# Read JSON from stdin
data = json.load(sys.stdin)
results = data.get('results', [])

for i, result in enumerate(results, 1):
    score = result.get('relevance_score', 0)
    summary = result.get('summary', 'N/A')
    timestamp = result.get('timestamp', 0)
    tags = result.get('tags', [])
    importance = result.get('importance', 0)
    
    # 转换时间戳
    try:
        dt = datetime.fromtimestamp(timestamp)
        time_str = dt.strftime('%Y-%m-%d %H:%M')
    except:
        time_str = 'Unknown'
    
    # 显示结果
    print(f"{i}. [{score:.3f}] {summary}")
    print(f"   时间: {time_str}")
    if tags:
        print(f"   标签: {', '.join(tags)}")
    print(f"   重要性: {importance}")
    print()
