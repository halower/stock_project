#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试Tushare实时数据接口
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.realtime import get_realtime_service, update_config
from app.core.logging import logger

def test_tushare_realtime():
    """测试Tushare实时数据获取"""
    
    print("=" * 80)
    print("测试Tushare实时数据接口")
    print("=" * 80)
    
    # 配置使用Tushare
    update_config(
        default_provider='tushare',
        auto_switch=True,
        enable_realtime_update=True
    )
    
    # 获取实时服务
    service = get_realtime_service()
    
    print("\n当前配置:")
    print(f"  数据源: {service.config.default_provider.value}")
    print(f"  自动切换: {service.config.auto_switch}")
    print(f"  实时更新: {service.config.enable_realtime_update}")
    
    # 测试获取股票实时数据
    print("\n" + "=" * 80)
    print("测试1: 获取股票实时数据（不包含ETF）")
    print("=" * 80)
    
    result = service.get_all_stocks_realtime(provider='tushare', include_etf=False)
    
    if result.get('success'):
        print(f"✓ 成功获取数据")
        print(f"  数据源: {result.get('source')}")
        print(f"  数据量: {result.get('count')} 条")
        print(f"  更新时间: {result.get('update_time')}")
        
        # 显示前5条数据
        data = result.get('data', [])
        if data:
            print(f"\n前5条数据示例:")
            for i, item in enumerate(data[:5], 1):
                print(f"  {i}. {item['code']} {item['name']}")
                print(f"     价格: {item['price']:.2f}, 涨跌: {item['change']:+.2f} ({item['change_pct']:+.2f}%)")
                print(f"     成交量: {item['volume']:.0f}, 成交额: {item['amount']:.0f}")
    else:
        print(f"✗ 获取失败: {result.get('error')}")
    
    # 测试获取股票+ETF实时数据
    print("\n" + "=" * 80)
    print("测试2: 获取股票+ETF实时数据")
    print("=" * 80)
    
    result = service.get_all_stocks_realtime(provider='tushare', include_etf=True)
    
    if result.get('success'):
        print(f"✓ 成功获取数据")
        print(f"  数据源: {result.get('source')}")
        print(f"  数据量: {result.get('count')} 条")
        print(f"  更新时间: {result.get('update_time')}")
        
        # 统计股票和ETF数量
        data = result.get('data', [])
        etf_count = sum(1 for item in data if item['code'].startswith(('5', '1')))
        stock_count = len(data) - etf_count
        print(f"  股票: {stock_count} 只")
        print(f"  ETF: {etf_count} 只")
    else:
        print(f"✗ 获取失败: {result.get('error')}")
    
    # 测试获取ETF实时数据
    print("\n" + "=" * 80)
    print("测试3: 获取ETF实时数据")
    print("=" * 80)
    
    result = service.get_all_etfs_realtime(provider='tushare')
    
    if result.get('success'):
        print(f"✓ 成功获取数据")
        print(f"  数据源: {result.get('source')}")
        print(f"  数据量: {result.get('count')} 条")
        print(f"  更新时间: {result.get('update_time')}")
        
        # 显示前5条ETF数据
        data = result.get('data', [])
        if data:
            print(f"\n前5条ETF数据示例:")
            for i, item in enumerate(data[:5], 1):
                print(f"  {i}. {item['code']} {item['name']}")
                print(f"     价格: {item['price']:.2f}, 涨跌: {item['change']:+.2f} ({item['change_pct']:+.2f}%)")
    else:
        print(f"✗ 获取失败: {result.get('error')}")
    
    # 显示统计信息
    print("\n" + "=" * 80)
    print("统计信息")
    print("=" * 80)
    
    stats = service.get_stats()
    print(f"总请求数: {stats['total_requests']}")
    print(f"最后使用数据源: {stats['last_provider']}")
    print(f"最后更新时间: {stats['last_update']}")
    print(f"\nTushare: 成功={stats['tushare']['success']}, 失败={stats['tushare']['failed']}")
    print(f"东方财富: 成功={stats['eastmoney']['success']}, 失败={stats['eastmoney']['failed']}")
    print(f"新浪: 成功={stats['sina']['success']}, 失败={stats['sina']['failed']}")
    
    print("\n" + "=" * 80)
    print("测试完成")
    print("=" * 80)

if __name__ == '__main__':
    try:
        test_tushare_realtime()
    except KeyboardInterrupt:
        print("\n\n测试被用户中断")
    except Exception as e:
        print(f"\n\n测试出错: {e}")
        import traceback
        traceback.print_exc()

