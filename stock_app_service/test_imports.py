#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""测试所有导入是否正常"""

import sys

def test_imports():
    """测试所有模块导入"""
    errors = []
    
    # 测试 scheduler 模块
    try:
        from app.services.scheduler import (
            start_stock_scheduler,
            stop_stock_scheduler,
            init_stock_system
        )
        print("✓ scheduler 模块导入成功")
    except Exception as e:
        errors.append(f"✗ scheduler 模块导入失败: {e}")
    
    # 测试 stock 模块
    try:
        from app.services.stock import (
            StockDataManager,
            stock_data_manager
        )
        print("✓ stock 模块导入成功")
    except Exception as e:
        errors.append(f"✗ stock 模块导入失败: {e}")
    
    # 测试 signal 模块
    try:
        from app.services.signal import (
            SignalManager,
            signal_manager
        )
        print("✓ signal 模块导入成功")
    except Exception as e:
        errors.append(f"✗ signal 模块导入失败: {e}")
    
    # 测试 etf 模块
    try:
        from app.services.etf import etf_manager
        print("✓ etf 模块导入成功")
    except Exception as e:
        errors.append(f"✗ etf 模块导入失败: {e}")
    
    # 测试 analysis 模块
    try:
        from app.services.analysis import get_news_sentiment_analysis
        print("✓ analysis 模块导入成功")
    except Exception as e:
        errors.append(f"✗ analysis 模块导入失败: {e}")
    
    # 测试 realtime 模块
    try:
        from app.services.realtime import get_proxy_manager
        print("✓ realtime 模块导入成功")
    except Exception as e:
        errors.append(f"✗ realtime 模块导入失败: {e}")
    
    # 测试 main.py
    try:
        from app.main import app
        print("✓ main.py 导入成功")
    except Exception as e:
        errors.append(f"✗ main.py 导入失败: {e}")
    
    # 输出结果
    print("\n" + "="*50)
    if errors:
        print("发现错误:")
        for error in errors:
            print(f"  {error}")
        return 1
    else:
        print("✓ 所有模块导入测试通过！")
        return 0

if __name__ == "__main__":
    sys.exit(test_imports())

