# -*- coding: utf-8 -*-
"""
诊断K线数据键格式
检查Redis中K线数据的键名格式，帮助排查为什么实时数据无法合并到K线
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import redis

def diagnose_kline_keys():
    """诊断K线数据键"""
    
    print("\n" + "="*80)
    print("K线数据键格式诊断工具")
    print("="*80)
    
    try:
        # 连接Redis
        r = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
        r.ping()
        print("✅ Redis连接成功\n")
    except Exception as e:
        print(f"❌ Redis连接失败: {e}")
        return
    
    # 1. 检查所有K线相关的键
    print("📊 步骤1: 扫描所有K线相关的键")
    print("-" * 80)
    
    patterns = [
        'stock_trend:*',
        'stocks:trend:*', 
        'stock:kline:*',
        'kline:*'
    ]
    
    all_keys = {}
    for pattern in patterns:
        cursor = 0
        keys = []
        while True:
            cursor, batch = r.scan(cursor, match=pattern, count=100)
            keys.extend(batch)
            if cursor == 0:
                break
        if keys:
            all_keys[pattern] = keys
            print(f"✅ 模式 '{pattern}': 找到 {len(keys)} 个键")
            # 显示前5个键示例
            for i, key in enumerate(keys[:5]):
                print(f"   示例{i+1}: {key}")
        else:
            print(f"❌ 模式 '{pattern}': 未找到任何键")
    
    if not all_keys:
        print("\n⚠️  警告: 没有找到任何K线数据键！")
        print("   这意味着Redis中没有K线历史数据")
        print("\n   可能的原因:")
        print("   1. 系统还没有初始化K线数据")
        print("   2. Redis数据被清空了")
        print("   3. K线数据使用了不同的键名格式")
        return
    
    # 2. 分析键名格式
    print("\n📋 步骤2: 分析键名格式")
    print("-" * 80)
    
    for pattern, keys in all_keys.items():
        if not keys:
            continue
        
        print(f"\n模式: {pattern}")
        print(f"总数: {len(keys)} 个")
        
        # 分析键名结构
        sample_keys = keys[:10]
        for key in sample_keys:
            # 尝试获取数据
            data = r.get(key)
            if data:
                data_type = "string"
                try:
                    import json
                    parsed = json.loads(data)
                    if isinstance(parsed, dict):
                        data_count = len(parsed.get('data', []))
                        print(f"   {key} → {data_type}, K线数量: {data_count}")
                    else:
                        print(f"   {key} → {data_type}")
                except:
                    print(f"   {key} → {data_type} (非JSON)")
            else:
                # 可能是hash类型
                data_type = r.type(key)
                print(f"   {key} → {data_type}")
    
    # 3. 检查实时数据格式
    print("\n📝 步骤3: 检查实时数据格式")
    print("-" * 80)
    
    realtime_key = 'stock:realtime'
    realtime_data = r.get(realtime_key)
    
    if realtime_data:
        try:
            import json
            data = json.loads(realtime_data)
            data_list = data.get('data', [])
            print(f"✅ 实时数据存在")
            print(f"   股票数量: {len(data_list)}")
            print(f"   数据源: {data.get('data_source', '未知')}")
            
            if data_list:
                sample = data_list[0]
                print(f"\n   示例股票数据:")
                print(f"   - 代码: {sample.get('code', 'N/A')}")
                print(f"   - 名称: {sample.get('name', 'N/A')}")
                print(f"   - 价格: {sample.get('price', 'N/A')}")
                print(f"   - 字段列表: {list(sample.keys())}")
                
                # 检查代码格式转换
                stock_code = sample.get('code', '')
                if stock_code:
                    if stock_code.startswith('6'):
                        ts_code = f"{stock_code}.SH"
                    elif stock_code.startswith(('43', '83', '87', '88')):
                        ts_code = f"{stock_code}.BJ"
                    else:
                        ts_code = f"{stock_code}.SZ"
                    
                    print(f"\n   代码转换:")
                    print(f"   实时数据代码: {stock_code}")
                    print(f"   转换后ts_code: {ts_code}")
                    
                    # 检查对应的K线键是否存在
                    kline_key = f"stock_trend:{ts_code}"
                    exists = r.exists(kline_key)
                    print(f"   对应K线键: {kline_key}")
                    print(f"   K线数据{'存在 ✅' if exists else '不存在 ❌'}")
                    
                    if not exists:
                        # 尝试其他可能的键格式
                        print(f"\n   尝试其他可能的键格式:")
                        possible_keys = [
                            f"stocks:trend:{ts_code}",
                            f"stock:kline:{ts_code}",
                            f"kline:{ts_code}",
                            f"stock_trend:{stock_code}",  # 不带后缀
                        ]
                        for pk in possible_keys:
                            if r.exists(pk):
                                print(f"   ✅ 找到: {pk}")
                            else:
                                print(f"   ❌ 不存在: {pk}")
        except Exception as e:
            print(f"解析实时数据失败: {e}")
    else:
        print("❌ 实时数据不存在")
    
    # 4. 提供建议
    print("\n" + "="*80)
    print("💡 诊断结果和建议")
    print("="*80)
    
    if not all_keys:
        print("\n❌ 问题: Redis中没有K线数据")
        print("\n解决方案:")
        print("1. 触发全量K线数据初始化:")
        print("   curl -X POST 'http://your-server:8000/api/stocks/scheduler/trigger' \\")
        print("     -H 'Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ' \\")
        print("     -H 'Content-Type: application/json' \\")
        print("     -d '{\"task_type\": \"clear_refetch\"}'")
    elif realtime_data and not exists:
        print("\n❌ 问题: K线数据存在，但键名格式不匹配")
        print(f"\n实际K线键格式: {list(all_keys.keys())[0]}")
        print(f"代码期望的格式: stock_trend:{{ts_code}}")
        print("\n需要修改代码中的STOCK_KEYS配置，或者重新初始化K线数据")
    else:
        print("\n✅ K线数据格式正常")
        print("   如果实时更新仍然为0，可能是:")
        print("   1. 部分股票没有K线数据")
        print("   2. 日志级别设置为INFO，看不到DEBUG日志")
        print("   3. 需要查看详细日志确定具体原因")

if __name__ == "__main__":
    diagnose_kline_keys()

