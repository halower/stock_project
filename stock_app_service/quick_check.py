#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""快速检查所有修复是否生效"""

import sys
import os

# 添加项目根目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def check_config():
    """检查配置项"""
    print("=" * 60)
    print("1. 检查配置项")
    print("=" * 60)
    
    try:
        from app.core.config import MAX_HISTORY_RECORDS
        print(f"✅ MAX_HISTORY_RECORDS = {MAX_HISTORY_RECORDS}")
        return True
    except Exception as e:
        print(f"❌ MAX_HISTORY_RECORDS 导入失败: {e}")
        return False

def check_critical_imports():
    """检查关键导入"""
    print("\n" + "=" * 60)
    print("2. 检查关键模块导入")
    print("=" * 60)
    
    imports = [
        ("app.core.config", "核心配置"),
        ("app.services.stock.stock_crud", "股票CRUD"),
        ("app.services.analysis.llm_service", "LLM服务"),
        ("app.services.analysis.news_analysis_service", "新闻分析"),
        ("app.services.scheduler.stock_scheduler", "股票调度器"),
        ("app.services.signal.signal_manager", "信号管理器"),
    ]
    
    all_success = True
    for module_name, description in imports:
        try:
            __import__(module_name)
            print(f"✅ {description}: {module_name}")
        except Exception as e:
            print(f"❌ {description}: {module_name}")
            print(f"   错误: {e}")
            all_success = False
    
    return all_success

def check_deleted_dirs():
    """检查已删除的目录"""
    print("\n" + "=" * 60)
    print("3. 检查已删除的目录")
    print("=" * 60)
    
    dirs_to_check = [
        "app/services/realtime_v2",
        "app/mcp",
    ]
    
    all_deleted = True
    for dir_path in dirs_to_check:
        full_path = os.path.join(os.path.dirname(__file__), dir_path)
        if os.path.exists(full_path):
            print(f"❌ 目录仍然存在: {dir_path}")
            all_deleted = False
        else:
            print(f"✅ 目录已删除: {dir_path}")
    
    return all_deleted

def check_new_structure():
    """检查新的目录结构"""
    print("\n" + "=" * 60)
    print("4. 检查新的目录结构")
    print("=" * 60)
    
    expected_dirs = [
        "app/services/stock",
        "app/services/etf",
        "app/services/signal",
        "app/services/scheduler",
        "app/services/analysis",
        "app/services/data",
        "app/services/chart",
    ]
    
    all_exist = True
    for dir_path in expected_dirs:
        full_path = os.path.join(os.path.dirname(__file__), dir_path)
        init_file = os.path.join(full_path, "__init__.py")
        
        if os.path.exists(full_path) and os.path.exists(init_file):
            print(f"✅ {dir_path}")
        else:
            print(f"❌ {dir_path} (缺少 __init__.py)")
            all_exist = False
    
    return all_exist

def main():
    """主检查函数"""
    print("\n" + "🔍 快速检查所有修复")
    print("=" * 60)
    
    results = []
    
    # 执行所有检查
    results.append(("配置项", check_config()))
    results.append(("关键导入", check_critical_imports()))
    results.append(("已删除目录", check_deleted_dirs()))
    results.append(("新目录结构", check_new_structure()))
    
    # 汇总结果
    print("\n" + "=" * 60)
    print("📊 检查结果汇总")
    print("=" * 60)
    
    all_passed = True
    for name, passed in results:
        status = "✅ 通过" if passed else "❌ 失败"
        print(f"{name}: {status}")
        if not passed:
            all_passed = False
    
    print("=" * 60)
    
    if all_passed:
        print("\n🎉 所有检查通过！可以部署了！")
        return 0
    else:
        print("\n⚠️  有检查项失败，请修复后再部署")
        return 1

if __name__ == "__main__":
    sys.exit(main())

