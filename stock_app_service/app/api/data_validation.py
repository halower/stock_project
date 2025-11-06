# -*- coding: utf-8 -*-
"""
数据验证API
提供接口验证当天的股票和ETF数据情况
"""

from fastapi import APIRouter, Query
from datetime import datetime
from typing import Dict, Any, List, Optional
import random

from app.core.logging import logger
from app.db.session import RedisCache
from app.core.etf_config import get_etf_list

router = APIRouter()
redis_cache = RedisCache()

# Redis键名规则
STOCK_KEYS = {
    'stock_codes': 'stocks:codes:all',
    'stock_kline': 'stock_trend:{}',
}

ETF_KEYS = {
    'etf_codes': 'etf:codes:all',
    'etf_kline': 'etf_trend:{}',
}


@router.get("/api/data/validation/today", summary="验证当天数据")
async def validate_today_data(
    sample_size: int = Query(default=20, description="抽样数量", ge=1, le=100),
    check_stocks: bool = Query(default=True, description="是否检查股票"),
    check_etfs: bool = Query(default=True, description="是否检查ETF")
) -> Dict[str, Any]:
    """
    验证当天的股票和ETF是否有K线数据
    
    返回：
    - 总体统计
    - 抽样检查结果
    - 数据源信息
    """
    try:
        today_str = datetime.now().strftime('%Y-%m-%d')
        today_trade_date = datetime.now().strftime('%Y%m%d')
        
        result = {
            'today': today_str,
            'check_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'stocks': None,
            'etfs': None
        }
        
        # 检查股票
        if check_stocks:
            stock_result = await _check_stocks_today_data(today_str, today_trade_date, sample_size)
            result['stocks'] = stock_result
        
        # 检查ETF
        if check_etfs:
            etf_result = await _check_etfs_today_data(today_str, today_trade_date, sample_size)
            result['etfs'] = etf_result
        
        return {
            'success': True,
            'data': result
        }
        
    except Exception as e:
        logger.error(f"验证当天数据失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return {
            'success': False,
            'error': str(e)
        }


async def _check_stocks_today_data(today_str: str, today_trade_date: str, sample_size: int) -> Dict[str, Any]:
    """检查股票当天数据"""
    try:
        # 获取所有股票代码
        stock_codes = redis_cache.get_cache(STOCK_KEYS['stock_codes'])
        
        if not stock_codes:
            return {
                'error': '未找到股票代码列表',
                'total': 0
            }
        
        # 过滤出纯股票（排除ETF）
        pure_stocks = [s for s in stock_codes if s.get('market') != 'ETF']
        total_stocks = len(pure_stocks)
        
        # 随机抽样
        sample_stocks = random.sample(pure_stocks, min(sample_size, total_stocks))
        
        # 检查抽样股票
        has_today_data = []
        no_today_data = []
        no_kline_data = []
        
        for stock in sample_stocks:
            ts_code = stock.get('ts_code')
            code = stock.get('code', ts_code.split('.')[0] if ts_code else '')
            name = stock.get('name', '')
            
            # 获取K线数据
            kline_key = STOCK_KEYS['stock_kline'].format(ts_code)
            kline_data = redis_cache.get_cache(kline_key)
            
            if not kline_data:
                no_kline_data.append({
                    'code': code,
                    'name': name,
                    'ts_code': ts_code,
                    'reason': '无K线数据'
                })
                continue
            
            # 处理不同格式
            if isinstance(kline_data, dict):
                kline_list = kline_data.get('data', [])
            elif isinstance(kline_data, list):
                kline_list = kline_data
            else:
                no_kline_data.append({
                    'code': code,
                    'name': name,
                    'ts_code': ts_code,
                    'reason': '数据格式错误'
                })
                continue
            
            if not kline_list:
                no_kline_data.append({
                    'code': code,
                    'name': name,
                    'ts_code': ts_code,
                    'reason': 'K线列表为空'
                })
                continue
            
            # 检查最后一根K线是否是今天的
            last_kline = kline_list[-1]
            last_trade_date = str(last_kline.get('trade_date', ''))
            last_date = last_kline.get('actual_trade_date', last_kline.get('date', ''))
            
            is_today = (last_date == today_str) or (last_trade_date == today_trade_date)
            
            stock_info = {
                'code': code,
                'name': name,
                'ts_code': ts_code,
                'last_date': last_date or last_trade_date,
                'last_price': last_kline.get('close', 0),
                'is_closing_data': last_kline.get('is_closing_data', False),
                'update_time': last_kline.get('update_time', ''),
                'total_klines': len(kline_list)
            }
            
            if is_today:
                has_today_data.append(stock_info)
            else:
                no_today_data.append(stock_info)
        
        # 统计
        return {
            'total': total_stocks,
            'sample_size': len(sample_stocks),
            'has_today_data': {
                'count': len(has_today_data),
                'percentage': round(len(has_today_data) / len(sample_stocks) * 100, 2) if sample_stocks else 0,
                'samples': has_today_data[:10]  # 只返回前10个样本
            },
            'no_today_data': {
                'count': len(no_today_data),
                'percentage': round(len(no_today_data) / len(sample_stocks) * 100, 2) if sample_stocks else 0,
                'samples': no_today_data[:10]
            },
            'no_kline_data': {
                'count': len(no_kline_data),
                'percentage': round(len(no_kline_data) / len(sample_stocks) * 100, 2) if sample_stocks else 0,
                'samples': no_kline_data[:10]
            }
        }
        
    except Exception as e:
        logger.error(f"检查股票数据失败: {e}")
        return {
            'error': str(e)
        }


