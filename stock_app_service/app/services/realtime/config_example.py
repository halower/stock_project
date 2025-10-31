# -*- coding: utf-8 -*-
"""
实时行情服务V2配置示例
"""

# ==================== 代理配置 ====================

# 代理API配置
PROXY_CONFIG = {
    'api_url': 'https://share.proxy.qg.net/get',
    'api_key': '8E0IORZ1',  # 替换为您的API密钥
    'pool_size': 10,         # 代理池大小
    'refresh_interval': 300, # 刷新间隔（秒）
    'max_fail_count': 3,     # 最大失败次数
    'enable_proxy': True     # 是否启用代理
}

# ==================== 股票实时数据配置 ====================

STOCK_REALTIME_CONFIG = {
    'default_provider': 'eastmoney',  # 默认数据源: eastmoney/sina/auto
    'auto_switch': True,              # 是否自动切换数据源
    'retry_times': 3,                 # 重试次数
    'timeout': 10                     # 请求超时（秒）
}

# ==================== ETF实时数据配置 ====================

ETF_REALTIME_CONFIG = {
    'default_provider': 'eastmoney',  # 默认数据源: eastmoney/sina/auto
    'auto_switch': True,              # 是否自动切换数据源
    'retry_times': 3,                 # 重试次数
    'timeout': 10                     # 请求超时（秒）
}

# ==================== 使用示例 ====================

def example_usage():
    """使用示例"""
    from app.services.realtime import (
        get_proxy_manager,
        get_stock_realtime_service_v2,
        get_etf_realtime_service_v2
    )
    
    # 1. 初始化代理管理器
    proxy_manager = get_proxy_manager(**PROXY_CONFIG)
    
    # 2. 初始化股票实时服务
    stock_service = get_stock_realtime_service_v2(
        proxy_manager=proxy_manager,
        **STOCK_REALTIME_CONFIG
    )
    
    # 3. 获取股票实时数据
    result = stock_service.get_all_stocks_realtime()
    
    if result['success']:
        print(f"✅ 成功获取 {result['count']} 只股票数据")
        print(f"📊 数据来源: {result['source']}")
        
        # 显示前5只股票
        for stock in result['data'][:5]:
            print(f"  {stock['code']} {stock['name']}: ¥{stock['price']}")
    else:
        print(f"❌ 获取失败: {result['error']}")
    
    # 4. 查看统计信息
    stats = stock_service.get_stats()
    print(f"\n📈 统计信息:")
    print(f"  总请求数: {stats['total_requests']}")
    print(f"  代理使用: {stats['proxy_used']}")
    print(f"  直连使用: {stats['direct_used']}")
    print(f"  东方财富: 成功{stats['eastmoney']['success']} 失败{stats['eastmoney']['fail']}")
    print(f"  新浪财经: 成功{stats['sina']['success']} 失败{stats['sina']['fail']}")
    
    # 5. 查看代理统计
    proxy_stats = proxy_manager.get_stats()
    print(f"\n🔄 代理统计:")
    print(f"  总获取: {proxy_stats['total_fetched']}")
    print(f"  总使用: {proxy_stats['total_used']}")
    print(f"  总失败: {proxy_stats['total_failed']}")
    print(f"  当前池大小: {proxy_stats['current_pool_size']}")
    print(f"  可用代理: {proxy_stats['available_count']}")


if __name__ == '__main__':
    example_usage()

