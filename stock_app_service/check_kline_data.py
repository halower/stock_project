# -*- coding: utf-8 -*-
"""
检查Redis中的K线数据情况
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.db.session import RedisCache
from app.core.logging import logger

redis_cache = RedisCache()

def check_kline_data():
    """检查K线数据存储情况"""
    
    print("\n" + "="*60)
    print("检查Redis中的K线数据")
    print("="*60)
    
    # 测试几个常见股票
    test_stocks = [
        '600000.SH',  # 浦发银行
        '000001.SZ',  # 平安银行
        '600519.SH',  # 贵州茅台
        '000858.SZ',  # 五粮液
        '601318.SH',  # 中国平安
    ]
    
    found_count = 0
    not_found_count = 0
    
    for ts_code in test_stocks:
        kline_key = f'stock_trend:{ts_code}'
        kline_data = redis_cache.get_cache(kline_key)
        
        if kline_data:
            found_count += 1
            if isinstance(kline_data, dict):
                data_list = kline_data.get('data', [])
                print(f"✅ {ts_code}: 有数据，共 {len(data_list)} 条K线")
                if data_list:
                    last_kline = data_list[-1]
                    last_date = last_kline.get('trade_date', last_kline.get('date', '未知'))
                    print(f"   最后一根K线日期: {last_date}")
            else:
                print(f"✅ {ts_code}: 有数据（格式待检查）")
        else:
            not_found_count += 1
            print(f"❌ {ts_code}: 没有数据")
    
    print(f"\n总结: {found_count} 个有数据, {not_found_count} 个没有数据")
    
    # 检查总的股票数量
    print("\n" + "="*60)
    print("检查所有K线数据")
    print("="*60)
    
    try:
        # 尝试获取所有stock_trend:*的键
        import redis
        r = redis_cache.redis_client
        
        pattern = 'stock_trend:*'
        cursor = 0
        total_keys = 0
        
        while True:
            cursor, keys = r.scan(cursor, match=pattern, count=100)
            total_keys += len(keys)
            if cursor == 0:
                break
        
        print(f"Redis中共有 {total_keys} 个K线数据键")
        
        # 如果数量为0，说明没有初始化K线数据
        if total_keys == 0:
            print("\n⚠️  警告: Redis中没有任何K线数据！")
            print("   这意味着系统还没有初始化历史数据")
            print("   需要先运行全量K线数据更新任务")
            print("\n   解决方法:")
            print("   1. 通过API触发全量更新: POST /api/stocks/scheduler/full-kline-update")
            print("   2. 或者重启服务，让系统自动初始化（如果配置了STOCK_INIT_MODE）")
        else:
            print(f"\n✅ K线数据正常，共 {total_keys} 只股票")
    
    except Exception as e:
        print(f"检查失败: {e}")
    
    # 检查实时数据
    print("\n" + "="*60)
    print("检查实时数据")
    print("="*60)
    
    realtime_key = 'stock:realtime'
    realtime_data = redis_cache.get_cache(realtime_key)
    
    if realtime_data:
        data_list = realtime_data.get('data', [])
        print(f"✅ 实时数据存在")
        print(f"   股票数量: {len(data_list)}")
        print(f"   数据源: {realtime_data.get('data_source', '未知')}")
        print(f"   更新时间: {realtime_data.get('update_time', '未知')}")
        
        if data_list:
            sample = data_list[0]
            print(f"   示例: {sample.get('code')} {sample.get('name')} {sample.get('price')}")
    else:
        print("❌ 实时数据不存在")
    
    print("\n" + "="*60)

if __name__ == "__main__":
    check_kline_data()