async def _check_etfs_today_data(today_str: str, today_trade_date: str, sample_size: int) -> Dict[str, Any]:
    """检查ETF当天数据"""
    try:
        # 获取ETF列表
        etf_list = get_etf_list()
        
        if not etf_list:
            return {
                'error': '未找到ETF列表',
                'total': 0
            }
        
        total_etfs = len(etf_list)
        
        # 随机抽样
        sample_etfs = random.sample(etf_list, min(sample_size, total_etfs))
        
        # 检查抽样ETF
        has_today_data = []
        no_today_data = []
        no_kline_data = []
        
        for etf in sample_etfs:
            ts_code = etf.get('ts_code')
            code = etf.get('symbol')
            name = etf.get('name', '')
            
            # 获取K线数据
            kline_key = ETF_KEYS['etf_kline'].format(ts_code)
            kline_data = redis_cache.get_cache(kline_key)
            
            if not kline_data or not isinstance(kline_data, list) or len(kline_data) == 0:
                no_kline_data.append({
                    'code': code,
                    'name': name,
                    'ts_code': ts_code,
                    'reason': '无K线数据'
                })
                continue
            
            # 检查最后一根K线是否是今天的
            last_kline = kline_data[-1]
            last_date = str(last_kline.get('date', ''))
            last_trade_date = str(last_kline.get('trade_date', ''))
            
            is_today = (last_date == today_str) or (last_trade_date == today_trade_date)
            
            etf_info = {
                'code': code,
                'name': name,
                'ts_code': ts_code,
                'last_date': last_date or last_trade_date,
                'last_price': last_kline.get('close', 0),
                'is_closing_data': last_kline.get('is_closing_data', False),
                'update_time': last_kline.get('update_time', ''),
                'total_klines': len(kline_data)
            }
            
            if is_today:
                has_today_data.append(etf_info)
            else:
                no_today_data.append(etf_info)
        
        # 统计
        return {
            'total': total_etfs,
            'sample_size': len(sample_etfs),
            'has_today_data': {
                'count': len(has_today_data),
                'percentage': round(len(has_today_data) / len(sample_etfs) * 100, 2) if sample_etfs else 0,
                'samples': has_today_data[:10]
            },
            'no_today_data': {
                'count': len(no_today_data),
                'percentage': round(len(no_today_data) / len(sample_etfs) * 100, 2) if sample_etfs else 0,
                'samples': no_today_data[:10]
            },
            'no_kline_data': {
                'count': len(no_kline_data),
                'percentage': round(len(no_kline_data) / len(sample_etfs) * 100, 2) if sample_etfs else 0,
                'samples': no_kline_data[:10]
            }
        }
        
    except Exception as e:
        logger.error(f"检查ETF数据失败: {e}")
        return {
            'error': str(e)
        }


