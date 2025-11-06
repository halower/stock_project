# -*- coding: utf-8 -*-
"""
实时数据更新服务
负责股票和ETF的实时数据获取和更新
"""

import asyncio
import threading
import traceback
from datetime import datetime
from typing import Dict, Any, List, Tuple

from app.core.logging import logger
from app.db.session import RedisCache
from app.services.realtime import get_proxy_manager, get_etf_realtime_service_v2

# Redis缓存客户端
redis_cache = RedisCache()

# Redis键名规则
STOCK_KEYS = {
    'stock_codes': 'stocks:codes:all',
    'stock_kline': 'stock_trend:{}',
    'strategy_signals': 'stock:buy_signals',
    'realtime_data': 'stock:realtime',
    'scheduler_log': 'stock:scheduler:log',
    'last_update': 'stock:last_update',
}

ETF_KEYS = {
    'etf_codes': 'etf:codes:all',
    'etf_realtime': 'etf:realtime',
    'etf_kline': 'etf_trend:{}',
    'etf_signals': 'etf:buy_signals',
    'etf_scheduler_log': 'etf:scheduler:log',
    'etf_last_update': 'etf:last_update',
}


def get_stock_realtime_data_sina() -> List[Dict]:
    """
    使用新浪接口获取所有股票实时数据（备用方案）
    
    Returns:
        股票实时数据列表
    """
    try:
        from app.services.realtime import get_proxy_manager
        from app.services.realtime.stock_realtime_service import StockRealtimeServiceV2
        
        logger.info("🔄 使用新浪接口获取股票实时数据...")
        
        # 创建独立的新浪接口服务实例（不使用单例）
        proxy_manager = get_proxy_manager()
        realtime_service = StockRealtimeServiceV2(
            proxy_manager=proxy_manager,
            default_provider='sina',  # 明确指定使用新浪接口
            auto_switch=False,  # 不自动切换到其他数据源
            retry_times=3,
            timeout=15
        )
        result = realtime_service.get_all_stocks_realtime(provider='sina')
        
        if not result.get('success'):
            logger.error(f"新浪接口获取失败: {result.get('error', '未知错误')}")
            return []
        
        realtime_data = result.get('data', [])
        data_source = result.get('source', 'unknown')
        
        logger.info(f"✅ 新浪接口成功获取 {len(realtime_data)} 只股票实时数据，数据源: {data_source}")
        return realtime_data
        
    except Exception as e:
        logger.error(f"❌ 新浪接口获取股票实时数据失败: {e}")
        logger.error(traceback.format_exc())
        return []


def get_stock_realtime_data_akshare() -> List[Dict]:
    """
    使用 akshare 获取所有股票实时数据
    
    Returns:
        股票实时数据列表
    """
    try:
        import akshare as ak
        
        logger.info("🔄 使用 akshare 获取股票实时数据...")
        
        # 使用 akshare 的实时行情接口
        df = ak.stock_zh_a_spot_em()
        
        if df.empty:
            logger.error("akshare 返回的数据为空")
            return []
        
        # 转换数据格式
        realtime_data = []
        for _, row in df.iterrows():
            try:
                code = str(row.get('代码', ''))
                if not code:
                    continue
                
                # 构造标准格式的实时数据
                stock_data = {
                    'code': code,
                    'name': str(row.get('名称', '')),
                    'price': float(row.get('最新价', 0)),
                    'change': float(row.get('涨跌额', 0)),
                    'change_percent': float(row.get('涨跌幅', 0)),
                    'open': float(row.get('今开', 0)),
                    'high': float(row.get('最高', 0)),
                    'low': float(row.get('最低', 0)),
                    'pre_close': float(row.get('昨收', 0)),
                    'volume': float(row.get('成交量', 0)),
                    'amount': float(row.get('成交额', 0)),
                    'turnover_rate': float(row.get('换手率', 0)) if '换手率' in row else 0.0,
                }
                realtime_data.append(stock_data)
            except Exception as e:
                logger.debug(f"解析股票 {row.get('代码', 'unknown')} 数据失败: {e}")
                continue
        
        logger.info(f"✅ akshare 成功获取 {len(realtime_data)} 只股票实时数据")
        return realtime_data
        
    except Exception as e:
        logger.error(f"❌ akshare 获取股票实时数据失败: {e}")
        logger.error(traceback.format_exc())
        return []


