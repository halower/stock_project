# -*- coding: utf-8 -*-
"""
ETF实时行情服务
支持多数据源、自动切换、防封策略
"""

import time
import random
from datetime import datetime
from typing import Dict, Any, List, Optional
from enum import Enum
import pandas as pd

from app.core.logging import logger

try:
    import akshare as ak
except ImportError:
    logger.warning("akshare未安装，ETF实时行情功能将不可用")
    ak = None


class ETFDataProvider(Enum):
    """ETF数据源枚举"""
    EASTMONEY = "eastmoney"  # 东方财富
    SINA = "sina"            # 新浪财经
    AUTO = "auto"            # 自动选择


class ETFRealtimeService:
    """
    ETF实时行情服务
    
    特点：
    1. 支持多数据源（东方财富、新浪）
    2. 自动切换和故障转移
    3. 防封策略（限流、随机延迟）
    4. 统一的数据格式输出
    """
    
    def __init__(
        self,
        default_provider: str = "eastmoney",
        auto_switch: bool = True,
        retry_times: int = 2,
        min_request_interval: float = 3.0
    ):
        """
        初始化ETF实时行情服务
        
        Args:
            default_provider: 默认数据源 (eastmoney/sina/auto)
            auto_switch: 是否自动切换数据源
            retry_times: 失败重试次数
            min_request_interval: 最小请求间隔（秒）
        """
        self.default_provider = ETFDataProvider(default_provider)
        self.auto_switch = auto_switch
        self.retry_times = retry_times
        self.min_request_interval = min_request_interval
        
        # 统计信息
        self.stats = {
            'eastmoney': {'success': 0, 'fail': 0, 'last_success_time': None},
            'sina': {'success': 0, 'fail': 0, 'last_success_time': None},
            'total_requests': 0,
            'auto_switches': 0
        }
        
        # 上次请求时间（用于限流）
        self._last_request_time = 0
        
        logger.info(f"ETF实时行情服务初始化: provider={default_provider}, auto_switch={auto_switch}")
    
    def get_all_etfs_realtime(self, provider: Optional[str] = None) -> Dict[str, Any]:
        """
        获取所有ETF的实时行情
        
        Args:
            provider: 指定数据源，None则使用默认配置
            
        Returns:
            {
                'success': bool,
                'data': List[Dict],  # ETF列表
                'count': int,
                'source': str,
                'error': str (if failed)
            }
        """
        self.stats['total_requests'] += 1
        
        # 确定使用的数据源
        if provider:
            try:
                target_provider = ETFDataProvider(provider)
            except ValueError:
                return {
                    'success': False,
                    'error': f'不支持的数据源: {provider}',
                    'data': [],
                    'count': 0
                }
        else:
            target_provider = self.default_provider
        
        # AUTO模式：按优先级尝试
        if target_provider == ETFDataProvider.AUTO:
            providers_to_try = [ETFDataProvider.EASTMONEY, ETFDataProvider.SINA]
        else:
            providers_to_try = [target_provider]
        
        # 如果启用自动切换，添加备用数据源
        if self.auto_switch and len(providers_to_try) == 1:
            if target_provider == ETFDataProvider.EASTMONEY:
                providers_to_try.append(ETFDataProvider.SINA)
            elif target_provider == ETFDataProvider.SINA:
                providers_to_try.append(ETFDataProvider.EASTMONEY)
        
        # 尝试各个数据源
        last_error = None
        for idx, prov in enumerate(providers_to_try):
            # 如果是自动切换到备用源，记录日志
            if idx > 0:
                self.stats['auto_switches'] += 1
                logger.warning(f"主数据源失败，切换到备用源: {prov.value}")
            
            # 重试机制
            for retry in range(self.retry_times):
                try:
                    # 限流控制
                    self._rate_limit_control()
                    
                    # 调用对应的数据源
                    if prov == ETFDataProvider.EASTMONEY:
                        result = self._fetch_eastmoney_etf()
                    elif prov == ETFDataProvider.SINA:
                        result = self._fetch_sina_etf()
                    else:
                        continue
                    
                    # 成功
                    if result.get('success'):
                        self.stats[prov.value]['success'] += 1
                        self.stats[prov.value]['last_success_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                        logger.info(f"成功从 {prov.value} 获取 {result.get('count', 0)} 只ETF实时数据")
                        return result
                    
                    last_error = result.get('error', '未知错误')
                    
                except Exception as e:
                    last_error = str(e)
                    logger.warning(f"获取ETF数据失败 (provider={prov.value}, retry={retry+1}): {e}")
                    
                    # 重试前等待（随机延迟，防止被封）
                    if retry < self.retry_times - 1:
                        delay = random.uniform(1.0, 3.0)
                        time.sleep(delay)
            
            # 记录失败
            self.stats[prov.value]['fail'] += 1
        
        # 所有数据源都失败
        error_msg = f"所有数据源均失败，最后错误: {last_error}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg,
            'data': [],
            'count': 0,
            'source': 'none'
        }
    
    def get_single_etf_realtime(self, etf_code: str, provider: Optional[str] = None) -> Dict[str, Any]:
        """
        获取单只ETF的实时行情
        
        Args:
            etf_code: ETF代码（6位数字）
            provider: 指定数据源
            
        Returns:
            {
                'success': bool,
                'data': Dict,  # ETF数据
                'source': str,
                'error': str (if failed)
            }
        """
        # 获取所有ETF数据
        result = self.get_all_etfs_realtime(provider)
        
        if not result.get('success'):
            return result
        
        # 查找指定ETF
        all_etfs = result.get('data', [])
        for etf in all_etfs:
            if etf.get('code') == etf_code:
                return {
                    'success': True,
                    'data': etf,
                    'source': result.get('source')
                }
        
        return {
            'success': False,
            'error': f'未找到ETF: {etf_code}',
            'data': {},
            'source': result.get('source')
        }
    
    def _fetch_eastmoney_etf(self) -> Dict[str, Any]:
        """
        从东方财富获取ETF实时行情
        使用 akshare 的 fund_etf_spot_em 接口
        
        Returns:
            标准化的数据格式
        """
        if not ak:
            return {
                'success': False,
                'error': 'akshare未安装',
                'data': [],
                'count': 0,
                'source': 'eastmoney'
            }
        
        # 获取实时行情数据
        df = ak.fund_etf_spot_em()
        
        if df.empty:
            return {
                'success': False,
                'error': '东方财富返回空数据',
                'data': [],
                'count': 0,
                'source': 'eastmoney'
            }
        
        # 转换数据格式
        etf_data = []
        for _, row in df.iterrows():
            try:
                # 东方财富接口的字段名（中文）
                etf_item = {
                    'code': str(row.get('代码', '')),
                    'name': str(row.get('名称', '')),
                    'price': float(row.get('最新价', 0)) if pd.notna(row.get('最新价')) else 0.0,
                    'change': float(row.get('涨跌额', 0)) if pd.notna(row.get('涨跌额')) else 0.0,
                    'change_percent': float(row.get('涨跌幅', 0)) if pd.notna(row.get('涨跌幅')) else 0.0,
                    'volume': float(row.get('成交量', 0)) if pd.notna(row.get('成交量')) else 0.0,
                    'amount': float(row.get('成交额', 0)) if pd.notna(row.get('成交额')) else 0.0,
                    'open': float(row.get('开盘价', 0)) if pd.notna(row.get('开盘价')) else 0.0,
                    'high': float(row.get('最高价', 0)) if pd.notna(row.get('最高价')) else 0.0,
                    'low': float(row.get('最低价', 0)) if pd.notna(row.get('最低价')) else 0.0,
                    'pre_close': float(row.get('昨收', 0)) if pd.notna(row.get('昨收')) else 0.0,
                    'turnover_rate': float(row.get('换手率', 0)) if pd.notna(row.get('换手率')) else 0.0,
                    'iopv': float(row.get('IOPV实时估值', 0)) if pd.notna(row.get('IOPV实时估值')) else 0.0,
                    'discount_rate': float(row.get('基金折价率', 0)) if pd.notna(row.get('基金折价率')) else 0.0,
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
                
                # 验证代码有效性
                if etf_item['code'] and len(etf_item['code']) == 6 and etf_item['code'].isdigit():
                    etf_data.append(etf_item)
                    
            except Exception as e:
                logger.warning(f"解析东方财富ETF数据行失败: {e}, row: {row.to_dict()}")
                continue
        
        return {
            'success': True,
            'data': etf_data,
            'count': len(etf_data),
            'source': 'eastmoney',
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def _fetch_sina_etf(self) -> Dict[str, Any]:
        """
        从新浪财经获取ETF实时行情
        使用 akshare 的 fund_etf_category_sina 接口
        
        Returns:
            标准化的数据格式
        """
        if not ak:
            return {
                'success': False,
                'error': 'akshare未安装',
                'data': [],
                'count': 0,
                'source': 'sina'
            }
        
        # 获取ETF基金实时行情（新浪只有一个分类）
        df = ak.fund_etf_category_sina(symbol="ETF基金")
        
        if df.empty:
            return {
                'success': False,
                'error': '新浪财经返回空数据',
                'data': [],
                'count': 0,
                'source': 'sina'
            }
        
        # 转换数据格式
        etf_data = []
        for _, row in df.iterrows():
            try:
                # 新浪接口的代码格式可能是 "sz159949" 或 "sh510050" 等
                raw_code = str(row.get('代码', '')).strip().lower()
                
                # 清理代码格式：去除前缀（sh、sz等）
                code = raw_code
                if raw_code.startswith('sh'):
                    code = raw_code[2:]
                elif raw_code.startswith('sz'):
                    code = raw_code[2:]
                elif raw_code.startswith('bj'):
                    code = raw_code[2:]
                
                # 确保代码是6位数字
                if not code or len(code) != 6 or not code.isdigit():
                    logger.debug(f"跳过无效ETF代码: {raw_code} -> {code}")
                    continue
                
                logger.debug(f"新浪ETF代码转换: {row.get('代码', '')} -> {code}")
                
                # 新浪接口的字段名
                etf_item = {
                    'code': code,  # 使用清理后的6位代码
                    'name': str(row.get('名称', '')),
                    'price': float(row.get('最新价', 0)) if pd.notna(row.get('最新价')) else 0.0,
                    'change': float(row.get('涨跌额', 0)) if pd.notna(row.get('涨跌额')) else 0.0,
                    'change_percent': float(row.get('涨跌幅', 0)) if pd.notna(row.get('涨跌幅')) else 0.0,
                    'volume': float(row.get('成交量', 0)) if pd.notna(row.get('成交量')) else 0.0,
                    'amount': float(row.get('成交额', 0)) if pd.notna(row.get('成交额')) else 0.0,
                    'open': float(row.get('今开', 0)) if pd.notna(row.get('今开')) else 0.0,
                    'high': float(row.get('最高', 0)) if pd.notna(row.get('最高')) else 0.0,
                    'low': float(row.get('最低', 0)) if pd.notna(row.get('最低')) else 0.0,
                    'pre_close': float(row.get('昨收', 0)) if pd.notna(row.get('昨收')) else 0.0,
                    'turnover_rate': 0.0,  # 新浪接口不提供换手率
                    'iopv': 0.0,  # 新浪接口不提供IOPV
                    'discount_rate': 0.0,  # 新浪接口不提供折价率
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                }
                etf_data.append(etf_item)
                
            except Exception as e:
                logger.warning(f"解析新浪财经ETF数据行失败: {e}, row: {row.to_dict()}")
                continue
        
        logger.info(f"新浪财经ETF数据解析完成: 共 {len(etf_data)} 只")
        if len(etf_data) > 0:
            # 显示前3个ETF代码供调试
            sample_codes = [etf['code'] for etf in etf_data[:3]]
            logger.info(f"新浪ETF示例代码: {sample_codes}")
        
        return {
            'success': True,
            'data': etf_data,
            'count': len(etf_data),
            'source': 'sina',
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def _rate_limit_control(self):
        """
        限流控制：确保两次请求之间有最小间隔
        """
        current_time = time.time()
        elapsed = current_time - self._last_request_time
        
        if elapsed < self.min_request_interval:
            # 需要等待
            sleep_time = self.min_request_interval - elapsed
            # 添加随机扰动，避免规律性请求
            sleep_time += random.uniform(0, 0.5)
            logger.debug(f"限流控制: 等待 {sleep_time:.2f} 秒")
            time.sleep(sleep_time)
        
        self._last_request_time = time.time()
    
    def get_config(self) -> Dict[str, Any]:
        """获取当前配置"""
        return {
            'default_provider': self.default_provider.value,
            'auto_switch': self.auto_switch,
            'retry_times': self.retry_times,
            'min_request_interval': self.min_request_interval
        }
    
    def update_config(
        self,
        default_provider: Optional[str] = None,
        auto_switch: Optional[bool] = None,
        retry_times: Optional[int] = None,
        min_request_interval: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        更新配置
        
        Returns:
            更新后的配置
        """
        if default_provider is not None:
            try:
                self.default_provider = ETFDataProvider(default_provider)
                logger.info(f"ETF数据源已更新: {default_provider}")
            except ValueError:
                logger.warning(f"无效的数据源: {default_provider}")
        
        if auto_switch is not None:
            self.auto_switch = auto_switch
            logger.info(f"ETF自动切换已{'启用' if auto_switch else '禁用'}")
        
        if retry_times is not None:
            self.retry_times = max(1, retry_times)
            logger.info(f"ETF重试次数已更新: {self.retry_times}")
        
        if min_request_interval is not None:
            self.min_request_interval = max(0.5, min_request_interval)
            logger.info(f"ETF请求间隔已更新: {self.min_request_interval}秒")
        
        return self.get_config()
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        return self.stats.copy()
    
    def reset_stats(self):
        """重置统计信息"""
        for provider in ['eastmoney', 'sina']:
            self.stats[provider] = {'success': 0, 'fail': 0, 'last_success_time': None}
        self.stats['total_requests'] = 0
        self.stats['auto_switches'] = 0
        logger.info("ETF实时行情服务统计信息已重置")


# 全局单例
_etf_realtime_service: Optional[ETFRealtimeService] = None


def get_etf_realtime_service() -> ETFRealtimeService:
    """
    获取ETF实时行情服务单例
    
    配置从环境变量读取（如果有的话）
    """
    global _etf_realtime_service
    
    if _etf_realtime_service is None:
        import os
        
        default_provider = os.getenv("ETF_REALTIME_PROVIDER", "eastmoney")
        auto_switch = os.getenv("ETF_AUTO_SWITCH", "true").lower() in ("true", "1", "yes")
        retry_times = int(os.getenv("ETF_RETRY_TIMES", "2"))
        min_interval = float(os.getenv("ETF_MIN_REQUEST_INTERVAL", "3.0"))
        
        _etf_realtime_service = ETFRealtimeService(
            default_provider=default_provider,
            auto_switch=auto_switch,
            retry_times=retry_times,
            min_request_interval=min_interval
        )
    
    return _etf_realtime_service

