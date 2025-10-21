# -*- coding: utf-8 -*-
"""
实时行情服务测试脚本
运行此脚本测试新的实时行情服务功能
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.realtime_service import RealtimeStockService, get_realtime_service
from app.core.logging import logger


def test_eastmoney():
    """测试东方财富数据源"""
    print("\n" + "="*60)
    print("测试1: 东方财富数据源")
    print("="*60)
    
    service = RealtimeStockService(default_provider='eastmoney', auto_switch=False)
    result = service.get_all_stocks_realtime()
    
    if result.get('success'):
        print(f"✅ 成功获取数据")
        print(f"   数据源: {result.get('source')}")
        print(f"   股票数量: {result.get('count')}")
        print(f"   更新时间: {result.get('update_time')}")
        if result.get('data'):
            sample = result['data'][0]
            print(f"   示例数据: {sample['code']} {sample['name']} {sample['price']}")
        return True
    else:
        print(f"❌ 获取失败: {result.get('error')}")
        return False


def test_sina():
    """测试新浪数据源"""
    print("\n" + "="*60)
    print("测试2: 新浪财经数据源")
    print("="*60)
    
    service = RealtimeStockService(default_provider='sina', auto_switch=False)
    result = service.get_all_stocks_realtime()
    
    if result.get('success'):
        print(f"✅ 成功获取数据")
        print(f"   数据源: {result.get('source')}")
        print(f"   股票数量: {result.get('count')}")
        print(f"   更新时间: {result.get('update_time')}")
        if result.get('data'):
            sample = result['data'][0]
            print(f"   示例数据: {sample['code']} {sample['name']} {sample['price']}")
        return True
    else:
        print(f"❌ 获取失败: {result.get('error')}")
        return False


def test_auto_switch():
    """测试自动切换功能"""
    print("\n" + "="*60)
    print("测试3: 自动切换模式")
    print("="*60)
    
    service = RealtimeStockService(default_provider='auto', auto_switch=True, retry_times=2)
    result = service.get_all_stocks_realtime()
    
    if result.get('success'):
        print(f"✅ 成功获取数据")
        print(f"   实际使用的数据源: {result.get('source')}")
        print(f"   股票数量: {result.get('count')}")
        print(f"   更新时间: {result.get('update_time')}")
        return True
    else:
        print(f"❌ 获取失败: {result.get('error')}")
        return False


def test_single_stock():
    """测试单只股票查询"""
    print("\n" + "="*60)
    print("测试4: 单只股票查询")
    print("="*60)
    
    service = get_realtime_service()
    stock_code = '600000'  # 浦发银行
    
    result = service.get_single_stock_realtime(stock_code)
    
    if result.get('success'):
        data = result.get('data', {})
        print(f"✅ 成功获取股票 {stock_code} 的实时数据")
        print(f"   数据源: {result.get('source')}")
        print(f"   股票代码: {data.get('code')}")
        print(f"   股票名称: {data.get('name')}")
        print(f"   最新价: {data.get('price')}")
        print(f"   涨跌额: {data.get('change')}")
        print(f"   涨跌幅: {data.get('change_percent')}%")
        print(f"   成交量: {data.get('volume')}")
        print(f"   成交额: {data.get('amount')}")
        return True
    else:
        print(f"❌ 获取失败: {result.get('error')}")
        return False


def test_statistics():
    """测试统计功能"""
    print("\n" + "="*60)
    print("测试5: 统计信息")
    print("="*60)
    
    service = get_realtime_service()
    
    # 执行几次查询以产生统计数据
    service.get_all_stocks_realtime(provider='eastmoney')
    service.get_all_stocks_realtime(provider='sina')
    
    stats = service.get_stats()
    
    print(f"📊 统计信息:")
    print(f"   总请求次数: {stats['total_requests']}")
    print(f"   东方财富:")
    print(f"      成功: {stats['eastmoney']['success']}")
    print(f"      失败: {stats['eastmoney']['fail']}")
    print(f"      成功率: {stats['eastmoney']['success_rate']:.2f}%")
    print(f"   新浪财经:")
    print(f"      成功: {stats['sina']['success']}")
    print(f"      失败: {stats['sina']['fail']}")
    print(f"      成功率: {stats['sina']['success_rate']:.2f}%")
    print(f"   最后使用的数据源: {stats['last_provider']}")
    print(f"   最后更新时间: {stats['last_update']}")
    print(f"   当前配置:")
    print(f"      默认提供商: {stats['config']['default_provider']}")
    print(f"      自动切换: {stats['config']['auto_switch']}")
    print(f"      重试次数: {stats['config']['retry_times']}")
    
    return True


def test_data_format():
    """测试数据格式一致性"""
    print("\n" + "="*60)
    print("测试6: 数据格式一致性")
    print("="*60)
    
    required_fields = [
        'code', 'name', 'price', 'change', 'change_percent',
        'volume', 'amount', 'high', 'low', 'open', 'pre_close',
        'buy', 'sell', 'update_time'
    ]
    
    # 测试东方财富
    service = RealtimeStockService(default_provider='eastmoney', auto_switch=False)
    result = service.get_all_stocks_realtime()
    
    if result.get('success') and result.get('data'):
        sample = result['data'][0]
        missing_fields = [field for field in required_fields if field not in sample]
        
        if not missing_fields:
            print(f"✅ 东方财富数据格式正确，包含所有必需字段")
        else:
            print(f"⚠️  东方财富数据缺少字段: {missing_fields}")
    
    # 测试新浪
    service = RealtimeStockService(default_provider='sina', auto_switch=False)
    result = service.get_all_stocks_realtime()
    
    if result.get('success') and result.get('data'):
        sample = result['data'][0]
        missing_fields = [field for field in required_fields if field not in sample]
        
        if not missing_fields:
            print(f"✅ 新浪数据格式正确，包含所有必需字段")
        else:
            print(f"⚠️  新浪数据缺少字段: {missing_fields}")
    
    return True


def main():
    """运行所有测试"""
    print("\n" + "="*60)
    print("实时行情服务测试")
    print("="*60)
    
    tests = [
        ("东方财富数据源", test_eastmoney),
        ("新浪财经数据源", test_sina),
        ("自动切换模式", test_auto_switch),
        ("单只股票查询", test_single_stock),
        ("统计信息", test_statistics),
        ("数据格式一致性", test_data_format),
    ]
    
    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print(f"\n❌ 测试 '{name}' 出现异常: {str(e)}")
            logger.error(f"测试异常: {e}", exc_info=True)
            results.append((name, False))
    
    # 输出汇总
    print("\n" + "="*60)
    print("测试结果汇总")
    print("="*60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for name, result in results:
        status = "✅ 通过" if result else "❌ 失败"
        print(f"{status} - {name}")
    
    print(f"\n总计: {passed}/{total} 个测试通过")
    
    if passed == total:
        print("\n🎉 所有测试通过！实时行情服务工作正常。")
    else:
        print(f"\n⚠️  有 {total - passed} 个测试失败，请检查日志。")
    
    return passed == total


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

