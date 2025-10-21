# -*- coding: utf-8 -*-
"""
基于Redis的股票数据服务
全面替代传统数据库，实现股票代码、历史数据、实时数据的获取和存储
"""

import tushare as ts
import akshare as ak
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import requests
import time

from app.core.logging import logger
from app.db.session import RedisCache
from app.services.realtime_service import get_realtime_service

# Redis缓存客户端
redis_cache = RedisCache()

def get_stock_names() -> Dict[str, Any]:
    """
    获取股票代码和名称列表
    优先使用Tushare，失败时使用AKShare
    """
    try:
        logger.info("开始获取股票代码列表...")
        
        # 尝试使用Tushare获取
        try:
            pro = ts.pro_api()
            df = pro.stock_basic(exchange='', list_status='L', fields='ts_code,symbol,name,area,industry,market')
            
            if not df.empty:
                stock_list = []
                for _, row in df.iterrows():
                    stock_list.append({
                        'ts_code': row['ts_code'],
                        'symbol': row['symbol'],
                        'name': row['name'],
                        'area': row['area'] if pd.notna(row['area']) else '',
                        'industry': row['industry'] if pd.notna(row['industry']) else '',
                        'market': row['market'] if pd.notna(row['market']) else ''
                    })
                
                logger.info(f"Tushare成功获取 {len(stock_list)} 只股票代码")
                return {
                    'success': True,
                    'data': stock_list,
                    'count': len(stock_list),
                    'source': 'tushare'
                }
                
        except Exception as e:
            logger.warning(f"Tushare获取股票代码失败: {str(e)}")
        
        # 备用方案：使用AKShare获取
        try:
            logger.info("使用AKShare获取股票代码...")
            df = ak.stock_info_a_code_name()
            
            if not df.empty:
                stock_list = []
                for _, row in df.iterrows():
                    code = row['code']
                    name = row['name']
                    
                    # 判断交易所
                    if code.startswith('6'):
                        ts_code = f"{code}.SH"
                        market = 'SH'
                    elif code.startswith(('43', '83', '87', '88')):
                        ts_code = f"{code}.BJ"
                        market = 'BJ'
                    else:
                        ts_code = f"{code}.SZ"
                        market = 'SZ'
                    
                    stock_list.append({
                        'ts_code': ts_code,
                        'symbol': code,
                        'name': name,
                        'area': '',
                        'industry': '',
                        'market': market
                    })
                
                logger.info(f"AKShare成功获取 {len(stock_list)} 只股票代码")
                return {
                    'success': True,
                    'data': stock_list,
                    'count': len(stock_list),
                    'source': 'akshare'
                }
                
        except Exception as e:
            logger.error(f"AKShare获取股票代码也失败: {str(e)}")
        
        return {
            'error': '所有数据源都无法获取股票代码'
        }
        
    except Exception as e:
        logger.error(f"获取股票代码异常: {str(e)}")
        return {
            'error': str(e)
        }

def get_stock_history(stock_code: str, days: int = 120) -> Dict[str, Any]:
    """
    获取股票历史数据
    优先使用Tushare，失败时使用AKShare
    """
    try:
        logger.info(f"开始获取股票 {stock_code} 的历史数据，天数: {days}")
        
        # 尝试使用Tushare获取
        try:
            history_data = get_stock_history_tushare(stock_code, days)
            if history_data:
                return {
                    'success': True,
                    'data': history_data,
                    'count': len(history_data),
                    'source': 'tushare'
                }
        except Exception as e:
            logger.warning(f"Tushare获取历史数据失败: {str(e)}")
        
        # 备用方案：使用AKShare获取
        try:
            history_data = get_stock_history_akshare(stock_code, days)
            if history_data:
                return {
                    'success': True,
                    'data': history_data,
                    'count': len(history_data),
                    'source': 'akshare'
                }
        except Exception as e:
            logger.error(f"AKShare获取历史数据也失败: {str(e)}")
        
        return {
            'error': f'无法获取股票 {stock_code} 的历史数据'
        }
        
    except Exception as e:
        logger.error(f"获取股票历史数据异常: {str(e)}")
        return {
            'error': str(e)
        }

