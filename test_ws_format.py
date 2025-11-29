#!/usr/bin/env python3
"""测试WebSocket推送的数据格式"""
import asyncio
import json
from app.services.websocket import price_publisher
from app.services.signal.signal_manager import signal_manager

async def test_format():
    # 获取策略的价格更新
    price_updates = await price_publisher._get_strategy_price_updates('volume_wave')
    
    print(f"获取到 {len(price_updates)} 个价格更新")
    
    if price_updates:
        # 打印前3个
        for i, update in enumerate(price_updates[:3]):
            print(f"\n更新 {i+1}:")
            print(f"  类型: {type(update)}")
            print(f"  内容: {update}")
            print(f"  model_dump: {update.model_dump()}")

if __name__ == "__main__":
    import sys
    sys.path.insert(0, '/Users/hsb/Downloads/stock_project/stock_app_service')
    asyncio.run(test_format())
