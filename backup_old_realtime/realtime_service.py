# -*- coding: utf-8 -*-
"""
统一实时行情服务
支持多个数据源（东方财富、新浪）自动切换
"""

import akshare as ak
import pandas as pd
from datetime import datetime
from typing import Dict, Any, List, Optional, Literal
from enum import Enum
import time
import random

from app.core.logging import logger
from app.core.config import settings


class DataProvider(str, Enum):
    """数据提供商枚举"""
    EASTMONEY = "eastmoney"  # 东方财富
    SINA = "sina"  # 新浪财经
    AUTO = "auto"  # 自动选择


class RealtimeStockService:
    """
    实时行情服务类
    
    功能：
    1. 支持多个数据源（东方财富、新浪）
    2. 自动切换数据源（某个失败时自动尝试另一个）
    3. 统一的数据格式返回
    4. 支持单只股票和批量获取
    5. 智能防封机制（请求间隔控制、错误重试）
    """
    
    def __init__(
        self, 
        default_provider: str = None,
        auto_switch: bool = None,
        retry_times: int = 2,
        min_request_interval: float = 1.0  # 最小请求间隔（秒）
    ):
        """
        初始化实时行情服务
        
        Args:
            default_provider: 默认数据提供商（eastmoney, sina, auto）
            auto_switch: 是否启用自动切换
            retry_times: 每个数据源重试次数
            min_request_interval: 最小请求间隔（秒），防止请求过于频繁
        """
        self.default_provider = default_provider or settings.REALTIME_DATA_PROVIDER
        self.auto_switch = auto_switch if auto_switch is not None else settings.REALTIME_AUTO_SWITCH
        self.retry_times = retry_times
        self.min_request_interval = min_request_interval
        
        # 统计信息
        self.stats = {
            'eastmoney_success': 0,
            'eastmoney_fail': 0,
            'sina_success': 0,
            'sina_fail': 0,
            'last_provider': None,
            'last_update': None,
            'last_request_time': None  # 记录上次请求时间
        }
        
    def get_all_stocks_realtime(self, provider: str = None) -> Dict[str, Any]:
        """
        获取所有A股实时行情数据
        
        Args:
            provider: 指定数据提供商，如果为None则使用默认配置
            
        Returns:
            {
                'success': True/False,
                'data': [...],  # 股票数据列表
                'count': int,  # 股票数量
                'source': str,  # 数据来源
                'update_time': str,  # 更新时间
                'error': str  # 错误信息（如果失败）
            }
        """
        use_provider = provider or self.default_provider
        
        # 定义尝试顺序
        providers_to_try = []
        if use_provider == DataProvider.AUTO:
            # auto模式：根据历史成功率决定顺序
            if self.stats['eastmoney_success'] >= self.stats['sina_success']:
                providers_to_try = [DataProvider.EASTMONEY, DataProvider.SINA]
            else:
                providers_to_try = [DataProvider.SINA, DataProvider.EASTMONEY]
        elif use_provider == DataProvider.EASTMONEY:
            providers_to_try = [DataProvider.EASTMONEY]
            if self.auto_switch:
                providers_to_try.append(DataProvider.SINA)
        elif use_provider == DataProvider.SINA:
            providers_to_try = [DataProvider.SINA]
            if self.auto_switch:
                providers_to_try.append(DataProvider.EASTMONEY)
        else:
            # 默认尝试东方财富
            providers_to_try = [DataProvider.EASTMONEY, DataProvider.SINA]
        
        # 防封机制：检查并控制请求频率
        self._rate_limit_control()
        
        # 依次尝试各个数据源
        last_error = None
        for data_provider in providers_to_try:
            for attempt in range(self.retry_times):
                try:
                    logger.info(f"尝试从 {data_provider} 获取实时行情数据（第{attempt+1}次尝试）...")
                    
                    if data_provider == DataProvider.EASTMONEY:
                        result = self._fetch_eastmoney_spot()
                    elif data_provider == DataProvider.SINA:
                        result = self._fetch_sina_spot()
                    else:
                        continue
                    
                    if result and result.get('success'):
                        # 更新统计信息
                        self.stats[f'{data_provider}_success'] += 1
                        self.stats['last_provider'] = data_provider
                        self.stats['last_update'] = datetime.now().isoformat()
                        self.stats['last_request_time'] = time.time()
                        
                        logger.info(f"成功从 {data_provider} 获取 {result.get('count', 0)} 只股票实时数据")
                        return result
                    
                except Exception as e:
                    last_error = str(e)
                    logger.warning(f"从 {data_provider} 获取实时数据失败（第{attempt+1}次）: {last_error}")
                    
                    # 更新失败统计
                    self.stats[f'{data_provider}_fail'] += 1
                    
                    # 如果不是最后一次尝试，使用随机延迟避免规律性
                    if attempt < self.retry_times - 1:
                        delay = random.uniform(1.5, 3.0)  # 随机延迟1.5-3秒
                        logger.debug(f"等待 {delay:.1f} 秒后重试...")
                        time.sleep(delay)
        
        # 所有数据源都失败
        error_msg = f"所有数据源均获取失败，最后错误: {last_error}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg,
            'data': [],
            'count': 0,
            'source': 'none',
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def _fetch_eastmoney_spot(self) -> Dict[str, Any]:
        """
        从东方财富获取实时行情
        
        Returns:
            标准化的数据格式
        """
        # 获取实时行情数据
        df = ak.stock_zh_a_spot_em()
        
        if df.empty:
            return {
                'success': False,
                'error': '东方财富返回空数据',
                'data': [],
                'count': 0,
                'source': 'eastmoney'
            }
        
        # 转换数据格式
        realtime_data = []
        for _, row in df.iterrows():
            try:
                stock_data = {
                    'code': str(row.get('代码', '')),
                    'name': str(row.get('名称', '')),
                    'price': float(row.get('最新价', 0)) if pd.notna(row.get('最新价')) else 0.0,
                    'change': float(row.get('涨跌额', 0)) if pd.notna(row.get('涨跌额')) else 0.0,
                    'change_percent': float(row.get('涨跌幅', 0)) if pd.notna(row.get('涨跌幅')) else 0.0,
                    'volume': float(row.get('成交量', 0)) if pd.notna(row.get('成交量')) else 0.0,
                    'amount': float(row.get('成交额', 0)) if pd.notna(row.get('成交额')) else 0.0,
                    'high': float(row.get('最高', 0)) if pd.notna(row.get('最高')) else 0.0,
                    'low': float(row.get('最低', 0)) if pd.notna(row.get('最低')) else 0.0,
                    'open': float(row.get('今开', 0)) if pd.notna(row.get('今开')) else 0.0,
                    'pre_close': float(row.get('昨收', 0)) if pd.notna(row.get('昨收')) else 0.0,
                    'buy': float(row.get('买入', 0)) if pd.notna(row.get('买入')) else 0.0,
                    'sell': float(row.get('卖出', 0)) if pd.notna(row.get('卖出')) else 0.0,
                    'turnover_rate': float(row.get('换手率', 0)) if pd.notna(row.get('换手率')) else 0.0,
                    'timestamp': str(row.get('时间戳', '')) if pd.notna(row.get('时间戳')) else '',
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
                realtime_data.append(stock_data)
            except Exception as e:
                logger.warning(f"解析东方财富数据行失败: {e}, row: {row.to_dict()}")
                continue
        
        return {
            'success': True,
            'data': realtime_data,
            'count': len(realtime_data),
            'source': 'eastmoney',
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def _fetch_sina_spot(self) -> Dict[str, Any]:
        """
        从新浪财经获取实时行情
        使用 akshare 的 stock_zh_a_spot 接口
        
        Returns:
            标准化的数据格式
        """
        # 获取实时行情数据
        df = ak.stock_zh_a_spot()
        
        if df.empty:
            return {
                'success': False,
                'error': '新浪财经返回空数据',
                'data': [],
                'count': 0,
                'source': 'sina'
            }
        
        # 转换数据格式 - 新浪接口字段
        realtime_data = []
        for _, row in df.iterrows():
            try:
                # 新浪接口的代码格式可能是 "sh600000" 或 "bj430047" 等
                raw_code = str(row.get('代码', ''))
                
                # 清理代码格式：去除前缀（sh、sz、bj等）
                code = raw_code
                if raw_code.startswith('sh'):
                    code = raw_code[2:]  # 去除 "sh" 前缀
                elif raw_code.startswith('sz'):
                    code = raw_code[2:]  # 去除 "sz" 前缀
                elif raw_code.startswith('bj'):
                    code = raw_code[2:]  # 去除 "bj" 前缀
                
                # 确保代码是6位数字
                if not code or len(code) != 6 or not code.isdigit():
                    logger.debug(f"跳过无效股票代码: {raw_code} -> {code}")
                    continue
                
                # 新浪接口的字段名
                stock_data = {
                    'code': code,  # 使用清理后的6位代码
                    'name': str(row.get('名称', '')),
                    'price': float(row.get('最新价', 0)) if pd.notna(row.get('最新价')) else 0.0,
                    'change': float(row.get('涨跌额', 0)) if pd.notna(row.get('涨跌额')) else 0.0,
                    'change_percent': float(row.get('涨跌幅', 0)) if pd.notna(row.get('涨跌幅')) else 0.0,
                    'volume': float(row.get('成交量', 0)) if pd.notna(row.get('成交量')) else 0.0,
                    'amount': float(row.get('成交额', 0)) if pd.notna(row.get('成交额')) else 0.0,
                    'high': float(row.get('最高', 0)) if pd.notna(row.get('最高')) else 0.0,
                    'low': float(row.get('最低', 0)) if pd.notna(row.get('最低')) else 0.0,
                    'open': float(row.get('今开', 0)) if pd.notna(row.get('今开')) else 0.0,
                    'pre_close': float(row.get('昨收', 0)) if pd.notna(row.get('昨收')) else 0.0,
                    'buy': float(row.get('买入', 0)) if pd.notna(row.get('买入')) else 0.0,
                    'sell': float(row.get('卖出', 0)) if pd.notna(row.get('卖出')) else 0.0,
                    'turnover_rate': 0.0,  # 新浪接口可能不提供换手率
                    'timestamp': str(row.get('时间戳', '')) if pd.notna(row.get('时间戳')) else '',
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
                realtime_data.append(stock_data)
            except Exception as e:
                logger.warning(f"解析新浪财经数据行失败: {e}, row: {row.to_dict()}")
                continue
        
        return {
            'success': True,
            'data': realtime_data,
            'count': len(realtime_data),
            'source': 'sina',
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def get_single_stock_realtime(self, stock_code: str, provider: str = None) -> Dict[str, Any]:
        """
        获取单只股票的实时数据
        
        Args:
            stock_code: 股票代码（6位数字）
            provider: 指定数据提供商
            
        Returns:
            {
                'success': True/False,
                'data': {...},  # 股票数据
                'source': str,  # 数据来源
                'error': str  # 错误信息（如果失败）
            }
        """
        # 先获取全量数据（有缓存的情况下效率更高）
        result = self.get_all_stocks_realtime(provider)
        
        if not result.get('success'):
            return {
                'success': False,
                'error': result.get('error', '获取实时数据失败'),
                'data': None,
                'source': result.get('source', 'unknown')
            }
        
        # 从全量数据中查找指定股票
        all_data = result.get('data', [])
        for stock_data in all_data:
            if stock_data.get('code') == stock_code:
                return {
                    'success': True,
                    'data': stock_data,
                    'source': result.get('source'),
                    'update_time': stock_data.get('update_time')
                }
        
        # 未找到指定股票
        return {
            'success': False,
            'error': f'未找到股票 {stock_code} 的实时数据',
            'data': None,
            'source': result.get('source')
        }
    
    def get_stats(self) -> Dict[str, Any]:
        """
        获取服务统计信息
        
        Returns:
            统计数据字典
        """
        total_requests = sum([
            self.stats['eastmoney_success'],
            self.stats['eastmoney_fail'],
            self.stats['sina_success'],
            self.stats['sina_fail']
        ])
        
        return {
            'total_requests': total_requests,
            'eastmoney': {
                'success': self.stats['eastmoney_success'],
                'fail': self.stats['eastmoney_fail'],
                'success_rate': (
                    self.stats['eastmoney_success'] / 
                    max(self.stats['eastmoney_success'] + self.stats['eastmoney_fail'], 1) * 100
                )
            },
            'sina': {
                'success': self.stats['sina_success'],
                'fail': self.stats['sina_fail'],
                'success_rate': (
                    self.stats['sina_success'] / 
                    max(self.stats['sina_success'] + self.stats['sina_fail'], 1) * 100
                )
            },
            'last_provider': self.stats['last_provider'],
            'last_update': self.stats['last_update'],
            'config': {
                'default_provider': self.default_provider,
                'auto_switch': self.auto_switch,
                'retry_times': self.retry_times
            }
        }
    
    def reset_stats(self):
        """重置统计信息"""
        last_request_time = self.stats.get('last_request_time')  # 保留请求时间用于频率控制
        self.stats = {
            'eastmoney_success': 0,
            'eastmoney_fail': 0,
            'sina_success': 0,
            'sina_fail': 0,
            'last_provider': None,
            'last_update': None,
            'last_request_time': last_request_time
        }
        logger.info("实时行情服务统计信息已重置")
    
    def _rate_limit_control(self):
        """
        请求频率控制（防封机制）
        
        确保两次请求之间有足够的时间间隔，避免请求过于频繁被封IP
        """
        if self.stats.get('last_request_time'):
            elapsed = time.time() - self.stats['last_request_time']
            if elapsed < self.min_request_interval:
                wait_time = self.min_request_interval - elapsed
                # 添加随机扰动，避免请求过于规律
                wait_time += random.uniform(0.1, 0.3)
                logger.debug(f"频率控制：等待 {wait_time:.2f} 秒...")
                time.sleep(wait_time)


# 全局实时行情服务实例
_realtime_service_instance = None


def get_realtime_service() -> RealtimeStockService:
    """
    获取实时行情服务单例
    
    Returns:
        RealtimeStockService实例
    """
    global _realtime_service_instance
    if _realtime_service_instance is None:
        _realtime_service_instance = RealtimeStockService()
        logger.info("创建实时行情服务实例")
    return _realtime_service_instance


# 便捷函数
def get_all_stocks_realtime(provider: str = None) -> Dict[str, Any]:
    """获取所有A股实时行情（便捷函数）"""
    service = get_realtime_service()
    return service.get_all_stocks_realtime(provider)


def get_single_stock_realtime(stock_code: str, provider: str = None) -> Dict[str, Any]:
    """获取单只股票实时数据（便捷函数）"""
    service = get_realtime_service()
    return service.get_single_stock_realtime(stock_code, provider)


def get_realtime_stats() -> Dict[str, Any]:
    """获取实时行情服务统计信息（便捷函数）"""
    service = get_realtime_service()
    return service.get_stats()

