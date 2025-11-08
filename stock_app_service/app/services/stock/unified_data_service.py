# -*- coding: utf-8 -*-
"""
统一数据服务
封装股票和ETF的历史数据和实时数据获取方法
"""

import asyncio
import json
import time
import threading
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import pandas as pd

from app.core.logging import logger
from app.core.config import settings
from app.db.session import RedisCache


class TushareRateLimiter:
    """
    Tushare API频率限制器（滑动窗口算法）
    
    Tushare限制：500次/分钟
    设置：450次/分钟（留50次余量，避免触发限制）
    
    工作原理：
    1. 维护一个60秒的滑动窗口
    2. 记录每次API调用的时间戳
    3. 自动清理60秒前的旧记录
    4. 如果窗口内调用次数 >= 450次，等待最早的调用过期
    """
    
    def __init__(self, max_calls_per_minute=450):
        self.call_times = []
        self.max_calls_per_minute = max_calls_per_minute  # Tushare实际500次/分，设置450留余量
        self.lock = threading.Lock()
    
    def _record_call(self):
        """记录API调用"""
        with self.lock:
            current_time = time.time()
            self.call_times.append(current_time)
            # 清理过期记录（60秒前的）
            cutoff_time = current_time - 60
            self.call_times = [t for t in self.call_times if t > cutoff_time]
    
    def wait_if_needed(self):
        """
        如果需要，等待频率限制解除（滑动窗口）
        
        不是等待60秒，而是等待最早的调用过期（滑出窗口）
        """
        with self.lock:
            current_time = time.time()
            cutoff_time = current_time - 60
            # 清理60秒前的旧记录
            self.call_times = [t for t in self.call_times if t > cutoff_time]
            
            # 如果窗口内调用次数达到限制
            if len(self.call_times) >= self.max_calls_per_minute:
                # 计算需要等待的时间：等待最早的调用滑出60秒窗口
                oldest_call = min(self.call_times)
                elapsed = current_time - oldest_call  # 最早调用已经过去的时间
                wait_seconds = max(1.0, 60 - elapsed + 0.5)  # 等待它滑出窗口，加0.5秒余量
                
                logger.warning(
                    f"触发Tushare频率限制（{len(self.call_times)}/{self.max_calls_per_minute}次/分钟），"
                    f"等待 {wait_seconds:.1f} 秒（滑动窗口）..."
                )
                time.sleep(wait_seconds)
                
                # 等待后清理过期记录
                current_time = time.time()
                cutoff_time = current_time - 60
                old_count = len(self.call_times)
                self.call_times = [t for t in self.call_times if t > cutoff_time]
                new_count = len(self.call_times)
                
                logger.info(f"频率限制解除，窗口内调用: {old_count} → {new_count}，继续数据获取...")


# 全局频率限制器实例（确保所有服务共享同一个限制器）
_global_rate_limiter = None

def get_rate_limiter():
    """
    获取全局频率限制器
    
    Tushare限制：500次/分钟
    设置：450次/分钟（留50次余量）
    """
    global _global_rate_limiter
    if _global_rate_limiter is None:
        _global_rate_limiter = TushareRateLimiter(max_calls_per_minute=450)
        logger.info("初始化全局Tushare频率限制器: 450次/分钟（Tushare实际500次/分钟，留50次余量）")
    return _global_rate_limiter


