#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""测试所有导入是否正常"""

import sys
import traceback

def test_import(module_name, description):
    """测试单个模块导入"""
    try:
        __import__(module_name)
        print(f"✅ {description}: {module_name}")
        return True
    except Exception as e:
        print(f"❌ {description}: {module_name}")
        print(f"   错误: {e}")
        traceback.print_exc()
        return False

def main():
    """测试所有关键导入"""
    print("=" * 60)
    print("测试所有模块导入")
    print("=" * 60)
    
    tests = [
        # 核心配置
        ("app.core.config", "核心配置"),
        ("app.core.logging", "日志系统"),
        
        # 数据库和缓存
        ("app.db.redis_cache", "Redis缓存"),
        
        # 服务模块
        ("app.services.stock", "股票服务"),
        ("app.services.stock.stock_data_manager", "股票数据管理器"),
        ("app.services.stock.stock_crud", "股票CRUD"),
        ("app.services.stock.redis_stock_service", "Redis股票服务"),
        
        ("app.services.etf", "ETF服务"),
        ("app.services.etf.etf_manager", "ETF管理器"),
        
        ("app.services.signal", "信号服务"),
        ("app.services.signal.signal_manager", "信号管理器"),
        ("app.services.signal.signal_service", "信号服务"),
        
        ("app.services.scheduler", "调度器"),
        ("app.services.scheduler.stock_scheduler", "股票调度器"),
        ("app.services.scheduler.news_scheduler", "新闻调度器"),
        
        ("app.services.analysis", "分析服务"),
        ("app.services.analysis.stock_ai_analysis_service", "AI分析服务"),
        ("app.services.analysis.news_analysis_service", "新闻分析服务"),
        ("app.services.analysis.llm_service", "LLM服务"),
        
        ("app.services.data", "数据服务"),
        ("app.services.data.data_source_service", "数据源服务"),
        ("app.services.data.data_validation_service", "数据验证服务"),
        
        ("app.services.chart", "图表服务"),
        
        # API路由
        ("app.api.stocks_redis", "股票Redis API"),
        ("app.api.stock_scheduler_api", "股票调度器API"),
        ("app.api.etf_config", "ETF配置API"),
        ("app.api.signal_management", "信号管理API"),
        ("app.api.stock_ai_analysis", "AI分析API"),
        ("app.api.stock_data_management", "股票数据管理API"),
        ("app.api.news_analysis", "新闻分析API"),
        ("app.api.etf_diagnosis", "ETF诊断API"),
        ("app.api.realtime", "实时数据API"),
        
        # 主应用
        ("app.main", "主应用"),
    ]
    
    success_count = 0
    fail_count = 0
    
    for module_name, description in tests:
        if test_import(module_name, description):
            success_count += 1
        else:
            fail_count += 1
        print()
    
    print("=" * 60)
    print(f"测试完成: ✅ {success_count} 成功, ❌ {fail_count} 失败")
    print("=" * 60)
    
    # 测试特定配置项
    print("\n测试配置项:")
    try:
        from app.core.config import MAX_HISTORY_RECORDS
        print(f"✅ MAX_HISTORY_RECORDS = {MAX_HISTORY_RECORDS}")
    except Exception as e:
        print(f"❌ MAX_HISTORY_RECORDS 导入失败: {e}")
    
    return fail_count == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

