#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ETF 数据诊断脚本
检查 stock_list 中的 ETF 数据格式
"""

import json
from app.core.sync_redis_client import get_sync_redis_client

def diagnose_etf_data():
    """诊断 ETF 数据"""
    print("=" * 60)
    print("ETF 数据诊断")
    print("=" * 60)
    
    redis = get_sync_redis_client()
    stock_list = redis.hgetall("stock_list")
    
    print(f"\n📊 stock_list 总数: {len(stock_list)}")
    
    # 统计
    etf_count = 0
    stock_count = 0
    error_count = 0
    error_etfs = []
    
    for key, value in stock_list.items():
        try:
            # 解码
            if isinstance(value, bytes):
                value = value.decode('utf-8')
            
            # 检查是否是 ETF
            if 'ETF' in value:
                etf_count += 1
                
                # 尝试解析
                try:
                    data = json.loads(value)
                    if not isinstance(data, dict):
                        error_count += 1
                        error_etfs.append({
                            'key': key,
                            'type': str(type(data)),
                            'value': str(value)[:200]
                        })
                        print(f"\n❌ 错误的 ETF 数据:")
                        print(f"   Key: {key}")
                        print(f"   Type: {type(data)}")
                        print(f"   Value: {str(data)[:200]}")
                except json.JSONDecodeError as e:
                    error_count += 1
                    error_etfs.append({
                        'key': key,
                        'error': str(e),
                        'value': str(value)[:200]
                    })
                    print(f"\n❌ JSON 解析失败:")
                    print(f"   Key: {key}")
                    print(f"   Error: {e}")
                    print(f"   Value: {value[:200]}")
            else:
                stock_count += 1
                
        except Exception as e:
            print(f"\n❌ 处理 {key} 时出错: {e}")
    
    print(f"\n" + "=" * 60)
    print(f"📊 统计结果:")
    print(f"   股票数量: {stock_count}")
    print(f"   ETF 数量: {etf_count}")
    print(f"   错误数量: {error_count}")
    print("=" * 60)
    
    if error_etfs:
        print(f"\n❌ 发现 {len(error_etfs)} 个错误的 ETF 数据")
        print("\n建议操作:")
        print("1. 清空 stock_list 中的 ETF 数据")
        print("2. 重新初始化 ETF 清单")
        print("\n执行命令:")
        print("docker exec -it stock_app_api python -c \"")
        print("from app.core.sync_redis_client import get_sync_redis_client")
        print("import json")
        print("redis = get_sync_redis_client()")
        print("stock_list = redis.hgetall('stock_list')")
        print("for key, value in stock_list.items():")
        print("    if isinstance(value, bytes):")
        print("        value = value.decode('utf-8')")
        print("    if 'ETF' in value:")
        print("        redis.hdel('stock_list', key)")
        print("print('ETF 数据已清空')")
        print("\"")
    else:
        print(f"\n✅ 所有 ETF 数据格式正确")
    
    return error_count == 0

if __name__ == "__main__":
    diagnose_etf_data()

