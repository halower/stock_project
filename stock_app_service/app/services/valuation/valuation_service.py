# -*- coding: utf-8 -*-
"""
估值分析服务 - 提供股票估值指标分析和筛选功能

主要功能：
1. 获取估值指标 - PE、PB、PS、股息率等
2. 财务数据获取 - ROE、ROA、负债率等
3. 估值筛选 - 多维度筛选低估值股票
4. 估值排名 - 按各类指标排序
5. 历史估值对比 - 估值分位数分析
"""

import tushare as ts
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from app.core.logging import logger
from app.core.config import settings
from app.db.session import RedisCache
import json


class ValuationService:
    """估值分析服务类"""
    
    def __init__(self):
        """初始化估值服务"""
        try:
            self.pro = ts.pro_api(settings.TUSHARE_TOKEN)
            self.redis_cache = RedisCache()
            logger.info("估值分析服务初始化成功")
        except Exception as e:
            logger.error(f"估值分析服务初始化失败: {e}")
            raise
    
    async def get_daily_basic_data(self, trade_date: Optional[str] = None) -> Dict[str, Any]:
        """
        获取每日指标数据（PE、PB、PS等）
        
        Args:
            trade_date: 交易日期（YYYYMMDD格式），默认最新交易日
            
        Returns:
            {
                'success': bool,
                'data': List[Dict],  # 估值数据列表
                'count': int,
                'trade_date': str,
                'timestamp': str
            }
        """
        try:
            if not trade_date:
                trade_date = datetime.now().strftime('%Y%m%d')
            
            # 先尝试获取"最新交易日"的缓存
            latest_cache_key = "valuation:daily_basic:latest"
            cached_latest = self.redis_cache.get_cache(latest_cache_key)
            if cached_latest and isinstance(cached_latest, dict):
                logger.info(f"从缓存获取最新交易日数据: {cached_latest.get('trade_date')}")
                return {
                    'success': True,
                    'data': cached_latest.get('data', []),
                    'count': len(cached_latest.get('data', [])),
                    'trade_date': cached_latest.get('trade_date', trade_date),
                    'timestamp': datetime.now().isoformat(),
                    'from_cache': True
                }
            
            # 尝试从指定日期的缓存获取
            cache_key = f"valuation:daily_basic:{trade_date}"
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                logger.info(f"从缓存获取每日指标数据: {trade_date}")
                return {
                    'success': True,
                    'data': cached_data,
                    'count': len(cached_data),
                    'trade_date': trade_date,
                    'timestamp': datetime.now().isoformat(),
                    'from_cache': True
                }
            
            logger.info(f"从Tushare获取每日指标数据: {trade_date}")
            
            # 调用Tushare接口获取每日指标
            df = self.pro.daily_basic(
                trade_date=trade_date,
                fields='ts_code,trade_date,close,turnover_rate,turnover_rate_f,volume_ratio,pe,pe_ttm,pb,ps,ps_ttm,dv_ratio,dv_ttm,total_share,float_share,free_share,total_mv,circ_mv'
            )
            
            if df.empty:
                # 如果当天没有数据，尝试获取最近的交易日数据（向前查找最多10天）
                logger.warning(f"日期 {trade_date} 无数据，尝试获取最近交易日数据")
                
                current_date = datetime.strptime(trade_date, '%Y%m%d')
                for i in range(1, 11):  # 最多向前查找10天
                    prev_date = (current_date - timedelta(days=i)).strftime('%Y%m%d')
                    logger.info(f"尝试获取 {prev_date} 的数据")
                    
                    df = self.pro.daily_basic(
                        trade_date=prev_date,
                        fields='ts_code,trade_date,close,turnover_rate,turnover_rate_f,volume_ratio,pe,pe_ttm,pb,ps,ps_ttm,dv_ratio,dv_ttm,total_share,float_share,free_share,total_mv,circ_mv'
                    )
                    
                    if not df.empty:
                        trade_date = prev_date
                        logger.info(f"找到最近交易日数据: {trade_date}")
                        break
                
                if df.empty:
                    return {
                        'success': False,
                        'error': '未获取到估值数据（最近10天无交易数据）',
                        'data': [],
                        'count': 0
                    }
            
            # 转换数据格式
            valuation_data = []
            for _, row in df.iterrows():
                data = {
                    'ts_code': row.get('ts_code', ''),
                    'trade_date': row.get('trade_date', ''),
                    'close': float(row.get('close', 0)) if pd.notna(row.get('close')) else 0,
                    'turnover_rate': float(row.get('turnover_rate', 0)) if pd.notna(row.get('turnover_rate')) else 0,
                    'volume_ratio': float(row.get('volume_ratio', 0)) if pd.notna(row.get('volume_ratio')) else 0,
                    'pe': float(row.get('pe', 0)) if pd.notna(row.get('pe')) else None,
                    'pe_ttm': float(row.get('pe_ttm', 0)) if pd.notna(row.get('pe_ttm')) else None,
                    'pb': float(row.get('pb', 0)) if pd.notna(row.get('pb')) else None,
                    'ps': float(row.get('ps', 0)) if pd.notna(row.get('ps')) else None,
                    'ps_ttm': float(row.get('ps_ttm', 0)) if pd.notna(row.get('ps_ttm')) else None,
                    'dv_ratio': float(row.get('dv_ratio', 0)) if pd.notna(row.get('dv_ratio')) else None,
                    'dv_ttm': float(row.get('dv_ttm', 0)) if pd.notna(row.get('dv_ttm')) else None,
                    'total_mv': float(row.get('total_mv', 0)) if pd.notna(row.get('total_mv')) else 0,
                    'circ_mv': float(row.get('circ_mv', 0)) if pd.notna(row.get('circ_mv')) else 0
                }
                valuation_data.append(data)
            
            # 缓存数据（24小时）
            self.redis_cache.set_cache(cache_key, valuation_data, ttl=86400)
            
            # 同时缓存为"最新交易日"数据（24小时）
            latest_data = {
                'data': valuation_data,
                'trade_date': trade_date
            }
            self.redis_cache.set_cache(latest_cache_key, latest_data, ttl=86400)
            
            logger.info(f"成功获取 {len(valuation_data)} 只股票的估值数据（交易日: {trade_date}）")
            
            return {
                'success': True,
                'data': valuation_data,
                'count': len(valuation_data),
                'trade_date': trade_date,
                'timestamp': datetime.now().isoformat(),
                'from_cache': False
            }
            
        except Exception as e:
            logger.error(f"获取每日指标数据失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'data': [],
                'count': 0
            }
    
    async def screening_by_valuation(
        self,
        pe_min: Optional[float] = None,
        pe_max: Optional[float] = None,
        pb_min: Optional[float] = None,
        pb_max: Optional[float] = None,
        ps_min: Optional[float] = None,
        ps_max: Optional[float] = None,
        dividend_yield_min: Optional[float] = None,
        market_value_min: Optional[float] = None,
        market_value_max: Optional[float] = None,
        limit: int = 100
    ) -> Dict[str, Any]:
        """
        按估值指标筛选股票
        
        Args:
            pe_min: PE最小值
            pe_max: PE最大值
            pb_min: PB最小值
            pb_max: PB最大值
            ps_min: PS最小值
            ps_max: PS最大值
            dividend_yield_min: 股息率最小值
            market_value_min: 市值最小值（亿元）
            market_value_max: 市值最大值（亿元）
            limit: 返回数量限制
            
        Returns:
            {
                'success': bool,
                'data': List[Dict],  # 筛选结果
                'count': int,
                'filters': Dict,  # 筛选条件
                'timestamp': str
            }
        """
        try:
            # 构建缓存键
            cache_key = f"valuation:screening:{pe_min}_{pe_max}_{pb_min}_{pb_max}_{ps_min}_{ps_max}_{dividend_yield_min}_{market_value_min}_{market_value_max}_{limit}"
            
            # 尝试从缓存获取（5分钟）
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                logger.info("从缓存获取估值筛选结果")
                return cached_data
            
            # 获取最新的每日指标数据
            daily_basic_result = await self.get_daily_basic_data()
            if not daily_basic_result['success']:
                return {
                    'success': False,
                    'error': '无法获取估值数据',
                    'data': [],
                    'count': 0
                }
            
            valuation_data = daily_basic_result['data']
            
            # 获取股票名称映射
            stock_names = await self._get_stock_names()
            
            # 应用筛选条件
            filtered_stocks = []
            for stock in valuation_data:
                # PE筛选
                if pe_min is not None and (stock['pe_ttm'] is None or stock['pe_ttm'] < pe_min):
                    continue
                if pe_max is not None and (stock['pe_ttm'] is None or stock['pe_ttm'] > pe_max):
                    continue
                
                # PB筛选
                if pb_min is not None and (stock['pb'] is None or stock['pb'] < pb_min):
                    continue
                if pb_max is not None and (stock['pb'] is None or stock['pb'] > pb_max):
                    continue
                
                # PS筛选
                if ps_min is not None and (stock['ps_ttm'] is None or stock['ps_ttm'] < ps_min):
                    continue
                if ps_max is not None and (stock['ps_ttm'] is None or stock['ps_ttm'] > ps_max):
                    continue
                
                # 股息率筛选
                if dividend_yield_min is not None and (stock['dv_ttm'] is None or stock['dv_ttm'] < dividend_yield_min):
                    continue
                
                # 市值筛选（total_mv单位是万元，需要转换为亿元）
                market_value = stock['total_mv'] / 10000 if stock['total_mv'] > 0 else 0
                if market_value_min is not None and market_value < market_value_min:
                    continue
                if market_value_max is not None and market_value > market_value_max:
                    continue
                
                # 过滤掉估值异常的股票（PE或PB为负或过大）
                if stock['pe_ttm'] and (stock['pe_ttm'] < 0 or stock['pe_ttm'] > 1000):
                    continue
                if stock['pb'] and (stock['pb'] < 0 or stock['pb'] > 100):
                    continue
                
                # 添加股票名称
                stock_code = stock['ts_code'].split('.')[0]
                stock['stock_code'] = stock_code
                stock['stock_name'] = stock_names.get(stock['ts_code'], stock_names.get(stock_code, ''))
                stock['market_value'] = round(market_value, 2)
                
                filtered_stocks.append(stock)
            
            # 限制返回数量
            filtered_stocks = filtered_stocks[:limit]
            
            result = {
                'success': True,
                'data': filtered_stocks,
                'count': len(filtered_stocks),
                'filters': {
                    'pe_min': pe_min,
                    'pe_max': pe_max,
                    'pb_min': pb_min,
                    'pb_max': pb_max,
                    'ps_min': ps_min,
                    'ps_max': ps_max,
                    'dividend_yield_min': dividend_yield_min,
                    'market_value_min': market_value_min,
                    'market_value_max': market_value_max
                },
                'timestamp': datetime.now().isoformat()
            }
            
            # 缓存5分钟
            self.redis_cache.set_cache(cache_key, result, ttl=300)
            
            logger.info(f"估值筛选完成，筛选出 {len(filtered_stocks)} 只股票")
            
            return result
            
        except Exception as e:
            logger.error(f"估值筛选失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'data': [],
                'count': 0
            }
    
    async def get_valuation_ranking(
        self,
        rank_by: str = 'pe',
        order: str = 'asc',
        limit: int = 100
    ) -> Dict[str, Any]:
        """
        获取估值排名
        
        Args:
            rank_by: 排名依据（pe, pb, ps, dividend_yield, market_value）
            order: 排序方式（asc=升序, desc=降序）
            limit: 返回数量限制
            
        Returns:
            {
                'success': bool,
                'rank_by': str,
                'order': str,
                'data': List[Dict],  # 排名列表
                'count': int,
                'timestamp': str
            }
        """
        try:
            cache_key = f"valuation:ranking:{rank_by}_{order}_{limit}"
            
            # 尝试从缓存获取（5分钟）
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                logger.info(f"从缓存获取估值排名: {rank_by}")
                return cached_data
            
            # 获取最新的每日指标数据
            daily_basic_result = await self.get_daily_basic_data()
            if not daily_basic_result['success']:
                return {
                    'success': False,
                    'error': '无法获取估值数据',
                    'data': [],
                    'count': 0
                }
            
            valuation_data = daily_basic_result['data']
            
            # 获取股票名称映射
            stock_names = await self._get_stock_names()
            
            # 添加股票名称和市值（亿元）
            for stock in valuation_data:
                stock_code = stock['ts_code'].split('.')[0]
                stock['stock_code'] = stock_code
                stock['stock_name'] = stock_names.get(stock['ts_code'], stock_names.get(stock_code, ''))
                stock['market_value'] = round(stock['total_mv'] / 10000, 2) if stock['total_mv'] > 0 else 0
            
            # 根据排名字段过滤和排序
            field_map = {
                'pe': 'pe_ttm',
                'pb': 'pb',
                'ps': 'ps_ttm',
                'dividend_yield': 'dv_ttm',
                'market_value': 'market_value'
            }
            
            sort_field = field_map.get(rank_by, 'pe_ttm')
            
            # 过滤掉无效数据
            valid_stocks = [s for s in valuation_data if s.get(sort_field) is not None and s.get(sort_field) > 0]
            
            # 排序
            reverse = (order == 'desc')
            valid_stocks.sort(key=lambda x: x[sort_field], reverse=reverse)
            
            # 限制返回数量
            valid_stocks = valid_stocks[:limit]
            
            result = {
                'success': True,
                'rank_by': rank_by,
                'order': order,
                'data': valid_stocks,
                'count': len(valid_stocks),
                'timestamp': datetime.now().isoformat()
            }
            
            # 缓存5分钟
            self.redis_cache.set_cache(cache_key, result, ttl=300)
            
            logger.info(f"成功获取估值排名，排序字段: {rank_by}，数量: {len(valid_stocks)}")
            
            return result
            
        except Exception as e:
            logger.error(f"获取估值排名失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'rank_by': rank_by,
                'order': order,
                'data': [],
                'count': 0
            }
    
    async def get_stock_valuation_detail(self, stock_code: str) -> Dict[str, Any]:
        """
        获取个股估值详情
        
        Args:
            stock_code: 股票代码（如：000001）
            
        Returns:
            {
                'success': bool,
                'stock_code': str,
                'stock_name': str,
                'current_valuation': Dict,  # 当前估值指标
                'timestamp': str
            }
        """
        try:
            # 转换股票代码格式
            if stock_code.startswith('6'):
                ts_code = f"{stock_code}.SH"
            elif stock_code.startswith(('0', '3')):
                ts_code = f"{stock_code}.SZ"
            elif stock_code.startswith(('43', '83', '87', '88')):
                ts_code = f"{stock_code}.BJ"
            else:
                ts_code = f"{stock_code}.SZ"
            
            cache_key = f"valuation:detail:{ts_code}"
            
            # 尝试从缓存获取（5分钟）
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                logger.info(f"从缓存获取股票估值详情: {stock_code}")
                return cached_data
            
            # 获取最新的每日指标数据
            daily_basic_result = await self.get_daily_basic_data()
            if not daily_basic_result['success']:
                return {
                    'success': False,
                    'error': '无法获取估值数据',
                    'stock_code': stock_code
                }
            
            # 查找该股票的数据
            stock_data = None
            for stock in daily_basic_result['data']:
                if stock['ts_code'] == ts_code:
                    stock_data = stock
                    break
            
            if not stock_data:
                return {
                    'success': False,
                    'error': '未找到该股票的估值数据',
                    'stock_code': stock_code
                }
            
            # 获取股票名称
            stock_names = await self._get_stock_names()
            stock_name = stock_names.get(ts_code, stock_names.get(stock_code, ''))
            
            result = {
                'success': True,
                'stock_code': stock_code,
                'ts_code': ts_code,
                'stock_name': stock_name,
                'current_valuation': {
                    'close': stock_data['close'],
                    'pe': stock_data['pe'],
                    'pe_ttm': stock_data['pe_ttm'],
                    'pb': stock_data['pb'],
                    'ps': stock_data['ps'],
                    'ps_ttm': stock_data['ps_ttm'],
                    'dividend_yield': stock_data['dv_ttm'],
                    'market_value': round(stock_data['total_mv'] / 10000, 2) if stock_data['total_mv'] > 0 else 0,
                    'circ_market_value': round(stock_data['circ_mv'] / 10000, 2) if stock_data['circ_mv'] > 0 else 0,
                    'turnover_rate': stock_data['turnover_rate'],
                    'volume_ratio': stock_data['volume_ratio']
                },
                'timestamp': datetime.now().isoformat()
            }
            
            # 缓存5分钟
            self.redis_cache.set_cache(cache_key, result, ttl=300)
            
            logger.info(f"成功获取股票 {stock_code} 的估值详情")
            
            return result
            
        except Exception as e:
            logger.error(f"获取股票估值详情失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'stock_code': stock_code
            }
    
    async def _get_stock_names(self) -> Dict[str, str]:
        """
        获取股票名称映射
        
        Returns:
            {ts_code: name} 或 {stock_code: name}
        """
        try:
            # 从Redis获取股票列表
            stock_codes_data = self.redis_cache.get_cache("stocks:codes:all")
            
            if not stock_codes_data:
                return {}
            
            if isinstance(stock_codes_data, str):
                stock_codes = json.loads(stock_codes_data)
            else:
                stock_codes = stock_codes_data
            
            # 构建名称映射
            name_map = {}
            for stock in stock_codes:
                ts_code = stock.get('ts_code', '')
                stock_code = stock.get('symbol', '') or stock.get('code', '')
                name = stock.get('name', '')
                
                if ts_code and name:
                    name_map[ts_code] = name
                if stock_code and name:
                    name_map[stock_code] = name
            
            return name_map
            
        except Exception as e:
            logger.error(f"获取股票名称映射失败: {e}")
            return {}