def get_stock_history_tushare(stock_code: str, days: int = 120) -> List[Dict[str, Any]]:
    """
    通过Tushare获取股票历史数据
    """
    try:
        pro = ts.pro_api()
        
        # 转换股票代码格式
        if stock_code.startswith('6'):
            ts_code = f"{stock_code}.SH"
        elif stock_code.startswith('5'):
            # 5开头是上海ETF（如510030、512660）
            ts_code = f"{stock_code}.SH"
        elif stock_code.startswith(('43', '83', '87', '88')):
            ts_code = f"{stock_code}.BJ"
        else:
            ts_code = f"{stock_code}.SZ"
        
        # 计算日期范围
        end_date = datetime.now().strftime('%Y%m%d')
        start_date = (datetime.now() - timedelta(days=days * 2)).strftime('%Y%m%d')
        
        # 判断是否为ETF（5开头的上海ETF，1开头的深圳ETF）
        is_etf = stock_code.startswith(('5', '1')) and len(stock_code) == 6
        
        # 获取历史数据 - ETF使用fund_daily接口，股票使用daily接口
        if is_etf:
            logger.info(f"检测到ETF {stock_code}，使用fund_daily接口")
            df = pro.fund_daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
        else:
            df = pro.daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
        
        if df.empty:
            return []
        
        # 按日期排序并取最近的指定天数
        df = df.sort_values('trade_date').tail(days)
        
        # 转换数据格式 - 使用安全访问，避免字段不存在导致的错误
        history_data = []
        for _, row in df.iterrows():
            try:
                data = {
                    "date": datetime.strptime(str(row["trade_date"]), '%Y%m%d').strftime('%Y-%m-%d'),
                    "open": float(row.get("open", 0)) if pd.notna(row.get("open")) else 0,
                    "close": float(row.get("close", 0)) if pd.notna(row.get("close")) else 0,
                    "high": float(row.get("high", 0)) if pd.notna(row.get("high")) else 0,
                    "low": float(row.get("low", 0)) if pd.notna(row.get("low")) else 0,
                    "volume": float(row.get("vol", 0)) * 100 if pd.notna(row.get("vol")) else 0,
                    "amount": float(row.get("amount", 0)) * 1000 if pd.notna(row.get("amount")) else 0,
                    "pct_chg": float(row.get("pct_chg", 0)) if pd.notna(row.get("pct_chg")) else 0,
                    "change": float(row.get("change", 0)) if pd.notna(row.get("change")) else 0,
                }
                history_data.append(data)
            except Exception as e:
                logger.error(f"转换第 {len(history_data)+1} 行数据失败: {str(e)}, 原始数据: {row.to_dict()}")
                raise
        
        return history_data
        
    except Exception as e:
        logger.error(f"Tushare获取股票 {stock_code} 历史数据失败: {str(e)}")
        raise

def get_stock_history_akshare(stock_code: str, days: int = 120) -> List[Dict[str, Any]]:
    """
    通过AKShare获取股票历史数据
    """
    try:
        # 计算日期范围
        end_date = datetime.now().strftime('%Y%m%d')
        start_date = (datetime.now() - timedelta(days=days * 2)).strftime('%Y%m%d')
        
        # 使用akshare获取历史数据
        df = ak.stock_zh_a_hist(symbol=stock_code, period="daily", start_date=start_date, end_date=end_date, adjust="")
        
        if df.empty:
            return []
        
        # 只取最近的指定天数
        df = df.tail(days)
        
        # 转换数据格式
        history_data = []
        for _, row in df.iterrows():
            data = {
                "date": row["日期"].strftime('%Y-%m-%d') if pd.notna(row["日期"]) else '',
                "open": float(row["开盘"]),
                "close": float(row["收盘"]),
                "high": float(row["最高"]),
                "low": float(row["最低"]),
                "volume": float(row["成交量"]) if pd.notna(row["成交量"]) else 0,
                "amount": float(row["成交额"]) if pd.notna(row["成交额"]) else 0,
                "pct_chg": float(row["涨跌幅"]) if "涨跌幅" in row and pd.notna(row["涨跌幅"]) else 0,
                "change": float(row["涨跌额"]) if "涨跌额" in row and pd.notna(row["涨跌额"]) else 0,
            }
            history_data.append(data)
        
        return history_data
        
    except Exception as e:
        logger.error(f"AKShare获取股票 {stock_code} 历史数据失败: {str(e)}")
        raise

