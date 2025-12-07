# -*- coding: utf-8 -*-
"""
打板分析服务
基于Tushare打板专题接口，提供涨跌停、炸板、龙虎榜等数据

Tushare打板专题接口：
1. limit_list_d - 每日涨跌停、炸板数据 (需要5000积分)
2. stk_limit - 涨跌停价格
3. top_list - 龙虎榜每日明细
4. top_inst - 龙虎榜机构明细
"""

import asyncio
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import pandas as pd

from app.core.logging import logger
from app.core.config import settings
from app.db.session import RedisCache
from app.services.stock.unified_data_service import get_rate_limiter


class LimitBoardService:
    """打板分析服务"""
    
    def __init__(self):
        self.redis_cache = RedisCache()
        self.rate_limiter = get_rate_limiter()
        self._pro = None
    
    @property
    def pro(self):
        """延迟加载tushare pro api"""
        if self._pro is None:
            import tushare as ts
            self._pro = ts.pro_api(settings.TUSHARE_TOKEN)
        return self._pro
    
    # ==================== 1. 涨跌停数据 ====================
    
    def get_limit_list(
        self,
        trade_date: Optional[str] = None,
        limit_type: str = 'U',  # U-涨停 D-跌停
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """
        获取每日涨跌停列表
        
        Args:
            trade_date: 交易日期，格式YYYYMMDD，默认最近交易日
            limit_type: 涨跌停类型 U-涨停 D-跌停
            use_cache: 是否使用缓存
            
        Returns:
            涨跌停数据列表
        """
        try:
            if trade_date is None:
                trade_date = self._get_last_trade_date()
            
            cache_key = f"limit_list:{trade_date}:{limit_type}"
            
            # 尝试从缓存获取
            if use_cache:
                cached = self.redis_cache.get_cache(cache_key)
                if cached:
                    logger.debug(f"从缓存获取涨跌停数据: {cache_key}")
                    return cached
            
            # 等待频率限制
            self.rate_limiter.wait_if_needed()
            self.rate_limiter._record_call()
            
            # 调用limit_list_d接口（需要5000积分）
            try:
                df = self.pro.limit_list_d(
                    trade_date=trade_date,
                    limit_type=limit_type,
                    fields='trade_date,ts_code,name,close,pct_chg,amp,fc_ratio,fl_ratio,fd_amount,first_time,last_time,open_times,up_stat,limit_times,limit'
                )
            except Exception as e:
                error_msg = str(e)
                if "权限" in error_msg or "积分" in error_msg or "5000" in error_msg:
                    logger.warning(f"limit_list_d接口需要5000积分，尝试使用替代方案")
                    return self._get_limit_list_alternative(trade_date, limit_type)
                raise
            
            if df is None or df.empty:
                logger.warning(f"涨跌停数据为空: {trade_date}")
                return {
                    'success': True,
                    'trade_date': trade_date,
                    'limit_type': limit_type,
                    'count': 0,
                    'data': []
                }
            
            # 转换为列表
            data = []
            for _, row in df.iterrows():
                item = {
                    'trade_date': str(row.get('trade_date', '')),
                    'ts_code': str(row.get('ts_code', '')),
                    'name': str(row.get('name', '')),
                    'close': float(row.get('close', 0)) if pd.notna(row.get('close')) else 0,
                    'pct_chg': float(row.get('pct_chg', 0)) if pd.notna(row.get('pct_chg')) else 0,
                    'amp': float(row.get('amp', 0)) if pd.notna(row.get('amp')) else 0,  # 振幅
                    'fc_ratio': float(row.get('fc_ratio', 0)) if pd.notna(row.get('fc_ratio')) else 0,  # 封成比
                    'fl_ratio': float(row.get('fl_ratio', 0)) if pd.notna(row.get('fl_ratio')) else 0,  # 封流比
                    'fd_amount': float(row.get('fd_amount', 0)) if pd.notna(row.get('fd_amount')) else 0,  # 封单金额
                    'first_time': str(row.get('first_time', '')) if pd.notna(row.get('first_time')) else '',  # 首次封板时间
                    'last_time': str(row.get('last_time', '')) if pd.notna(row.get('last_time')) else '',  # 最后封板时间
                    'open_times': int(row.get('open_times', 0)) if pd.notna(row.get('open_times')) else 0,  # 开板次数
                    'up_stat': str(row.get('up_stat', '')) if pd.notna(row.get('up_stat')) else '',  # 连板统计
                    'limit_times': int(row.get('limit_times', 0)) if pd.notna(row.get('limit_times')) else 0,  # 连板次数
                    'limit': str(row.get('limit', '')) if pd.notna(row.get('limit')) else '',  # 涨跌停状态
                }
                data.append(item)
            
            # 按连板次数排序
            data.sort(key=lambda x: x['limit_times'], reverse=True)
            
            result = {
                'success': True,
                'trade_date': trade_date,
                'limit_type': limit_type,
                'count': len(data),
                'data': data,
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
            # 缓存结果
            self.redis_cache.set_cache(cache_key, result, ttl=3600)  # 1小时
            
            logger.info(f"获取涨跌停数据成功: {trade_date}, 类型: {limit_type}, 数量: {len(data)}")
            return result
            
        except Exception as e:
            logger.error(f"获取涨跌停数据失败: {e}")
            return {
                'success': False,
                'message': str(e),
                'trade_date': trade_date,
                'limit_type': limit_type,
                'count': 0,
                'data': []
            }
    
    def _get_limit_list_alternative(
        self,
        trade_date: str,
        limit_type: str
    ) -> Dict[str, Any]:
        """
        替代方案：使用stk_limit接口获取涨跌停股票
        stk_limit不需要额外积分
        """
        try:
            self.rate_limiter.wait_if_needed()
            self.rate_limiter._record_call()
            
            # 使用stk_limit获取涨跌停价格数据
            df = self.pro.stk_limit(
                trade_date=trade_date,
                fields='trade_date,ts_code,pre_close,up_limit,down_limit'
            )
            
            if df is None or df.empty:
                return {
                    'success': True,
                    'trade_date': trade_date,
                    'limit_type': limit_type,
                    'count': 0,
                    'data': [],
                    'source': 'stk_limit'
                }
            
            # 获取当日收盘价数据
            self.rate_limiter.wait_if_needed()
            self.rate_limiter._record_call()
            
            daily_df = self.pro.daily(
                trade_date=trade_date,
                fields='ts_code,close,pct_chg,vol,amount'
            )
            
            if daily_df is not None and not daily_df.empty:
                # 合并数据
                df = df.merge(daily_df, on='ts_code', how='left')
                
                # 筛选涨停或跌停
                if limit_type == 'U':
                    # 涨停：收盘价 >= 涨停价 * 0.999
                    df = df[df['close'] >= df['up_limit'] * 0.999]
                else:
                    # 跌停：收盘价 <= 跌停价 * 1.001
                    df = df[df['close'] <= df['down_limit'] * 1.001]
            
            # 获取股票名称
            stock_basic = self._get_stock_basic()
            
            data = []
            for _, row in df.iterrows():
                ts_code = str(row.get('ts_code', ''))
                name = stock_basic.get(ts_code, ts_code[:6])
                
                item = {
                    'trade_date': trade_date,
                    'ts_code': ts_code,
                    'name': name,
                    'close': float(row.get('close', 0)) if pd.notna(row.get('close')) else 0,
                    'pct_chg': float(row.get('pct_chg', 0)) if pd.notna(row.get('pct_chg')) else 0,
                    'up_limit': float(row.get('up_limit', 0)) if pd.notna(row.get('up_limit')) else 0,
                    'down_limit': float(row.get('down_limit', 0)) if pd.notna(row.get('down_limit')) else 0,
                    'vol': float(row.get('vol', 0)) if pd.notna(row.get('vol')) else 0,
                    'amount': float(row.get('amount', 0)) if pd.notna(row.get('amount')) else 0,
                }
                data.append(item)
            
            # 按涨跌幅排序
            data.sort(key=lambda x: x['pct_chg'], reverse=(limit_type == 'U'))
            
            return {
                'success': True,
                'trade_date': trade_date,
                'limit_type': limit_type,
                'count': len(data),
                'data': data,
                'source': 'stk_limit',
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except Exception as e:
            logger.error(f"替代方案获取涨跌停数据失败: {e}")
            return {
                'success': False,
                'message': str(e),
                'trade_date': trade_date,
                'limit_type': limit_type,
                'count': 0,
                'data': []
            }
    
    # ==================== 2. 龙虎榜数据 ====================
    
    def get_top_list(
        self,
        trade_date: Optional[str] = None,
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """
        获取龙虎榜数据
        
        Args:
            trade_date: 交易日期，格式YYYYMMDD
            use_cache: 是否使用缓存
            
        Returns:
            龙虎榜数据
        """
        try:
            if trade_date is None:
                trade_date = self._get_last_trade_date()
            
            cache_key = f"top_list:{trade_date}"
            
            # 尝试从缓存获取
            if use_cache:
                cached = self.redis_cache.get_cache(cache_key)
                if cached:
                    logger.debug(f"从缓存获取龙虎榜数据: {cache_key}")
                    return cached
            
            # 等待频率限制
            self.rate_limiter.wait_if_needed()
            self.rate_limiter._record_call()
            
            # 调用top_list接口
            df = self.pro.top_list(
                trade_date=trade_date,
                fields='trade_date,ts_code,name,close,pct_change,turnover_rate,amount,l_sell,l_buy,l_amount,net_amount,net_rate,amount_rate,float_values,reason'
            )
            
            if df is None or df.empty:
                logger.warning(f"龙虎榜数据为空: {trade_date}")
                return {
                    'success': True,
                    'trade_date': trade_date,
                    'count': 0,
                    'data': []
                }
            
            # 转换为列表
            data = []
            for _, row in df.iterrows():
                item = {
                    'trade_date': str(row.get('trade_date', '')),
                    'ts_code': str(row.get('ts_code', '')),
                    'name': str(row.get('name', '')),
                    'close': float(row.get('close', 0)) if pd.notna(row.get('close')) else 0,
                    'pct_change': float(row.get('pct_change', 0)) if pd.notna(row.get('pct_change')) else 0,
                    'turnover_rate': float(row.get('turnover_rate', 0)) if pd.notna(row.get('turnover_rate')) else 0,
                    'amount': float(row.get('amount', 0)) if pd.notna(row.get('amount')) else 0,  # 总成交额
                    'l_sell': float(row.get('l_sell', 0)) if pd.notna(row.get('l_sell')) else 0,  # 龙虎榜卖出额
                    'l_buy': float(row.get('l_buy', 0)) if pd.notna(row.get('l_buy')) else 0,  # 龙虎榜买入额
                    'l_amount': float(row.get('l_amount', 0)) if pd.notna(row.get('l_amount')) else 0,  # 龙虎榜成交额
                    'net_amount': float(row.get('net_amount', 0)) if pd.notna(row.get('net_amount')) else 0,  # 龙虎榜净买入额
                    'net_rate': float(row.get('net_rate', 0)) if pd.notna(row.get('net_rate')) else 0,  # 净买入占比
                    'amount_rate': float(row.get('amount_rate', 0)) if pd.notna(row.get('amount_rate')) else 0,  # 成交额占比
                    'float_values': float(row.get('float_values', 0)) if pd.notna(row.get('float_values')) else 0,  # 流通市值
                    'reason': str(row.get('reason', '')) if pd.notna(row.get('reason')) else '',  # 上榜原因
                }
                data.append(item)
            
            # 按净买入额排序
            data.sort(key=lambda x: x['net_amount'], reverse=True)
            
            result = {
                'success': True,
                'trade_date': trade_date,
                'count': len(data),
                'data': data,
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
            # 缓存结果
            self.redis_cache.set_cache(cache_key, result, ttl=3600)
            
            logger.info(f"获取龙虎榜数据成功: {trade_date}, 数量: {len(data)}")
            return result
            
        except Exception as e:
            logger.error(f"获取龙虎榜数据失败: {e}")
            return {
                'success': False,
                'message': str(e),
                'trade_date': trade_date,
                'count': 0,
                'data': []
            }
    
    # ==================== 3. 连板统计 ====================
    
    def _get_recent_trade_dates(self, end_date: str, days: int = 5) -> List[str]:
        """
        获取最近N个交易日（排除周末）
        
        Args:
            end_date: 结束日期，格式YYYYMMDD
            days: 需要的交易日数量
            
        Returns:
            交易日期列表，从旧到新排序
        """
        trade_dates = []
        current_date = datetime.strptime(end_date, '%Y%m%d')
        
        while len(trade_dates) < days:
            # 跳过周末
            if current_date.weekday() < 5:  # 0-4是周一到周五
                trade_dates.append(current_date.strftime('%Y%m%d'))
            current_date -= timedelta(days=1)
        
        # 从旧到新排序
        trade_dates.reverse()
        return trade_dates
    
    def _calculate_continuous_limit_days(
        self,
        ts_code: str,
        recent_limit_data: List[Dict[str, Any]]
    ) -> int:
        """
        计算连板天数
        
        Args:
            ts_code: 股票代码
            recent_limit_data: 最近几天的涨停数据列表（按日期从旧到新排序）
            
        Returns:
            连板天数
        """
        continuous_days = 0
        
        # 从最新的一天往前数
        for day_data in reversed(recent_limit_data):
            # 检查这一天是否涨停
            stock_data = next((item for item in day_data.get('data', []) if item.get('ts_code') == ts_code), None)
            if stock_data:
                continuous_days += 1
            else:
                # 一旦中断就停止计数
                break
        
        return continuous_days
    
    def get_continuous_limit_stats(
        self,
        trade_date: Optional[str] = None,
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """
        获取连板统计数据（基于最近5天数据自己计算连板天数）
        
        Args:
            trade_date: 交易日期
            use_cache: 是否使用缓存
            
        Returns:
            连板统计数据
        """
        try:
            if trade_date is None:
                trade_date = self._get_last_trade_date()
            
            cache_key = f"continuous_limit_stats_v2:{trade_date}"
            
            # 尝试从缓存获取
            if use_cache:
                cached = self.redis_cache.get_cache(cache_key)
                if cached:
                    logger.debug(f"从缓存获取连板统计: {cache_key}")
                    return cached
            
            # 获取最近5个交易日
            recent_dates = self._get_recent_trade_dates(trade_date, 5)
            logger.info(f"获取最近5个交易日数据: {recent_dates}")
            
            # 获取每天的涨停数据
            recent_limit_data = []
            for date in recent_dates:
                limit_data = self.get_limit_list(date, 'U', use_cache)
                if limit_data.get('success'):
                    recent_limit_data.append({
                        'trade_date': date,
                        'data': limit_data.get('data', [])
                    })
            
            # 获取今天的涨停数据
            today_limit_data = self.get_limit_list(trade_date, 'U', use_cache)
            
            if not today_limit_data.get('success') or not today_limit_data.get('data'):
                result = {
                    'success': True,
                    'trade_date': trade_date,
                    'stats': {},
                    'top_continuous': []
                }
                self.redis_cache.set_cache(cache_key, result, ttl=3600)
                return result
            
            data = today_limit_data['data']
            
            # 为每只股票计算连板天数
            stocks_with_continuous = []
            for item in data:
                ts_code = item.get('ts_code', '')
                # 计算连板天数
                continuous_days = self._calculate_continuous_limit_days(ts_code, recent_limit_data)
                
                # 添加连板天数字段
                item_with_continuous = item.copy()
                item_with_continuous['limit_times'] = continuous_days
                stocks_with_continuous.append(item_with_continuous)
            
            # 统计各连板数量
            stats = {}
            for item in stocks_with_continuous:
                limit_times = item.get('limit_times', 1)
                if limit_times < 1:
                    limit_times = 1
                key = f"{limit_times}连板"
                stats[key] = stats.get(key, 0) + 1
            
            # 按连板数排序
            sorted_stats = dict(sorted(stats.items(), key=lambda x: int(x[0].replace('连板', '')), reverse=True))
            
            # 获取高连板股票（2连板以上）
            top_continuous = [item for item in stocks_with_continuous if item.get('limit_times', 0) >= 2]
            top_continuous.sort(key=lambda x: x.get('limit_times', 0), reverse=True)
            
            result = {
                'success': True,
                'trade_date': trade_date,
                'total_count': len(data),
                'stats': sorted_stats,
                'top_continuous': top_continuous[:20],  # 取前20只
                'all_up_limit_with_times': stocks_with_continuous,  # 新增：所有涨停股票（包含limit_times）
                'calculation_method': 'self_calculated',  # 标记为自己计算
                'recent_dates': recent_dates,  # 记录使用的日期范围
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
            # 缓存1小时
            self.redis_cache.set_cache(cache_key, result, ttl=3600)
            
            logger.info(f"连板统计完成: {trade_date}, 总数: {len(data)}, 2连板以上: {len(top_continuous)}")
            return result
            
        except Exception as e:
            logger.error(f"获取连板统计失败: {e}")
            return {
                'success': False,
                'message': str(e),
                'trade_date': trade_date,
                'stats': {},
                'top_continuous': []
            }
    
    # ==================== 4. 板块统计 ====================
    
    def get_sector_stats(
        self,
        trade_date: Optional[str] = None,
        use_cache: bool = True
    ) -> List[Dict[str, Any]]:
        """
        获取板块统计数据（基于涨停股票的行业分布）
        
        Args:
            trade_date: 交易日期
            use_cache: 是否使用缓存
            
        Returns:
            板块统计列表，按涨停数量排序
        """
        try:
            if trade_date is None:
                trade_date = self._get_last_trade_date()
            
            # 获取涨停数据
            limit_data = self.get_limit_list(trade_date, 'U', use_cache)
            
            if not limit_data.get('success') or not limit_data.get('data'):
                return []
            
            data = limit_data['data']
            
            # 获取股票行业信息
            sector_map = self._get_stock_industry()
            
            # 按行业分组统计
            sector_dict = {}
            for item in data:
                ts_code = item.get('ts_code', '')
                industry = sector_map.get(ts_code, '其他')
                
                if industry not in sector_dict:
                    sector_dict[industry] = {
                        'sector_name': industry,
                        'count': 0,
                        'total_pct_chg': 0,
                        'high_continuous_count': 0,
                        'stocks': []
                    }
                
                sector_dict[industry]['count'] += 1
                sector_dict[industry]['total_pct_chg'] += item.get('pct_chg', 0)
                sector_dict[industry]['stocks'].append({
                    **item,
                    'industry': industry
                })
                
                # 统计高连板（3连板以上）
                if item.get('limit_times', 0) >= 3:
                    sector_dict[industry]['high_continuous_count'] += 1
            
            # 计算平均涨幅并排序
            sector_stats = []
            for sector_name, stats in sector_dict.items():
                count = stats['count']
                avg_pct_chg = stats['total_pct_chg'] / count if count > 0 else 0
                
                sector_stats.append({
                    'sector_name': sector_name,
                    'count': count,
                    'avg_pct_chg': round(avg_pct_chg, 2),
                    'high_continuous_count': stats['high_continuous_count'],
                    'stocks': stats['stocks']
                })
            
            # 按涨停数量排序
            sector_stats.sort(key=lambda x: (x['count'], x['high_continuous_count']), reverse=True)
            
            logger.info(f"板块统计完成: {trade_date}, 共{len(sector_stats)}个板块")
            return sector_stats
            
        except Exception as e:
            logger.error(f"获取板块统计失败: {e}")
            return []
    
    # ==================== 5. 游资每日明细 ====================
    
    def get_hot_money_detail(
        self,
        trade_date: Optional[str] = None,
        ts_code: Optional[str] = None,
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """
        获取每日游资交易明细
        
        Args:
            trade_date: 交易日期，格式YYYYMMDD
            ts_code: 股票代码（可选）
            use_cache: 是否使用缓存
            
        Returns:
            游资交易明细数据
        """
        try:
            if trade_date is None:
                trade_date = self._get_last_trade_date()
            
            cache_key = f"hot_money_detail:{trade_date}:{ts_code or 'all'}"
            
            # 尝试从缓存获取
            if use_cache:
                cached = self.redis_cache.get_cache(cache_key)
                if cached:
                    logger.debug(f"从缓存获取游资明细: {cache_key}")
                    return cached
            
            # 等待频率限制
            self.rate_limiter.wait_if_needed()
            self.rate_limiter._record_call()
            
            # 调用hm_detail接口（需要10000积分）
            try:
                params = {'trade_date': trade_date}
                if ts_code:
                    params['ts_code'] = ts_code
                
                df = self.pro.hm_detail(**params)
                
                if df is None or df.empty:
                    logger.warning(f"游资明细数据为空: {trade_date}")
                    return {
                        'success': True,
                        'trade_date': trade_date,
                        'count': 0,
                        'data': []
                    }
                
                # 转换为字典列表
                data = df.to_dict('records')
                
                # 按买入金额降序排序
                data.sort(key=lambda x: x.get('buy_value', 0), reverse=True)
                
                result = {
                    'success': True,
                    'trade_date': trade_date,
                    'count': len(data),
                    'data': data
                }
                
                # 缓存结果（当日数据缓存1小时）
                self.redis_cache.set_cache(cache_key, result, ttl=3600)
                
                logger.info(f"获取游资明细成功: {trade_date}, {len(data)}条")
                return result
                
            except Exception as e:
                error_msg = str(e)
                if "权限" in error_msg or "积分" in error_msg or "10000" in error_msg:
                    logger.warning(f"hm_detail接口需要10000积分，返回空数据")
                    return {
                        'success': False,
                        'message': '游资明细接口需要10000积分权限',
                        'trade_date': trade_date,
                        'count': 0,
                        'data': []
                    }
                raise
                
        except Exception as e:
            logger.error(f"获取游资明细失败: {e}")
            return {
                'success': False,
                'message': str(e),
                'trade_date': trade_date,
                'count': 0,
                'data': []
            }
    
    # ==================== 6. 打板综合数据 ====================
    
    def get_limit_board_summary(
        self,
        trade_date: Optional[str] = None,
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """
        获取打板综合数据（涨停、跌停、龙虎榜、连板统计）
        
        Args:
            trade_date: 交易日期
            use_cache: 是否使用缓存
            
        Returns:
            打板综合数据
        """
        try:
            if trade_date is None:
                trade_date = self._get_last_trade_date()
            
            cache_key = f"limit_board_summary:{trade_date}"
            
            # 尝试从缓存获取
            if use_cache:
                cached = self.redis_cache.get_cache(cache_key)
                if cached:
                    logger.debug(f"从缓存获取打板综合数据: {cache_key}")
                    return cached
            
            # 获取各项数据
            down_limit = self.get_limit_list(trade_date, 'D', use_cache)
            top_list = self.get_top_list(trade_date, use_cache)
            continuous_stats = self.get_continuous_limit_stats(trade_date, use_cache)
            sector_stats = self.get_sector_stats(trade_date, use_cache)
            
            # 从 continuous_stats 中获取带有 limit_times 的完整涨停数据
            up_limit_with_times = continuous_stats.get('all_up_limit_with_times', [])
            
            # 如果 continuous_stats 没有返回完整数据，则使用原始方法
            if not up_limit_with_times:
                up_limit = self.get_limit_list(trade_date, 'U', use_cache)
                up_limit_with_times = up_limit.get('data', [])
            
            # 按连板天数排序（连板数高的排前面，同连板数按涨幅排序）
            up_limit_sorted = sorted(
                up_limit_with_times,
                key=lambda x: (x.get('limit_times', 0), x.get('pct_chg', 0)),
                reverse=True
            )
            
            result = {
                'success': True,
                'trade_date': trade_date,
                'summary': {
                    'up_limit_count': len(up_limit_with_times),
                    'down_limit_count': down_limit.get('count', 0),
                    'top_list_count': top_list.get('count', 0),
                    'continuous_stats': continuous_stats.get('stats', {}),
                },
                'up_limit': up_limit_sorted,  # 所有涨停股票（按连板数排序，包含limit_times）
                'down_limit': down_limit.get('data', [])[:10],  # 跌停前10只
                'top_list': top_list.get('data', [])[:20],  # 龙虎榜前20只
                'top_continuous': continuous_stats.get('top_continuous', []),  # 高连板股票
                'sector_stats': sector_stats[:10],  # 最强板块前10个
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
            # 缓存结果
            self.redis_cache.set_cache(cache_key, result, ttl=3600)
            
            logger.info(f"获取打板综合数据成功: {trade_date}")
            return result
            
        except Exception as e:
            logger.error(f"获取打板综合数据失败: {e}")
            return {
                'success': False,
                'message': str(e),
                'trade_date': trade_date
            }
    
    # ==================== 辅助方法 ====================
    
    def _get_last_trade_date(self) -> str:
        """获取最近交易日"""
        today = datetime.now()
        
        # 如果是周末，回退到周五
        weekday = today.weekday()
        if weekday == 5:  # 周六
            today = today - timedelta(days=1)
        elif weekday == 6:  # 周日
            today = today - timedelta(days=2)
        
        # 如果当前时间早于15:30，使用前一天
        if today.hour < 15 or (today.hour == 15 and today.minute < 30):
            today = today - timedelta(days=1)
            # 再次检查周末
            weekday = today.weekday()
            if weekday == 5:
                today = today - timedelta(days=1)
            elif weekday == 6:
                today = today - timedelta(days=2)
        
        return today.strftime('%Y%m%d')
    
    def _get_stock_basic(self) -> Dict[str, str]:
        """获取股票基本信息（代码-名称映射）"""
        cache_key = "stock_basic_names"
        
        cached = self.redis_cache.get_cache(cache_key)
        if cached:
            return cached
        
        try:
            self.rate_limiter.wait_if_needed()
            self.rate_limiter._record_call()
            
            df = self.pro.stock_basic(
                exchange='',
                list_status='L',
                fields='ts_code,name'
            )
            
            if df is not None and not df.empty:
                result = dict(zip(df['ts_code'], df['name']))
                self.redis_cache.set_cache(cache_key, result, ttl=86400)  # 24小时
                return result
        except Exception as e:
            logger.error(f"获取股票基本信息失败: {e}")
        
        return {}
    
    def _get_stock_industry(self) -> Dict[str, str]:
        """获取股票行业信息（代码-行业映射）"""
        cache_key = "stock_industry_map"
        
        cached = self.redis_cache.get_cache(cache_key)
        if cached:
            return cached
        
        try:
            self.rate_limiter.wait_if_needed()
            self.rate_limiter._record_call()
            
            # 获取股票基本信息，包含行业
            df = self.pro.stock_basic(
                exchange='',
                list_status='L',
                fields='ts_code,name,industry'
            )
            
            if df is not None and not df.empty:
                # 创建代码-行业映射
                result = {}
                for _, row in df.iterrows():
                    ts_code = row['ts_code']
                    industry = row['industry'] if pd.notna(row['industry']) else '其他'
                    result[ts_code] = industry
                
                self.redis_cache.set_cache(cache_key, result, ttl=86400)  # 24小时
                logger.info(f"获取股票行业信息成功: {len(result)}只股票")
                return result
        except Exception as e:
            logger.error(f"获取股票行业信息失败: {e}")
        
        return {}
    
    # ==================== 异步方法 ====================
    
    async def async_get_hot_money_detail(
        self,
        trade_date: Optional[str] = None,
        ts_code: Optional[str] = None,
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """异步获取游资每日明细"""
        import concurrent.futures
        
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            result = await loop.run_in_executor(
                executor,
                lambda: self.get_hot_money_detail(trade_date, ts_code, use_cache)
            )
        return result
    
    async def async_get_limit_list(
        self,
        trade_date: Optional[str] = None,
        limit_type: str = 'U',
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """异步获取涨跌停数据"""
        import concurrent.futures
        
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            result = await loop.run_in_executor(
                executor,
                lambda: self.get_limit_list(trade_date, limit_type, use_cache)
            )
        return result
    
    async def async_get_top_list(
        self,
        trade_date: Optional[str] = None,
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """异步获取龙虎榜数据"""
        import concurrent.futures
        
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            result = await loop.run_in_executor(
                executor,
                lambda: self.get_top_list(trade_date, use_cache)
            )
        return result
    
    async def async_get_limit_board_summary(
        self,
        trade_date: Optional[str] = None,
        use_cache: bool = True
    ) -> Dict[str, Any]:
        """异步获取打板综合数据"""
        import concurrent.futures
        
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            result = await loop.run_in_executor(
                executor,
                lambda: self.get_limit_board_summary(trade_date, use_cache)
            )
        return result


# 全局单例
limit_board_service = LimitBoardService()

