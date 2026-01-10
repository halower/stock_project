# -*- coding: utf-8 -*-
"""
多周期K线数据服务
支持日线、周线、月线、15分钟、60分钟等多种周期
日线使用Tushare，其他周期使用AKShare
"""

import time
import pandas as pd
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from app.core.logging import logger
from app.db.session import RedisCache


class MultiPeriodKlineService:
    """多周期K线数据服务"""
    
    # 支持的周期配置（15分钟找买点，60分钟日内趋势，日线+周线看大方向）
    PERIODS = {
        '15min': {
            'name': '15分钟',
            'cache_ttl': 300,  # 5分钟（交易时间）
            'source': 'akshare_min',
            'ak_period': '15',
        },
        '60min': {
            'name': '60分钟',
            'cache_ttl': 600,  # 10分钟
            'source': 'akshare_min',
            'ak_period': '60',
        },
        'daily': {
            'name': '日线',
            'cache_ttl': 86400,  # 24小时
            'source': 'tushare',
            'ak_period': 'daily',
        },
        'weekly': {
            'name': '周线',
            'cache_ttl': 3600,  # 1小时
            'source': 'akshare',
            'ak_period': 'weekly',
        },
    }
    
    # AKShare请求间隔（毫秒）
    MIN_REQUEST_INTERVAL = 150
    _last_request_time = 0
    
    def __init__(self):
        """初始化服务"""
        self.redis_cache = RedisCache()
        logger.info("多周期K线服务初始化成功")
    
    def _wait_for_rate_limit(self):
        """等待请求间隔，防止被限制"""
        now = time.time() * 1000
        elapsed = now - self._last_request_time
        if elapsed < self.MIN_REQUEST_INTERVAL:
            time.sleep((self.MIN_REQUEST_INTERVAL - elapsed) / 1000)
        MultiPeriodKlineService._last_request_time = time.time() * 1000
    
    def _is_trading_time(self) -> bool:
        """判断是否在交易时间"""
        now = datetime.now()
        # 周末不交易
        if now.weekday() >= 5:
            return False
        
        hour = now.hour
        minute = now.minute
        current_time = hour * 60 + minute
        
        # 交易时间：9:30-11:30, 13:00-15:00
        morning_start = 9 * 60 + 30
        morning_end = 11 * 60 + 30
        afternoon_start = 13 * 60
        afternoon_end = 15 * 60
        
        return (morning_start <= current_time <= morning_end) or \
               (afternoon_start <= current_time <= afternoon_end)
    
    def _get_cache_ttl(self, period: str) -> int:
        """根据交易时间动态调整缓存TTL"""
        base_ttl = self.PERIODS.get(period, {}).get('cache_ttl', 3600)
        
        # 非交易时间延长缓存
        if not self._is_trading_time():
            if period in ['15min', '30min', '60min']:
                return 3600  # 分钟级延长到1小时
            elif period in ['weekly', 'monthly']:
                return 86400  # 周线月线延长到24小时
        
        return base_ttl
    
    def _convert_stock_code(self, stock_code: str) -> tuple:
        """
        转换股票代码格式
        
        Returns:
            (ts_code, ak_symbol, market)
            ts_code: Tushare格式 如 000001.SZ
            ak_symbol: AKShare格式 如 000001
            market: 市场 sh/sz
        """
        # 移除可能的后缀
        code = stock_code.replace('.SH', '').replace('.SZ', '').replace('.BJ', '')
        
        if code.startswith('6'):
            return f"{code}.SH", code, 'sh'
        elif code.startswith('5'):
            return f"{code}.SH", code, 'sh'  # ETF
        elif code.startswith(('43', '83', '87', '88')):
            return f"{code}.BJ", code, 'bj'  # 北交所
        else:
            return f"{code}.SZ", code, 'sz'
    
    async def get_kline_data(
        self,
        stock_code: str,
        period: str = 'daily',
        limit: int = 200
    ) -> Dict[str, Any]:
        """
        获取指定周期的K线数据
        
        Args:
            stock_code: 股票代码
            period: K线周期 daily/weekly/monthly/15min/30min/60min
            limit: 返回数据条数
            
        Returns:
            {
                'success': bool,
                'data': List[Dict],
                'period': str,
                'period_name': str,
                'count': int,
                'from_cache': bool
            }
        """
        try:
            if period not in self.PERIODS:
                return {
                    'success': False,
                    'error': f'不支持的K线周期: {period}，支持的周期: {list(self.PERIODS.keys())}'
                }
            
            period_config = self.PERIODS[period]
            ts_code, ak_symbol, market = self._convert_stock_code(stock_code)
            
            # 检查缓存
            cache_key = f"kline:{period}:{ts_code}"
            cached_data = self.redis_cache.get_cache(cache_key)
            
            if cached_data:
                logger.info(f"从缓存获取 {stock_code} {period_config['name']} 数据")
                return {
                    'success': True,
                    'data': cached_data[:limit],
                    'period': period,
                    'period_name': period_config['name'],
                    'count': min(len(cached_data), limit),
                    'from_cache': True
                }
            
            # 根据数据源获取数据
            source = period_config['source']
            
            if source == 'tushare':
                kline_data = await self._fetch_tushare_daily(ts_code, limit)
            elif source == 'akshare':
                kline_data = await self._fetch_akshare_daily(ak_symbol, period_config['ak_period'], limit)
            elif source == 'akshare_min':
                kline_data = await self._fetch_akshare_minute(ak_symbol, period_config['ak_period'], limit)
            else:
                return {'success': False, 'error': f'未知数据源: {source}'}
            
            if not kline_data:
                return {
                    'success': False,
                    'error': f'获取 {stock_code} {period_config["name"]} 数据失败'
                }
            
            # 缓存数据
            cache_ttl = self._get_cache_ttl(period)
            self.redis_cache.set_cache(cache_key, kline_data, ttl=cache_ttl)
            
            logger.info(f"成功获取 {stock_code} {period_config['name']} 数据 {len(kline_data)} 条")
            
            return {
                'success': True,
                'data': kline_data[:limit],
                'period': period,
                'period_name': period_config['name'],
                'count': min(len(kline_data), limit),
                'from_cache': False
            }
            
        except Exception as e:
            logger.error(f"获取K线数据失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {'success': False, 'error': str(e)}
    
    async def _fetch_tushare_daily(self, ts_code: str, limit: int = 200) -> Optional[List[Dict]]:
        """从Tushare获取日线数据"""
        try:
            import tushare as ts
            from app.core.config import settings
            
            pro = ts.pro_api(settings.TUSHARE_TOKEN)
            
            end_date = datetime.now().strftime('%Y%m%d')
            start_date = (datetime.now() - timedelta(days=limit * 2)).strftime('%Y%m%d')
            
            # 判断是否ETF
            if ts_code.startswith('5') or ts_code.startswith('15'):
                df = pro.fund_daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
            else:
                df = pro.daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
            
            if df is None or df.empty:
                return None
            
            df = df.sort_values('trade_date').tail(limit)
            
            return self._convert_df_to_kline(df, 'tushare')
            
        except Exception as e:
            logger.error(f"Tushare获取日线失败: {e}")
            return None
    
    async def _fetch_akshare_daily(self, symbol: str, period: str, limit: int = 200) -> Optional[List[Dict]]:
        """从AKShare获取日线/周线/月线数据"""
        try:
            import akshare as ak
            
            self._wait_for_rate_limit()
            
            # 计算日期范围
            end_date = datetime.now().strftime('%Y%m%d')
            if period == 'weekly':
                start_date = (datetime.now() - timedelta(days=limit * 7)).strftime('%Y%m%d')
            elif period == 'monthly':
                start_date = (datetime.now() - timedelta(days=limit * 30)).strftime('%Y%m%d')
            else:
                start_date = (datetime.now() - timedelta(days=limit * 2)).strftime('%Y%m%d')
            
            logger.info(f"AKShare获取 {symbol} {period} 数据...")
            
            df = ak.stock_zh_a_hist(
                symbol=symbol,
                period=period,
                start_date=start_date,
                end_date=end_date,
                adjust="qfq"  # 前复权
            )
            
            if df is None or df.empty:
                logger.warning(f"AKShare返回空数据: {symbol} {period}")
                return None
            
            df = df.tail(limit)
            
            return self._convert_df_to_kline(df, 'akshare')
            
        except Exception as e:
            logger.error(f"AKShare获取{period}数据失败: {e}")
            return None
    
    async def _fetch_akshare_minute(self, symbol: str, period: str, limit: int = 200) -> Optional[List[Dict]]:
        """从AKShare获取分钟级数据"""
        try:
            import akshare as ak
            
            self._wait_for_rate_limit()
            
            logger.info(f"AKShare获取 {symbol} {period}分钟 数据...")
            
            df = ak.stock_zh_a_hist_min_em(
                symbol=symbol,
                period=period,
                adjust="qfq"  # 前复权
            )
            
            if df is None or df.empty:
                logger.warning(f"AKShare返回空数据: {symbol} {period}min")
                return None
            
            df = df.tail(limit)
            
            return self._convert_df_to_kline(df, 'akshare_min')
            
        except Exception as e:
            logger.error(f"AKShare获取分钟数据失败: {e}")
            return None
    
    def _convert_df_to_kline(self, df: pd.DataFrame, source: str) -> List[Dict]:
        """统一转换DataFrame为K线数据格式"""
        kline_data = []
        
        for _, row in df.iterrows():
            if source == 'tushare':
                item = {
                    'date': str(row.get('trade_date', '')),
                    'open': float(row.get('open', 0)),
                    'high': float(row.get('high', 0)),
                    'low': float(row.get('low', 0)),
                    'close': float(row.get('close', 0)),
                    'volume': float(row.get('vol', 0)) * 100,  # 手转股
                    'amount': float(row.get('amount', 0)) * 1000,  # 千元转元
                    'change_pct': float(row.get('pct_chg', 0)) if pd.notna(row.get('pct_chg')) else 0,
                }
            elif source == 'akshare':
                # 东方财富日线/周线/月线数据
                item = {
                    'date': str(row.get('日期', '')),
                    'open': float(row.get('开盘', 0)),
                    'high': float(row.get('最高', 0)),
                    'low': float(row.get('最低', 0)),
                    'close': float(row.get('收盘', 0)),
                    'volume': float(row.get('成交量', 0)),
                    'amount': float(row.get('成交额', 0)),
                    'change_pct': float(row.get('涨跌幅', 0)) if pd.notna(row.get('涨跌幅')) else 0,
                }
            elif source == 'akshare_min':
                # 东方财富分钟数据
                item = {
                    'date': str(row.get('时间', '')),
                    'open': float(row.get('开盘', 0)),
                    'high': float(row.get('最高', 0)),
                    'low': float(row.get('最低', 0)),
                    'close': float(row.get('收盘', 0)),
                    'volume': float(row.get('成交量', 0)),
                    'amount': float(row.get('成交额', 0)),
                    'change_pct': float(row.get('涨跌幅', 0)) if pd.notna(row.get('涨跌幅')) else 0,
                }
            else:
                continue
            
            kline_data.append(item)
        
        return kline_data
    
    def get_supported_periods(self) -> Dict[str, str]:
        """获取支持的周期列表"""
        return {k: v['name'] for k, v in self.PERIODS.items()}


# 全局服务实例
multi_period_kline_service = MultiPeriodKlineService()

