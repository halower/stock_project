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







