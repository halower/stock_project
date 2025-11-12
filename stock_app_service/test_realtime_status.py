#!/usr/bin/env python3
"""测试实时更新状态"""

import requests
import json
from datetime import datetime

# 测试服务器
BASE_URL = "http://101.200.47.169:8000"

def test_scheduler_status():
    """测试调度器状态"""
    print("=" * 60)
    print("1. 测试调度器状态")
    print("=" * 60)
    
    try:
        response = requests.get(f"{BASE_URL}/api/tasks/status")
        if response.status_code == 200:
            data = response.json()
            print(json.dumps(data, indent=2, ensure_ascii=False))
        else:
            print(f"错误: {response.status_code}")
    except Exception as e:
        print(f"请求失败: {e}")

def test_stock_kline():
    """测试股票K线数据"""
    print("\n" + "=" * 60)
    print("2. 测试股票K线数据（600250）")
    print("=" * 60)
    
    try:
        response = requests.get(f"{BASE_URL}/api/stocks/600250.SH/kline")
        if response.status_code == 200:
            data = response.json()
            if data.get('success') and data.get('data'):
                klines = data['data']
                print(f"总共 {len(klines)} 条K线")
                print("\n最近3条K线:")
                for kline in klines[-3:]:
                    print(f"  日期: {kline.get('trade_date')}, "
                          f"收盘: {kline.get('close')}, "
                          f"成交量: {kline.get('volume')}")
        else:
            print(f"错误: {response.status_code}")
    except Exception as e:
        print(f"请求失败: {e}")

def test_signal_list():
    """测试信号列表"""
    print("\n" + "=" * 60)
    print("3. 测试信号列表")
    print("=" * 60)
    
    try:
        response = requests.get(f"{BASE_URL}/api/stocks/signal/buy?strategy=volume_wave&limit=3")
        if response.status_code == 200:
            data = response.json()
            if data.get('data') and data['data'].get('signals'):
                signals = data['data']['signals']
                print(f"总共 {len(signals)} 个信号\n")
                for i, signal in enumerate(signals[:3], 1):
                    print(f"信号 {i}:")
                    print(f"  代码: {signal.get('code')} - {signal.get('name')}")
                    print(f"  价格: {signal.get('price')}")
                    print(f"  涨跌幅: {signal.get('change_percent')}%")
                    print(f"  K线日期: {signal.get('kline_date')}")
                    print(f"  计算时间: {signal.get('calculated_time')}")
                    print()
        else:
            print(f"错误: {response.status_code}")
    except Exception as e:
        print(f"请求失败: {e}")

if __name__ == "__main__":
    print(f"\n当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    test_scheduler_status()
    test_stock_kline()
    test_signal_list()

