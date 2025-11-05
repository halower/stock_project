#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
成交量诊断脚本
检查实时数据和K线数据中的成交量字段
"""

import json
from app.db.session import RedisCache
from app.core.config import STOCK_KEYS

redis_cache = RedisCache()

def diagnose_volume():
    """诊断成交量数据"""
    print("=" * 60)
    print("成交量数据诊断")
    print("=" * 60)
    
    # 1. 检查实时数据
    print("\n📊 检查实时数据...")
    realtime_data = redis_cache.get_cache(STOCK_KEYS['realtime_data'])
    
    if realtime_data and 'data' in realtime_data:
        data_list = realtime_data['data']
        print(f"实时数据数量: {len(data_list)}")
        
        # 检查前10个股票的成交量
        print("\n前10个股票的成交量数据:")
        for i, stock in enumerate(data_list[:10]):
            code = stock.get('code', 'N/A')
            volume = stock.get('volume', 0)
            vol = stock.get('vol', 0)
            amount = stock.get('amount', 0)
            print(f"  {i+1}. {code}: volume={volume}, vol={vol}, amount={amount}")
    else:
        print("❌ 没有实时数据")
    
    # 2. 检查K线数据
    print("\n📊 检查K线数据（随机抽样5个）...")
    sample_codes = ['000001.SZ', '600000.SH', '000002.SZ', '600519.SH', '000858.SZ']
    
    for ts_code in sample_codes:
        kline_key = STOCK_KEYS['stock_kline'].format(ts_code)
        kline_data = redis_cache.get_cache(kline_key)
        
        if kline_data:
            if isinstance(kline_data, dict):
                kline_list = kline_data.get('data', [])
            elif isinstance(kline_data, list):
                kline_list = kline_data
            else:
                print(f"  {ts_code}: 数据格式错误")
                continue
            
            if kline_list:
                last_kline = kline_list[-1]
                vol = last_kline.get('vol', 0)
                volume = last_kline.get('volume', 0)
                trade_date = last_kline.get('trade_date', 'N/A')
                actual_date = last_kline.get('actual_trade_date', 'N/A')
                
                print(f"  {ts_code}:")
                print(f"    最后K线日期: {trade_date} / {actual_date}")
                print(f"    vol字段: {vol}")
                print(f"    volume字段: {volume}")
                print(f"    所有字段: {list(last_kline.keys())}")
            else:
                print(f"  {ts_code}: K线数据为空")
        else:
            print(f"  {ts_code}: 没有K线数据")
    
    print("\n" + "=" * 60)
    print("诊断完成")
    print("=" * 60)

if __name__ == "__main__":
    diagnose_volume()