class UnifiedDataService:
    """统一数据服务类 - 处理股票和ETF"""
    
    def __init__(self):
        self.redis_cache = RedisCache()
        # 统一的Redis键规则（股票和ETF使用相同格式）
        self.kline_key_template = 'stock_trend:{}'  # ts_code
        # 使用全局共享的频率限制器
        self.rate_limiter = get_rate_limiter()
    
    # ==================== 1. 统一的历史数据获取方法 ====================
    
    def fetch_historical_data(
        self,
        ts_code: str,
        days: int = 180,
        is_etf: bool = False,
        retry_on_limit: bool = True
    ) -> List[Dict[str, Any]]:
        """
        统一的历史数据获取方法（股票+ETF）
        
        Args:
            ts_code: 股票/ETF代码，如 000001.SZ 或 510050.SH
            days: 获取天数
            is_etf: 是否为ETF（用于选择数据源）
            retry_on_limit: 触发频率限制时是否自动重试
            
        Returns:
            K线数据列表
        """
        try:
            import tushare as ts
            
            # 直接传入token，避免读取文件导致 "No columns to parse from file" 错误
            pro = ts.pro_api(settings.TUSHARE_TOKEN)
            
            # 等待频率限制（如果需要）
            self.rate_limiter.wait_if_needed()
            
            # 计算日期范围（扩大2倍以确保获取足够的交易日数据）
            end_date = datetime.now().strftime('%Y%m%d')
            start_date = (datetime.now() - timedelta(days=days * 2)).strftime('%Y%m%d')
            
            # 记录API调用
            self.rate_limiter._record_call()
            
            # 获取日线数据（股票和ETF使用相同的接口）
            df = pro.daily(
                ts_code=ts_code,
                start_date=start_date,
                end_date=end_date
            )
            
            if df is None or df.empty:
                logger.warning(f"{'ETF' if is_etf else '股票'} {ts_code} 历史数据为空")
                return []
            
            # 按日期排序并取最近的指定天数
            df = df.sort_values('trade_date').tail(days)
            
            # 转换为字典列表，并确保字段格式统一
            kline_data = []
            for _, row in df.iterrows():
                # Tushare返回的字段：ts_code, trade_date, open, high, low, close, pre_close, change, pct_chg, vol, amount
                kline_item = {
                    'ts_code': str(row.get('ts_code', ts_code)),
                    'trade_date': str(row.get('trade_date', '')),  # 格式：20241108
                    'open': float(row.get('open', 0)) if pd.notna(row.get('open')) else 0.0,
                    'high': float(row.get('high', 0)) if pd.notna(row.get('high')) else 0.0,
                    'low': float(row.get('low', 0)) if pd.notna(row.get('low')) else 0.0,
                    'close': float(row.get('close', 0)) if pd.notna(row.get('close')) else 0.0,
                    'pre_close': float(row.get('pre_close', 0)) if pd.notna(row.get('pre_close')) else 0.0,
                    'change': float(row.get('change', 0)) if pd.notna(row.get('change')) else 0.0,
                    'pct_chg': float(row.get('pct_chg', 0)) if pd.notna(row.get('pct_chg')) else 0.0,
                    'vol': float(row.get('vol', 0)) if pd.notna(row.get('vol')) else 0.0,  # 成交量（手）
                    'amount': float(row.get('amount', 0)) if pd.notna(row.get('amount')) else 0.0,  # 成交额（千元）
                }
                kline_data.append(kline_item)
            
            # 不输出每条成功日志，由批次汇总统计
            # logger.info(f"成功获取 {'ETF' if is_etf else '股票'} {ts_code} 历史数据 {len(kline_data)} 条")
            
            return kline_data
            
        except Exception as e:
            error_msg = str(e)
            logger.error(f"获取 {'ETF' if is_etf else '股票'} {ts_code} 历史数据失败: {e}")
            
            # 检查是否是频率限制错误
            if retry_on_limit and ("每分钟最多访问" in error_msg or "500次" in error_msg):
                logger.warning(f"{ts_code} 触发频率限制，等待后重试...")
                # 强制等待并重试
                time.sleep(5)  # 等待5秒
                return self.fetch_historical_data(ts_code, days, is_etf, retry_on_limit=False)
            
            return []
    
    async def async_fetch_historical_data(
        self,
        ts_code: str,
        days: int = 180,
        is_etf: bool = False
    ) -> List[Dict[str, Any]]:
        """
        异步版本的历史数据获取
        
        在线程池中执行同步的Tushare调用
        """
        import concurrent.futures
        
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            kline_data = await loop.run_in_executor(
                executor,
                self.fetch_historical_data,
                ts_code,
                days,
                is_etf
            )
        
        return kline_data
    
    # ==================== 2. 统一的实时数据获取方法 ====================
    
    def fetch_stock_realtime_data(self) -> Optional[pd.DataFrame]:
        """
        获取所有股票的实时数据
        使用akshare的新浪接口（已验证有效）
        
        Returns:
            包含所有股票实时数据的DataFrame
        """
        try:
            import akshare as ak
            
            logger.info("开始获取股票实时数据...")
            df = ak.stock_zh_a_spot()
            
            if df is not None and not df.empty:
                # 添加获取时间和数据来源
                df['update_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                df['data_source'] = 'sina'
                
                logger.info(f"成功获取 {len(df)} 只股票的实时数据")
                return df
            else:
                logger.warning("获取的股票实时数据为空")
                return None
                
        except Exception as e:
            logger.error(f"获取股票实时数据失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return None
    
    def fetch_etf_realtime_data(self) -> Optional[pd.DataFrame]:
        """
        获取所有ETF的实时数据
        使用新浪接口（通过akshare封装）
        
        Returns:
            包含所有ETF实时数据的DataFrame
        """
        try:
            import akshare as ak
            
            logger.info("开始获取ETF实时数据...")
            
            # 使用新浪ETF实时数据接口
            try:
                logger.info("使用新浪接口获取ETF数据...")
                df = ak.fund_etf_category_sina(symbol="ETF基金")
                
                if df is not None and not df.empty:
                    # 添加获取时间和数据来源
                    df['update_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    df['data_source'] = 'sina'
                    
                    logger.info(f"成功获取 {len(df)} 只ETF的实时数据")
                    return df
                else:
                    logger.warning("新浪接口返回空数据")
                    return None
            except Exception as e:
                logger.error(f"新浪接口获取ETF实时数据失败: {e}")
            
            logger.warning("获取ETF实时数据失败")
            return None
                
        except Exception as e:
            logger.error(f"获取ETF实时数据失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return None
    
    def fetch_all_realtime_data(self) -> Dict[str, Any]:
        """
        获取所有股票和ETF的实时数据
        
        Returns:
            包含股票和ETF实时数据的字典
        """
        result = {
            'success': False,
            'stock_data': None,
            'etf_data': None,
            'stock_count': 0,
            'etf_count': 0,
            'total_count': 0,
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
        # 获取股票实时数据
        stock_df = self.fetch_stock_realtime_data()
        if stock_df is not None:
            result['stock_data'] = stock_df
            result['stock_count'] = len(stock_df)
        
        # 获取ETF实时数据
        etf_df = self.fetch_etf_realtime_data()
        if etf_df is not None:
            result['etf_data'] = etf_df
            result['etf_count'] = len(etf_df)
        
        result['total_count'] = result['stock_count'] + result['etf_count']
        result['success'] = result['total_count'] > 0
        
        return result
    
    async def async_fetch_all_realtime_data(self) -> Dict[str, Any]:
        """
        异步版本：获取所有股票和ETF的实时数据
        
        在线程池中执行同步调用
        """
        import concurrent.futures
        
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            result = await loop.run_in_executor(
                executor,
                self.fetch_all_realtime_data
            )
        
        return result
    
    # ==================== 3. 实时数据更新到历史K线 ====================
    
    def update_kline_with_realtime(
        self,
        ts_code: str,
        realtime_data: Dict[str, Any],
        is_etf: bool = False
    ) -> bool:
        """
        用实时数据更新历史K线数据（当日有则更新，无则新增）
        
        Args:
            ts_code: 股票/ETF代码
            realtime_data: 实时数据字典
            is_etf: 是否为ETF
            
        Returns:
            是否更新成功
        """
        try:
            # 1. 获取现有K线数据
            key = self.kline_key_template.format(ts_code)
            cached_data = self.redis_cache.get_cache(key)
            
            if not cached_data:
                logger.warning(f"{'ETF' if is_etf else '股票'} {ts_code} 没有历史K线数据，跳过实时更新")
                return False
            
            # 2. 解析K线数据
            if isinstance(cached_data, dict):
                kline_list = cached_data.get('data', [])
            elif isinstance(cached_data, list):
                kline_list = cached_data
            else:
                logger.error(f"{'ETF' if is_etf else '股票'} {ts_code} K线数据格式错误")
                return False
            
            if not kline_list:
                logger.warning(f"{'ETF' if is_etf else '股票'} {ts_code} K线数据为空")
                return False
            
            # 3. 构造今日K线数据（格式与Tushare历史数据完全一致）
            today = datetime.now().strftime('%Y%m%d')
            
            # 从实时数据中提取字段（兼容不同的字段名）
            # 确保字段名和格式与Tushare历史数据完全一致
            current_price = float(realtime_data.get('最新价', realtime_data.get('price', realtime_data.get('close', 0))))
            open_price = float(realtime_data.get('今开', realtime_data.get('open', current_price)))
            
            # 获取昨收价，用于计算change
            pre_close = float(realtime_data.get('昨收', realtime_data.get('pre_close', current_price)))
            
            # 计算涨跌额
            change = current_price - pre_close if pre_close > 0 else 0.0
            
            # 获取涨跌幅（百分比）
            pct_chg = float(realtime_data.get('涨跌幅', realtime_data.get('change_percent', 0)))
            
            new_kline = {
                'ts_code': ts_code,
                'trade_date': today,  # 格式：20241108，与Tushare一致
                'open': open_price,
                'high': float(realtime_data.get('最高', realtime_data.get('high', current_price))),
                'low': float(realtime_data.get('最低', realtime_data.get('low', current_price))),
                'close': current_price,
                'pre_close': pre_close,
                'change': change,
                'pct_chg': pct_chg,
                'vol': float(realtime_data.get('成交量', realtime_data.get('volume', 0))),  # 成交量（手）
                'amount': float(realtime_data.get('成交额', realtime_data.get('amount', 0))),  # 成交额（千元）
            }
            
            # 4. 检查是否已有今日数据
            last_kline = kline_list[-1]
            last_trade_date = str(last_kline.get('trade_date', ''))
            
            if last_trade_date == today:
                # 更新今日数据
                kline_list[-1] = new_kline
                logger.debug(f"更新 {'ETF' if is_etf else '股票'} {ts_code} 今日K线数据")
            else:
                # 新增今日数据
                kline_list.append(new_kline)
                logger.debug(f"新增 {'ETF' if is_etf else '股票'} {ts_code} 今日K线数据")
            
            # 5. 保持最近180天的数据
            if len(kline_list) > 180:
                kline_list = kline_list[-180:]
            
            # 6. 更新到Redis
            cache_data = {
                'data': kline_list,
                'updated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'data_count': len(kline_list),
                'source': 'realtime_update',
                'last_update_type': 'realtime'
            }
            
            self.redis_cache.set_cache(key, cache_data, ttl=86400 * 30)  # 30天
            
            return True
            
        except Exception as e:
            logger.error(f"更新 {'ETF' if is_etf else '股票'} {ts_code} K线数据失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False
    
    def batch_update_klines_with_realtime(
        self,
        stock_df: Optional[pd.DataFrame],
        etf_df: Optional[pd.DataFrame]
    ) -> Dict[str, Any]:
        """
        批量更新K线数据
        
        Args:
            stock_df: 股票实时数据DataFrame
            etf_df: ETF实时数据DataFrame
            
        Returns:
            更新结果统计
        """
        result = {
            'stock_updated': 0,
            'stock_failed': 0,
            'etf_updated': 0,
            'etf_failed': 0,
            'total_updated': 0,
            'total_failed': 0
        }
        
        # 更新股票
        if stock_df is not None and not stock_df.empty:
            logger.info(f"开始更新 {len(stock_df)} 只股票的K线数据...")
            
            for _, row in stock_df.iterrows():
                try:
                    # 构造ts_code
                    code = str(row.get('代码', row.get('code', '')))
                    if not code:
                        continue
                    
                    # 根据代码前缀判断市场
                    if code.startswith('6'):
                        ts_code = f"{code}.SH"
                    elif code.startswith(('0', '3')):
                        ts_code = f"{code}.SZ"
                    elif code.startswith(('43', '83', '87', '88')):
                        ts_code = f"{code}.BJ"
                    else:
                        continue
                    
                    # 转换为字典
                    realtime_data = row.to_dict()
                    
                    # 更新K线
                    if self.update_kline_with_realtime(ts_code, realtime_data, is_etf=False):
                        result['stock_updated'] += 1
                    else:
                        result['stock_failed'] += 1
                        
                except Exception as e:
                    logger.error(f"更新股票 {code} 失败: {e}")
                    result['stock_failed'] += 1
        
        # 更新ETF
        if etf_df is not None and not etf_df.empty:
            logger.info(f"开始更新 {len(etf_df)} 只ETF的K线数据...")
            
            for _, row in etf_df.iterrows():
                try:
                    # 构造ts_code
                    code = str(row.get('代码', row.get('code', '')))
                    if not code:
                        continue
                    
                    # ETF通常是6位数字
                    if len(code) == 6:
                        # 根据代码前缀判断市场
                        if code.startswith('5'):
                            ts_code = f"{code}.SH"
                        elif code.startswith('1'):
                            ts_code = f"{code}.SZ"
                        else:
                            # 尝试两个市场
                            ts_code = f"{code}.SH"
                    else:
                        continue
                    
                    # 转换为字典
                    realtime_data = row.to_dict()
                    
                    # 更新K线
                    if self.update_kline_with_realtime(ts_code, realtime_data, is_etf=True):
                        result['etf_updated'] += 1
                    else:
                        result['etf_failed'] += 1
                        
                except Exception as e:
                    logger.error(f"更新ETF {code} 失败: {e}")
                    result['etf_failed'] += 1
        
        result['total_updated'] = result['stock_updated'] + result['etf_updated']
        result['total_failed'] = result['stock_failed'] + result['etf_failed']
        
        logger.info(
            f"K线数据更新完成: "
            f"股票({result['stock_updated']}/{result['stock_updated']+result['stock_failed']}), "
            f"ETF({result['etf_updated']}/{result['etf_updated']+result['etf_failed']}), "
            f"总计({result['total_updated']}/{result['total_updated']+result['total_failed']})"
        )
        
        return result
    
    async def async_batch_update_klines_with_realtime(
        self,
        stock_df: Optional[pd.DataFrame],
        etf_df: Optional[pd.DataFrame]
    ) -> Dict[str, Any]:
        """
        异步版本：批量更新K线数据
        
        在线程池中执行同步调用
        """
        import concurrent.futures
        
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            result = await loop.run_in_executor(
                executor,
                self.batch_update_klines_with_realtime,
                stock_df,
                etf_df
            )
        
        return result


# 全局单例
unified_data_service = UnifiedDataService()



# 导出频率限制器，供其他模块使用
__all__ = ['UnifiedDataService', 'unified_data_service', 'get_rate_limiter', 'TushareRateLimiter']