def get_realtime_stock_data(stock_code: str, provider: str = None) -> Dict[str, Any]:
    """
    获取股票实时数据
    使用统一的实时行情服务，支持多数据源自动切换
    
    Args:
        stock_code: 股票代码
        provider: 指定数据提供商（eastmoney, sina, auto），None则使用默认配置
    
    Returns:
        包含实时数据的字典
    """
    try:
        logger.info(f"开始获取股票 {stock_code} 的实时数据")
        
        # 使用新的统一实时行情服务
        service = get_realtime_service()
        result = service.get_single_stock_realtime(stock_code, provider)
        
        if result.get('success'):
            # 转换为旧格式以保持兼容性
            data = result.get('data', {})
            return {
                'success': True,
                'data': {
                    'stock_code': data.get('code'),
                    'name': data.get('name', ''),
                    'price': data.get('price', 0.0),
                    'change': data.get('change', 0.0),
                    'pct_chg': data.get('change_percent', 0.0),
                    'open': data.get('open', 0.0),
                    'high': data.get('high', 0.0),
                    'low': data.get('low', 0.0),
                    'volume': data.get('volume', 0.0),
                    'amount': data.get('amount', 0.0),
                    'turnover_rate': data.get('turnover_rate', 0.0),
                    'update_time': data.get('update_time', '')
                },
                'source': result.get('source')
            }
        else:
            # 失败时返回占位数据
            return {
                'success': True,
                'data': {
                    'stock_code': stock_code,
                    'price': 0.0,
                    'change': 0.0,
                    'pct_chg': 0.0,
                    'volume': 0,
                    'amount': 0.0,
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'status': 'no_data'
                },
                'source': 'placeholder',
                'error': result.get('error', '未知错误')
            }
        
    except Exception as e:
        logger.error(f"获取股票实时数据异常: {str(e)}")
        return {
            'success': False,
            'error': str(e),
            'data': {
                'stock_code': stock_code,
                'price': 0.0,
                'change': 0.0,
                'pct_chg': 0.0,
                'volume': 0,
                'amount': 0.0,
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'status': 'error'
            }
        }

def get_realtime_data_akshare(stock_code: str) -> Dict[str, Any]:
    """
    通过AKShare获取股票实时数据（已废弃，保留用于向后兼容）
    建议使用 get_realtime_stock_data() 或直接使用 realtime_service
    """
    logger.warning("get_realtime_data_akshare() 已废弃，建议使用 get_realtime_stock_data()")
    result = get_realtime_stock_data(stock_code, provider='eastmoney')
    if result.get('success'):
        return result.get('data')
    return None

def store_stock_data_to_redis(key: str, data: Any, ttl: int = None) -> bool:
    """
    将股票数据存储到Redis
    """
    try:
        redis_cache.set_cache(key, data, ttl=ttl)
        return True
    except Exception as e:
        logger.error(f"存储数据到Redis失败: {str(e)}")
        return False

def get_stock_data_from_redis(key: str) -> Any:
    """
    从Redis获取股票数据
    """
    try:
        return redis_cache.get_cache(key)
    except Exception as e:
        logger.error(f"从Redis获取数据失败: {str(e)}")
        return None

def calculate_ma(prices: List[float], period: int) -> float:
    """
    计算移动平均线
    """
    if len(prices) < period:
        return 0.0
    
    return sum(prices[-period:]) / period

def calculate_technical_indicators(history_data: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    计算技术指标
    """
    if not history_data or len(history_data) < 20:
        return {}
    
    try:
        # 提取收盘价
        closes = [float(d.get('close', 0)) for d in history_data]
        
        # 计算各种均线
        ma5 = calculate_ma(closes, 5)
        ma10 = calculate_ma(closes, 10)
        ma20 = calculate_ma(closes, 20)
        ma50 = calculate_ma(closes, 50) if len(closes) >= 50 else 0
        
        # 当前价格
        current_price = closes[-1] if closes else 0
        
        # 计算涨跌幅
        prev_price = closes[-2] if len(closes) > 1 else current_price
        pct_chg = ((current_price - prev_price) / prev_price * 100) if prev_price > 0 else 0
        
        return {
            'current_price': current_price,
            'ma5': ma5,
            'ma10': ma10,
            'ma20': ma20,
            'ma50': ma50,
            'pct_chg': pct_chg,
            'data_count': len(history_data)
        }
        
    except Exception as e:
        logger.error(f"计算技术指标失败: {str(e)}")
        return {}

# Redis键名常量
REDIS_KEYS = {
    'stock_codes': 'stocks:codes:all',
    'stock_history': 'stocks:history:{}',  # {stock_code}
    'stock_realtime': 'stocks:realtime:{}',  # {stock_code}
    'stock_indicators': 'stocks:indicators:{}',  # {stock_code}
    'stock_signals': 'stocks:signals:all',
    'last_update': 'stocks:update:{}'  # {data_type}
} 