#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""检查 Python 文件语法"""

import os
import py_compile
import sys

def check_file(filepath):
    """检查单个文件的语法"""
    try:
        py_compile.compile(filepath, doraise=True)
        return True, None
    except py_compile.PyCompileError as e:
        return False, str(e)

def main():
    """检查所有关键文件"""
    files_to_check = [
        "app/core/config.py",
        "app/services/scheduler/news_scheduler.py",
        "app/services/scheduler/stock_scheduler.py",
        "app/services/analysis/news_analysis_service.py",
        "app/services/analysis/llm_service.py",
        "app/services/stock/stock_crud.py",
        "app/services/data/data_validation_service.py",
        "app/services/data/data_source_service.py",
        "app/services/chart/chart_service.py",
        "app/main.py",
    ]
    
    print("=" * 60)
    print("Checking Python syntax...")
    print("=" * 60)
    
    success_count = 0
    fail_count = 0
    
    for filepath in files_to_check:
        full_path = os.path.join(os.path.dirname(__file__), filepath)
        if not os.path.exists(full_path):
            print(f"[SKIP] {filepath} (file not found)")
            continue
        
        success, error = check_file(full_path)
        if success:
            print(f"[OK] {filepath}")
            success_count += 1
        else:
            print(f"[FAIL] {filepath}")
            print(f"  Error: {error}")
            fail_count += 1
    
    print("=" * 60)
    print(f"Results: {success_count} OK, {fail_count} FAIL")
    print("=" * 60)
    
    return fail_count == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

