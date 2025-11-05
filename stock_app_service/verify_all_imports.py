#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""验证所有 __init__.py 中的导入是否正确"""

import sys
import importlib
import traceback

def check_module_exports(module_path, expected_exports):
    """检查模块是否能正确导出指定的内容"""
    try:
        module = importlib.import_module(module_path)
        missing = []
        for export in expected_exports:
            if not hasattr(module, export):
                missing.append(export)
        
        if missing:
            print(f"✗ {module_path}: 缺少导出 {missing}")
            return False
        else:
            print(f"✓ {module_path}: 所有导出正常")
            return True
    except Exception as e:
        print(f"✗ {module_path}: 导入失败")
        print(f"  错误: {e}")
        traceback.print_exc()
        return False

def main():
    """主函数"""
    print("="*60)
    print("验证所有模块导入")
    print("="*60)
    
    all_ok = True
    
    # 检查各个子模块
    modules_to_check = [
        ('app.services.scheduler', [
            'start_stock_scheduler',
            'stop_stock_scheduler',
            'init_stock_system',
            'update_realtime_stock_data',
            'update_etf_realtime_data',
            'trigger_stock_task',
            'start_news_scheduler',
            'stop_news_scheduler',
        ]),
        ('app.services.stock', [
            'StockDataManager',
            'stock_data_manager',
            'get_stocks',
            'get_all_stocks',
            'create_stock',
            'get_stock_by_code',
            'get_stock_names',
            'get_stock_history',
        ]),
        ('app.services.etf', [
            'ETFManager',
            'etf_manager',
        ]),
        ('app.services.signal', [
            'SignalManager',
            'signal_manager',
        ]),
        ('app.services.analysis', [
            'StockAIAnalysisService',
            'get_news_sentiment_analysis',
            'get_llm_service',
        ]),
        ('app.services.data', [
            'get_stock_history_tushare',
            'check_stock_data_integrity',
            'validate_all_stocks_data',
        ]),
        ('app.services.chart', [
            'ChartService',
        ]),
    ]
    
    for module_path, exports in modules_to_check:
        if not check_module_exports(module_path, exports):
            all_ok = False
    
    print("="*60)
    if all_ok:
        print("✓ 所有模块验证通过！")
        return 0
    else:
        print("✗ 部分模块验证失败")
        return 1

if __name__ == '__main__':
    sys.exit(main())