def get_stock_realtime_data_with_fallback(prefer_source: str = 'sina') -> Tuple[List[Dict], str]:
    """
    获取股票实时数据（带降级策略）
    
    Args:
        prefer_source: 优先数据源 ('sina' 或 'akshare')
        
    Returns:
        Tuple[股票实时数据列表, 实际使用的数据源]
    """
    if prefer_source == 'sina':
        # 优先使用新浪接口
        logger.info("📊 优先使用新浪接口获取股票实时数据")
        realtime_data = get_stock_realtime_data_sina()
        
        if realtime_data and len(realtime_data) > 0:
            return realtime_data, 'sina'
        
        # 新浪失败，降级到 akshare
        logger.warning("⚠️  新浪接口失败，降级到 akshare")
        realtime_data = get_stock_realtime_data_akshare()
        
        if realtime_data and len(realtime_data) > 0:
            return realtime_data, 'akshare'
        
        return [], 'none'
    
    else:
        # 优先使用 akshare
        logger.info("📊 优先使用 akshare 获取股票实时数据")
        realtime_data = get_stock_realtime_data_akshare()
        
        if realtime_data and len(realtime_data) > 0:
            return realtime_data, 'akshare'
        
        # akshare 失败，降级到新浪
        logger.warning("⚠️  akshare 失败，降级到新浪接口")
        realtime_data = get_stock_realtime_data_sina()
        
        if realtime_data and len(realtime_data) > 0:
            return realtime_data, 'sina'
        
        return [], 'none'


def get_etf_realtime_data(force_update=False) -> Tuple[Dict[str, Dict], str]:
    """
    获取ETF实时数据（使用东方财富接口）
    
    Args:
        force_update: 是否强制更新
        
    Returns:
        Tuple[实时数据字典, 数据源]
        实时数据字典格式: {code: {data}}
    """
    from app.core.etf_config import get_etf_list
    
    try:
        # 1. 从配置文件读取ETF列表（121个精选ETF）
        etf_config_list = get_etf_list()
        
        etf_codes_list = []
        for etf in etf_config_list:
            etf_codes_list.append({
                'code': etf['symbol'],
                'name': etf['name'],
                'ts_code': etf['ts_code'],
                'market': etf.get('market', 'ETF')
            })
        
        # 存储ETF代码列表到Redis
        redis_cache.set_cache(ETF_KEYS['etf_codes'], etf_codes_list, ttl=86400)
        
        # 2. 获取实时数据（仅获取CSV中的ETF）- 使用V2服务（支持代理）
        proxy_manager = get_proxy_manager()
        etf_service = get_etf_realtime_service_v2(proxy_manager=proxy_manager)
        result = etf_service.get_all_etfs_realtime()
        
        if not result.get('success'):
            raise Exception(result.get('error', '获取ETF实时数据失败'))
        
        all_realtime_data = result.get('data', [])
        data_source = result.get('source', 'unknown')
        
        logger.info(f"✅ 成功从 {data_source} 获取 {len(all_realtime_data)} 只ETF实时数据")
        
        # 3. 过滤出CSV中监控的ETF（以code为key）
        monitored_codes = {etf['code'] for etf in etf_codes_list}
        
        realtime_dict = {}
        for etf in all_realtime_data:
            code = etf.get('code')
            # 只保留CSV中监控的ETF
            if code and code in monitored_codes:
                realtime_dict[code] = etf
        
        # 4. 存储到Redis（只存储监控的ETF）
        redis_cache.set_cache(
            ETF_KEYS['etf_realtime'],
            {
                'data': realtime_dict,
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'source': data_source,
                'count': len(realtime_dict),
                'monitored_count': len(monitored_codes),
                'total_count': len(all_realtime_data)
            },
            ttl=3600  # 1小时过期
        )
        
        return realtime_dict, data_source
        
    except Exception as e:
        logger.error(f'获取ETF实时数据失败: {str(e)}')
        logger.error(traceback.format_exc())
        return {}, 'error'


