# -*- coding: utf-8 -*-
"""
指数数据服务 - 专门处理大盘指数数据
"""

import tushare as ts
import pandas as pd
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from app.core.logging import logger
from app.core.config import settings
from app.db.session import RedisCache


class IndexService:
    """指数数据服务类"""
    
    def __init__(self):
        """初始化指数服务"""
        try:
            self.pro = ts.pro_api(settings.TUSHARE_TOKEN)
            self.redis_cache = RedisCache()
            logger.info("指数服务初始化成功")
        except Exception as e:
            logger.error(f"指数服务初始化失败: {e}")
            raise
    
    async def get_index_daily(
        self,
        index_code: str = "000001.SH",
        days: int = 180
    ) -> Dict[str, Any]:
        """
        获取指数日线数据
        
        Args:
            index_code: 指数代码，默认000001.SH（上证指数）
                - 000001.SH: 上证指数
                - 399001.SZ: 深证成指
                - 399006.SZ: 创业板指
                - 399107.SZ: 深证A指（包含所有深市A股）
            days: 获取天数，默认180天
            
        Returns:
            {
                'success': bool,
                'data': List[Dict],  # K线数据
                'count': int,
                'index_code': str,
                'index_name': str
            }
        """
        try:
            logger.info(f"开始获取指数 {index_code} 的日线数据，天数: {days}")
            
            # 先尝试从Redis缓存获取
            cache_key = f"index:daily:{index_code}:{days}"
            cached_data = self.redis_cache.get_cache(cache_key)
            
            if cached_data:
                logger.info(f"从缓存获取指数 {index_code} 数据")
                return cached_data
            
            # 计算日期范围（扩大2倍以确保获取足够的交易日数据）
            end_date = datetime.now().strftime('%Y%m%d')
            start_date = (datetime.now() - timedelta(days=days * 2)).strftime('%Y%m%d')
            
            # 调用tushare接口获取指数日线数据
            df = self.pro.index_daily(
                ts_code=index_code,
                start_date=start_date,
                end_date=end_date
            )
            
            if df is None or df.empty:
                logger.warning(f"指数 {index_code} 日线数据为空")
                return {
                    'success': False,
                    'error': '指数数据为空',
                    'data': [],
                    'count': 0,
                    'index_code': index_code
                }
            
            # 按日期排序并取最近的指定天数
            df = df.sort_values('trade_date').tail(days)
            
            # 转换为字典列表
            kline_data = []
            for _, row in df.iterrows():
                kline_data.append({
                    'trade_date': str(row['trade_date']),
                    'open': float(row['open']) if pd.notna(row['open']) else 0.0,
                    'high': float(row['high']) if pd.notna(row['high']) else 0.0,
                    'low': float(row['low']) if pd.notna(row['low']) else 0.0,
                    'close': float(row['close']) if pd.notna(row['close']) else 0.0,
                    'pre_close': float(row['pre_close']) if pd.notna(row['pre_close']) else 0.0,
                    'change': float(row['change']) if pd.notna(row['change']) else 0.0,
                    'pct_chg': float(row['pct_chg']) if pd.notna(row['pct_chg']) else 0.0,
                    'vol': float(row['vol']) if pd.notna(row['vol']) else 0.0,
                    'amount': float(row['amount']) if pd.notna(row['amount']) else 0.0
                })
            
            # 获取指数名称
            index_names = {
                '000001.SH': '上证指数',
                '399001.SZ': '深证成指',
                '399006.SZ': '创业板指',
                '399107.SZ': '深证A指',
                '000300.SH': '沪深300',
                '000016.SH': '上证50',
                '000905.SH': '中证500'
            }
            index_name = index_names.get(index_code, index_code)
            
            result = {
                'success': True,
                'data': kline_data,
                'count': len(kline_data),
                'index_code': index_code,
                'index_name': index_name
            }
            
            # 缓存结果（5分钟）
            self.redis_cache.set_cache(cache_key, result, ttl=300)
            
            logger.info(f"成功获取指数 {index_code} 的 {len(kline_data)} 条日线数据")
            return result
            
        except Exception as e:
            logger.error(f"获取指数日线数据失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'error': str(e),
                'data': [],
                'count': 0,
                'index_code': index_code
            }
    
    async def get_index_list(self) -> Dict[str, Any]:
        """
        获取常用指数列表
        
        Returns:
            {
                'success': bool,
                'data': List[Dict]  # 指数列表
            }
        """
        try:
            # 常用指数列表
            indices = [
                {'code': '000001.SH', 'name': '上证指数', 'market': '上海'},
                {'code': '399001.SZ', 'name': '深证成指', 'market': '深圳'},
                {'code': '399006.SZ', 'name': '创业板指', 'market': '深圳'},
                {'code': '399107.SZ', 'name': '深证A指', 'market': '深圳'},
                {'code': '000300.SH', 'name': '沪深300', 'market': '跨市场'},
                {'code': '000016.SH', 'name': '上证50', 'market': '上海'},
                {'code': '000905.SH', 'name': '中证500', 'market': '跨市场'},
            ]
            
            return {
                'success': True,
                'data': indices,
                'count': len(indices)
            }
            
        except Exception as e:
            logger.error(f"获取指数列表失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'data': []
            }


# 创建全局实例
index_service = IndexService()