@router.get("/api/data/validation/stock/{ts_code}", summary="验证单个股票数据")
async def validate_single_stock(ts_code: str) -> Dict[str, Any]:
    """
    验证单个股票的K线数据
    
    Args:
        ts_code: 股票代码，如 000001.SZ
    """
    try:
        today_str = datetime.now().strftime('%Y-%m-%d')
        today_trade_date = datetime.now().strftime('%Y%m%d')
        
        # 获取K线数据
        kline_key = STOCK_KEYS['stock_kline'].format(ts_code)
        kline_data = redis_cache.get_cache(kline_key)
        
        if not kline_data:
            return {
                'success': False,
                'error': f'未找到 {ts_code} 的K线数据'
            }
        
        # 处理不同格式
        if isinstance(kline_data, dict):
            kline_list = kline_data.get('data', [])
            metadata = {
                'updated_at': kline_data.get('updated_at'),
                'data_count': kline_data.get('data_count'),
                'source': kline_data.get('source'),
                'last_update_type': kline_data.get('last_update_type')
            }
        elif isinstance(kline_data, list):
            kline_list = kline_data
            metadata = {'format': 'legacy_list'}
        else:
            return {
                'success': False,
                'error': '数据格式错误'
            }
        
        if not kline_list:
            return {
                'success': False,
                'error': 'K线列表为空'
            }
        
        # 分析最近几根K线
        recent_klines = kline_list[-5:] if len(kline_list) >= 5 else kline_list
        
        # 检查是否有今天的数据
        last_kline = kline_list[-1]
        last_trade_date = str(last_kline.get('trade_date', ''))
        last_date = last_kline.get('actual_trade_date', last_kline.get('date', ''))
        
        has_today = (last_date == today_str) or (last_trade_date == today_trade_date)
        
        return {
            'success': True,
            'data': {
                'ts_code': ts_code,
                'today': today_str,
                'has_today_data': has_today,
                'total_klines': len(kline_list),
                'last_kline': {
                    'date': last_date or last_trade_date,
                    'open': last_kline.get('open'),
                    'high': last_kline.get('high'),
                    'low': last_kline.get('low'),
                    'close': last_kline.get('close'),
                    'volume': last_kline.get('vol', last_kline.get('volume')),
                    'is_closing_data': last_kline.get('is_closing_data', False),
                    'update_time': last_kline.get('update_time', '')
                },
                'recent_klines': [
                    {
                        'date': k.get('actual_trade_date', k.get('date', k.get('trade_date', ''))),
                        'close': k.get('close'),
                        'volume': k.get('vol', k.get('volume')),
                    }
                    for k in recent_klines
                ],
                'metadata': metadata
            }
        }
        
    except Exception as e:
        logger.error(f"验证股票 {ts_code} 数据失败: {e}")
        return {
            'success': False,
            'error': str(e)
        }


@router.get("/api/data/validation/etf/{ts_code}", summary="验证单个ETF数据")
async def validate_single_etf(ts_code: str) -> Dict[str, Any]:
    """
    验证单个ETF的K线数据
    
    Args:
        ts_code: ETF代码，如 510050.SH
    """
    try:
        today_str = datetime.now().strftime('%Y-%m-%d')
        today_trade_date = datetime.now().strftime('%Y%m%d')
        
        # 获取K线数据
        kline_key = ETF_KEYS['etf_kline'].format(ts_code)
        kline_data = redis_cache.get_cache(kline_key)
        
        if not kline_data or not isinstance(kline_data, list) or len(kline_data) == 0:
            return {
                'success': False,
                'error': f'未找到 {ts_code} 的K线数据'
            }
        
        # 分析最近几根K线
        recent_klines = kline_data[-5:] if len(kline_data) >= 5 else kline_data
        
        # 检查是否有今天的数据
        last_kline = kline_data[-1]
        last_date = str(last_kline.get('date', ''))
        last_trade_date = str(last_kline.get('trade_date', ''))
        
        has_today = (last_date == today_str) or (last_trade_date == today_trade_date)
        
        return {
            'success': True,
            'data': {
                'ts_code': ts_code,
                'today': today_str,
                'has_today_data': has_today,
                'total_klines': len(kline_data),
                'last_kline': {
                    'date': last_date or last_trade_date,
                    'open': last_kline.get('open'),
                    'high': last_kline.get('high'),
                    'low': last_kline.get('low'),
                    'close': last_kline.get('close'),
                    'volume': last_kline.get('volume'),
                    'is_closing_data': last_kline.get('is_closing_data', False),
                    'update_time': last_kline.get('update_time', '')
                },
                'recent_klines': [
                    {
                        'date': k.get('date', k.get('trade_date', '')),
                        'close': k.get('close'),
                        'volume': k.get('volume'),
                    }
                    for k in recent_klines
                ]
            }
        }
        
    except Exception as e:
        logger.error(f"验证ETF {ts_code} 数据失败: {e}")
        return {
            'success': False,
            'error': str(e)
        }