def merge_stock_realtime_to_kline(realtime_data: List[Dict], is_closing_update=False) -> Tuple[int, int]:
    """
    将股票实时数据合并到K线数据
    
    Args:
        realtime_data: 实时数据列表
        is_closing_update: 是否为收盘后更新
        
    Returns:
        Tuple[成功数量, 失败数量]
    """
    updated_count = 0
    failed_count = 0
    today_str = datetime.now().strftime('%Y-%m-%d')
    today_trade_date = datetime.now().strftime('%Y%m%d')
    
    try:
        for stock_data in realtime_data:
            try:
                stock_code = stock_data.get('code')
                if not stock_code:
                    continue
                
                # 构造ts_code
                if stock_code.startswith('6'):
                    ts_code = f"{stock_code}.SH"
                elif stock_code.startswith(('43', '83', '87', '88')):
                    ts_code = f"{stock_code}.BJ"
                else:
                    ts_code = f"{stock_code}.SZ"
                
                # 获取K线数据
                kline_key = STOCK_KEYS['stock_kline'].format(ts_code)
                kline_data = redis_cache.get_cache(kline_key)
                
                if not kline_data:
                    failed_count += 1
                    continue
                
                # 处理不同的数据格式
                if isinstance(kline_data, dict):
                    kline_list = kline_data.get('data', [])
                    trend_data = kline_data
                elif isinstance(kline_data, list):
                    kline_list = kline_data
                    trend_data = {
                        'data': kline_list,
                        'updated_at': datetime.now().isoformat(),
                        'data_count': len(kline_list),
                        'source': 'legacy_format'
                    }
                else:
                    continue
                
                if not kline_list:
                    continue
                
                # 检查最后一根K线是否是今天的数据
                last_kline = kline_list[-1]
                last_trade_date = str(last_kline.get('trade_date', ''))
                last_date = last_kline.get('actual_trade_date', last_kline.get('date', ''))
                
                # 实时数据中的成交量数据处理
                current_volume = stock_data.get('volume', 0)
                if current_volume == 0:
                    current_volume = stock_data.get('vol', 0)
                if current_volume is None or current_volume < 0:
                    current_volume = 0
                
                # 判断是否需要新增今日K线
                if last_trade_date != today_trade_date and last_date != today_str:
                    # 新增今天的K线
                    new_kline = {
                        'ts_code': ts_code,
                        'trade_date': today_trade_date,
                        'open': stock_data['open'],
                        'high': stock_data['high'],
                        'low': stock_data['low'],
                        'close': stock_data['price'],
                        'pre_close': stock_data['pre_close'],
                        'change': stock_data['change'],
                        'pct_chg': stock_data['change_percent'],
                        'vol': current_volume / 100 if current_volume > 100 else current_volume,
                        'amount': stock_data['amount'] / 1000 if stock_data['amount'] > 1000 else stock_data['amount'],
                        'actual_trade_date': today_str,
                        'is_closing_data': is_closing_update,
                        'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    }
                    kline_list.append(new_kline)
                else:
                    # 更新最后一根K线
                    existing_volume = float(last_kline.get('vol', 0))
                    current_volume_in_hands = current_volume / 100
                    final_volume = max(existing_volume, current_volume_in_hands) if current_volume > 0 else existing_volume
                    
                    last_kline.update({
                        'ts_code': ts_code,
                        'trade_date': today_trade_date,
                        'high': max(float(last_kline.get('high', 0)), stock_data['high']),
                        'low': min(float(last_kline.get('low', float('inf'))), stock_data['low']) if float(last_kline.get('low', float('inf'))) != float('inf') else stock_data['low'],
                        'close': stock_data['price'],
                        'pre_close': stock_data['pre_close'],
                        'change': stock_data['change'],
                        'pct_chg': stock_data['change_percent'],
                        'vol': final_volume,
                        'amount': stock_data['amount'] / 1000,
                        'actual_trade_date': today_str,
                        'is_closing_data': is_closing_update,
                        'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    })
                
                # 更新trend_data
                trend_data.update({
                    'data': kline_list,
                    'updated_at': datetime.now().isoformat(),
                    'data_count': len(kline_list),
                    'last_update_type': 'closing_update' if is_closing_update else 'realtime_update'
                })
                
                # 更新Redis缓存
                redis_cache.set_cache(kline_key, trend_data, ttl=None)
                updated_count += 1
                
            except Exception as e:
                failed_count += 1
                if failed_count <= 5:
                    logger.error(f"处理股票 {stock_data.get('code', 'unknown')} 失败: {str(e)}")
                continue
        
        if failed_count > 0:
            logger.warning(f"⚠️  有 {failed_count} 只股票更新失败")
            
        return updated_count, failed_count
        
    except Exception as e:
        logger.error(f"合并股票实时数据到K线失败: {str(e)}")
        logger.error(traceback.format_exc())
        return 0, len(realtime_data) if realtime_data else 0


def merge_etf_realtime_to_kline(realtime_dict: Dict[str, Dict], is_closing_update=False) -> Tuple[int, int]:
    """
    将ETF实时数据合并到K线数据
    当天没有K线则新增，有K线则更新
    
    Args:
        realtime_dict: 实时数据字典 {code: data}
        is_closing_update: 是否为收盘后更新
        
    Returns:
        Tuple[成功数量, 失败数量]
    """
    updated_count = 0
    appended_count = 0
    created_count = 0
    failed_count = 0
    
    try:
        today_str = datetime.now().strftime('%Y-%m-%d')
        today_trade_date = datetime.now().strftime('%Y%m%d')
        
        for code, etf_data in realtime_dict.items():
            try:
                # 构造ts_code
                if code.startswith('5'):
                    ts_code = f"{code}.SH"
                else:
                    ts_code = f"{code}.SZ"
                
                # 获取K线数据
                kline_key = ETF_KEYS['etf_kline'].format(ts_code)
                kline_data = redis_cache.get_cache(kline_key)
                
                # 如果没有K线数据，创建新的K线数据列表
                if not kline_data or not isinstance(kline_data, list) or len(kline_data) == 0:
                    new_kline = {
                        'date': today_str,
                        'trade_date': today_trade_date,
                        'open': etf_data.get('open', etf_data.get('price', 0)),
                        'close': etf_data.get('price', 0),
                        'high': etf_data.get('high', etf_data.get('price', 0)),
                        'low': etf_data.get('low', etf_data.get('price', 0)),
                        'volume': etf_data.get('volume', 0),
                        'amount': etf_data.get('amount', 0),
                        'turnover_rate': etf_data.get('turnover_rate', 0),
                        'change': etf_data.get('change', 0),
                        'pct_chg': etf_data.get('change_percent', 0),
                        'is_closing_data': is_closing_update,
                        'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    }
                    kline_data = [new_kline]
                    redis_cache.set_cache(kline_key, kline_data, ttl=604800)
                    created_count += 1
                    continue
                
                # 获取最后一条K线
                last_kline = kline_data[-1]
                
                # 获取最后一条K线的日期
                last_date = str(last_kline.get('date', ''))
                last_trade_date = str(last_kline.get('trade_date', ''))
                
                # 判断是否是今天的数据
                is_today = (last_date == today_str) or (last_trade_date == today_trade_date)
                
                if is_today:
                    # 更新今天的K线
                    last_kline['close'] = etf_data.get('price', last_kline.get('close', 0))
                    last_kline['high'] = max(
                        last_kline.get('high', 0),
                        etf_data.get('high', 0),
                        etf_data.get('price', 0)
                    )
                    last_kline['low'] = min(
                        last_kline.get('low', 999999),
                        etf_data.get('low', 999999),
                        etf_data.get('price', 999999)
                    ) if last_kline.get('low', 0) > 0 else etf_data.get('low', 0)
                    last_kline['volume'] = etf_data.get('volume', last_kline.get('volume', 0))
                    last_kline['amount'] = etf_data.get('amount', last_kline.get('amount', 0))
                    last_kline['turnover_rate'] = etf_data.get('turnover_rate', last_kline.get('turnover_rate', 0))
                    last_kline['is_closing_data'] = is_closing_update
                    last_kline['update_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    
                    redis_cache.set_cache(kline_key, kline_data, ttl=604800)
                    updated_count += 1
                else:
                    # 新增今天的K线
                    new_kline = {
                        'date': today_str,
                        'trade_date': today_trade_date,
                        'open': etf_data.get('open', etf_data.get('price', 0)),
                        'close': etf_data.get('price', 0),
                        'high': etf_data.get('high', etf_data.get('price', 0)),
                        'low': etf_data.get('low', etf_data.get('price', 0)),
                        'volume': etf_data.get('volume', 0),
                        'amount': etf_data.get('amount', 0),
                        'turnover_rate': etf_data.get('turnover_rate', 0),
                        'change': etf_data.get('change', 0),
                        'pct_chg': etf_data.get('change_percent', 0),
                        'is_closing_data': is_closing_update,
                        'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    }
                    kline_data.append(new_kline)
                    
                    # 保持最多1000条K线
                    if len(kline_data) > 1000:
                        kline_data = kline_data[-1000:]
                    
                    redis_cache.set_cache(kline_key, kline_data, ttl=604800)
                    appended_count += 1
                    
            except Exception as e:
                failed_count += 1
                if failed_count <= 5:
                    logger.warning(f"合并ETF {code} 实时数据失败: {e}")
                continue
        
        total_success = updated_count + appended_count + created_count
        
        if failed_count > 0:
            logger.warning(f"⚠️  有 {failed_count} 只ETF更新失败")
        
        return total_success, failed_count
        
    except Exception as e:
        logger.error(f"合并ETF实时数据到K线失败: {e}")
        logger.error(traceback.format_exc())
        return 0, len(realtime_dict)


def update_realtime_data(force_update=False, is_closing_update=False, auto_calculate_signals=False) -> Dict[str, Any]:
    """
    更新实时数据（股票+ETF）
    
    流程：
    1. 使用新浪接口获取股票实时数据（失败时降级到 akshare）
    2. 使用东方财富获取 ETF 实时数据
    3. 合并到K线数据
    4. 触发一次信号计算（如果配置允许）
    
    Args:
        force_update: 是否强制更新，忽略交易时间检查
        is_closing_update: 是否为收盘后更新
        auto_calculate_signals: 是否自动计算买入信号
        
    Returns:
        更新结果字典
    """
    start_time = datetime.now()
    
    try:
        if is_closing_update:
            logger.info("📊 开始更新收盘数据（股票+ETF）...")
        else:
            logger.info("📊 开始更新实时数据（股票+ETF）...")
        
        # 步骤1: 使用降级策略获取股票实时数据（优先新浪，失败时降级到 akshare）
        logger.info("📊 步骤1/3: 获取股票实时数据（新浪接口 -> akshare 降级）...")
        stock_realtime_data, data_source = get_stock_realtime_data_with_fallback(prefer_source='sina')
        
        if not stock_realtime_data:
            raise Exception("获取股票实时数据为空（新浪和akshare均失败）")
        
        # 存储到Redis
        redis_cache.set_cache(STOCK_KEYS['realtime_data'], {
            'data': stock_realtime_data,
            'count': len(stock_realtime_data),
            'update_time': datetime.now().isoformat(),
            'data_source': data_source,
            'is_closing_data': is_closing_update
        }, ttl=1800)
        
        # 合并股票实时数据到K线
        stock_success, stock_failed = merge_stock_realtime_to_kline(stock_realtime_data, is_closing_update)
        logger.info(f"   ✅ 股票更新完成: 成功 {stock_success} 只, 失败 {stock_failed} 只")
        
        # 步骤2: 获取ETF实时数据
        logger.info("📊 步骤2/3: 获取ETF实时数据（东方财富）...")
        etf_realtime_dict, etf_source = get_etf_realtime_data(force_update=True)
        
        if not etf_realtime_dict:
            logger.warning("⚠️  获取ETF实时数据为空，跳过ETF更新")
            etf_success, etf_failed = 0, 0
        else:
            # 合并ETF实时数据到K线
            etf_success, etf_failed = merge_etf_realtime_to_kline(etf_realtime_dict, is_closing_update)
            logger.info(f"   ✅ ETF更新完成: 成功 {etf_success} 只, 失败 {etf_failed} 只")
        
        # 步骤3: 触发信号计算（只触发一次）
        from app.core.config import REALTIME_AUTO_CALCULATE_SIGNALS
        should_calculate = REALTIME_AUTO_CALCULATE_SIGNALS if not auto_calculate_signals else auto_calculate_signals
        
        if should_calculate:
            logger.info("📊 步骤3/3: 触发买入信号计算（股票+ETF统一计算）...")
            # 导入触发函数
            from app.services.scheduler.stock_scheduler import _trigger_signal_recalculation_async
            _trigger_signal_recalculation_async()
            signal_status = "✅ 信号计算已触发"
        else:
            logger.info("📊 步骤3/3: 跳过信号计算（配置: REALTIME_AUTO_CALCULATE_SIGNALS=false）")
            signal_status = "⏭️ 信号计算已跳过"
        
        total_success = stock_success + etf_success
        total_failed = stock_failed + etf_failed
        execution_time = (datetime.now() - start_time).total_seconds()
        
        logger.info("=" * 70)
        logger.info("🎉 实时数据更新完成")
        logger.info(f"   📈 股票: 成功 {stock_success} 只, 失败 {stock_failed} 只")
        logger.info(f"   📊 ETF:  成功 {etf_success} 只, 失败 {etf_failed} 只")
        logger.info(f"   📋 总计: 成功 {total_success} 只, 失败 {total_failed} 只")
        logger.info(f"   🔔 信号: {signal_status}")
        logger.info(f"   ⏱️  耗时: {execution_time:.2f}秒")
        logger.info(f"   📡 数据源: 股票({data_source}) + ETF(东方财富)")
        logger.info("=" * 70)
        
        return {
            'success': True,
            'stock_success': stock_success,
            'stock_failed': stock_failed,
            'etf_success': etf_success,
            'etf_failed': etf_failed,
            'total_success': total_success,
            'total_failed': total_failed,
            'execution_time': execution_time,
            'signal_status': signal_status
        }
        
    except Exception as e:
        execution_time = (datetime.now() - start_time).total_seconds()
        error_msg = f'实时数据更新失败: {str(e)}'
        logger.error(f"❌ {error_msg}")
        logger.error(traceback.format_exc())
        
        return {
            'success': False,
            'error': error_msg,
            'execution_time': execution_time
        }

