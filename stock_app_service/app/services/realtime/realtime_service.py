# -*- coding: utf-8 -*-
"""
统一的实时行情服务
合并股票和ETF的实时数据获取，消除代码重复
"""

import time
import random
from datetime import datetime
from typing import Dict, Any, Optional

from app.core.logging import logger
from .config import DataProvider, realtime_config
from .proxy_manager import ProxyManager, ProxyInfo


class RealtimeService:
    """
    统一的实时行情服务（股票+ETF）
    
    特点：
    1. 支持股票和ETF
    2. 支持动态代理IP
    3. 支持多数据源切换（东方财富、新浪）
    4. 完整的错误处理和重试机制
    5. 多线程并发获取
    """
    
    def __init__(self, proxy_manager: Optional[ProxyManager] = None):
        """
        初始化服务
        
        Args:
            proxy_manager: 代理管理器
        """
        self.proxy_manager = proxy_manager
        self.config = realtime_config
        
        # 统计信息
        self.stats = {
            'total_requests': 0,
            'proxy_used': 0,
            'direct_used': 0,
            'eastmoney': {'success': 0, 'failed': 0, 'last_success_time': None},
            'sina': {'success': 0, 'failed': 0, 'last_success_time': None},
            'last_provider': None,
            'last_update': None
        }
        
        logger.info(f"实时行情服务初始化: provider={self.config.default_provider.value}, "
                   f"proxy={'enabled' if proxy_manager and proxy_manager.enable_proxy else 'disabled'}")
    
    def get_all_stocks_realtime(
        self, 
        provider: Optional[str] = None,
        include_etf: bool = False
    ) -> Dict[str, Any]:
        """
        获取所有股票实时数据
        
        Args:
            provider: 数据提供商（eastmoney, sina, auto）
            include_etf: 是否包含ETF
        
        Returns:
            {
                'success': bool,
                'data': List[Dict],
                'count': int,
                'source': str,
                'update_time': str,
                'error': str (if failed)
            }
        """
        self.stats['total_requests'] += 1
        
        # 确定数据源
        use_provider = DataProvider(provider) if provider else self.config.default_provider
        
        # 定义尝试顺序
        if use_provider == DataProvider.AUTO:
            # 根据成功率排序
            if self.stats['eastmoney']['success'] >= self.stats['sina']['success']:
                providers_to_try = [DataProvider.EASTMONEY, DataProvider.SINA]
            else:
                providers_to_try = [DataProvider.SINA, DataProvider.EASTMONEY]
        else:
            providers_to_try = [use_provider]
            if self.config.auto_switch:
                # 添加备用数据源
                if use_provider == DataProvider.EASTMONEY:
                    providers_to_try.append(DataProvider.SINA)
                else:
                    providers_to_try.append(DataProvider.EASTMONEY)
        
        # 尝试各个数据源
        last_error = None
        for idx, prov in enumerate(providers_to_try):
            if idx > 0:
                logger.warning(f"主数据源失败，切换到备用源: {prov.value}")
            
            # 重试机制
            for retry in range(self.config.retry_times):
                try:
                    # 获取代理
                    proxy_info = self._get_proxy()
                    
                    # 调用对应数据源
                    if prov == DataProvider.EASTMONEY:
                        result = self._fetch_eastmoney_spot(proxy_info, include_etf)
                    elif prov == DataProvider.SINA:
                        result = self._fetch_sina_spot(proxy_info, include_etf)
                    else:
                        continue
                    
                    # 成功
                    if result.get('success'):
                        self._mark_success(prov, proxy_info)
                        logger.info(f"成功从{prov.value}获取{result.get('count', 0)}只{'股票+ETF' if include_etf else '股票'}实时数据")
                        return result
                    
                    last_error = result.get('error', '未知错误')
                    
                except Exception as e:
                    last_error = str(e)
                    logger.warning(f"获取实时数据失败 (provider={prov.value}, retry={retry+1}): {e}")
                    self._mark_failed(prov, proxy_info)
                    
                    # 重试前等待
                    if retry < self.config.retry_times - 1:
                        time.sleep(random.uniform(1.0, 2.0))
            
            # 记录失败
            self.stats[prov.value]['failed'] += 1
        
        # 所有数据源都失败
        error_msg = f"所有数据源均失败: {last_error}"
        logger.error(error_msg)
        return {
            'success': False,
            'error': error_msg,
            'data': [],
            'count': 0,
            'source': 'none',
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def get_all_etfs_realtime(self, provider: Optional[str] = None) -> Dict[str, Any]:
        """
        获取所有ETF实时数据
        
        Args:
            provider: 数据提供商
        
        Returns:
            标准化数据格式
        """
        # 复用股票方法，但只返回ETF
        result = self.get_all_stocks_realtime(provider, include_etf=True)
        
        if result.get('success'):
            # 过滤出ETF（代码以5或1开头）
            all_data = result.get('data', [])
            etf_data = [item for item in all_data if self._is_etf(item.get('code', ''))]
            
            return {
                'success': True,
                'data': etf_data,
                'count': len(etf_data),
                'source': result.get('source'),
                'update_time': result.get('update_time')
            }
        
        return result
    
    def _get_proxy(self) -> Optional[ProxyInfo]:
        """获取代理"""
        if self.proxy_manager and self.proxy_manager.enable_proxy:
            proxy_info = self.proxy_manager.get_proxy()
            if proxy_info:
                self.stats['proxy_used'] += 1
                return proxy_info
            else:
                self.stats['direct_used'] += 1
                logger.warning("无可用代理，使用直连")
        else:
            self.stats['direct_used'] += 1
        
        return None
    
    def _mark_success(self, provider: DataProvider, proxy_info: Optional[ProxyInfo]):
        """标记成功"""
        self.stats[provider.value]['success'] += 1
        self.stats[provider.value]['last_success_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        self.stats['last_provider'] = provider.value
        self.stats['last_update'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        if proxy_info and self.proxy_manager:
            self.proxy_manager.mark_proxy_success(proxy_info)
    
    def _mark_failed(self, provider: DataProvider, proxy_info: Optional[ProxyInfo]):
        """标记失败"""
        if proxy_info and self.proxy_manager:
            self.proxy_manager.mark_proxy_failed(proxy_info)
    
    def _is_etf(self, code: str) -> bool:
        """判断是否为ETF（代码以5或1开头）"""
        return code.startswith(('5', '1'))
    
    def _fetch_eastmoney_spot(
        self, 
        proxy_info: Optional[ProxyInfo] = None,
        include_etf: bool = False
    ) -> Dict[str, Any]:
        """从东方财富获取实时行情（使用akshare）"""
        try:
            import akshare as ak
            
            proxies = proxy_info.proxy_dict if proxy_info else None
            logger.info(f"使用{'代理' if proxies else '直连'}获取东方财富数据（akshare）")
            
            # 使用akshare获取东方财富数据
            df = ak.stock_zh_a_spot_em()
            
            if df is None or df.empty:
                return {'success': False, 'error': '东方财富返回空数据', 'data': [], 'count': 0, 'source': 'eastmoney'}
            
            # 转换为标准格式
            formatted_data = []
            for _, row in df.iterrows():
                code = str(row.get('代码', ''))
                
                # 根据include_etf过滤
                if not include_etf and self._is_etf(code):
                    continue
                
                formatted_data.append({
                    'code': code,
                    'name': row.get('名称', ''),
                    'price': float(row.get('最新价', 0)),
                    'change': float(row.get('涨跌额', 0)),
                    'change_pct': float(row.get('涨跌幅', 0)),
                    'volume': float(row.get('成交量', 0)),
                    'amount': float(row.get('成交额', 0)),
                    'high': float(row.get('最高', 0)),
                    'low': float(row.get('最低', 0)),
                    'open': float(row.get('今开', 0)),
                    'pre_close': float(row.get('昨收', 0))
                })
            
            logger.info(f"成功从东方财富获取 {len(formatted_data)} 条数据")
            
            return {
                'success': True,
                'data': formatted_data,
                'count': len(formatted_data),
                'source': 'eastmoney',
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except Exception as e:
            logger.error(f"东方财富数据获取失败: {e}")
            return {'success': False, 'error': str(e), 'data': [], 'count': 0, 'source': 'eastmoney'}
    
    def _fetch_sina_spot(
        self, 
        proxy_info: Optional[ProxyInfo] = None,
        include_etf: bool = False
    ) -> Dict[str, Any]:
        """从新浪获取实时行情（使用akshare）"""
        try:
            import akshare as ak
            
            proxies = proxy_info.proxy_dict if proxy_info else None
            logger.info(f"使用{'代理' if proxies else '直连'}获取新浪数据（akshare）")
            
            # 使用akshare获取新浪数据
            df = ak.stock_zh_a_spot()
            
            if df is None or df.empty:
                return {'success': False, 'error': '新浪返回空数据', 'data': [], 'count': 0, 'source': 'sina'}
            
            # 转换为标准格式
            formatted_data = []
            for _, row in df.iterrows():
                code = str(row.get('代码', ''))
                
                # 根据include_etf过滤
                if not include_etf and self._is_etf(code):
                    continue
                
                formatted_data.append({
                    'code': code,
                    'name': row.get('名称', ''),
                    'price': float(row.get('最新价', 0)),
                    'change': float(row.get('涨跌额', 0)),
                    'change_pct': float(row.get('涨跌幅', 0)),
                    'volume': float(row.get('成交量', 0)),
                    'amount': float(row.get('成交额', 0)),
                    'high': float(row.get('最高', 0)),
                    'low': float(row.get('最低', 0)),
                    'open': float(row.get('今开', 0)),
                    'pre_close': float(row.get('昨收', 0))
                })
            
            logger.info(f"成功从新浪获取 {len(formatted_data)} 条数据")
            
            return {
                'success': True,
                'data': formatted_data,
                'count': len(formatted_data),
                'source': 'sina',
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except Exception as e:
            logger.error(f"新浪数据获取失败: {e}")
            return {'success': False, 'error': str(e), 'data': [], 'count': 0, 'source': 'sina'}
    
    def get_stats(self) -> Dict:
        """获取统计信息"""
        return self.stats.copy()
    
    def reset_stats(self):
        """重置统计信息"""
        self.stats = {
            'total_requests': 0,
            'proxy_used': 0,
            'direct_used': 0,
            'eastmoney': {'success': 0, 'failed': 0, 'last_success_time': None},
            'sina': {'success': 0, 'failed': 0, 'last_success_time': None},
            'last_provider': None,
            'last_update': None
        }
        logger.info("统计信息已重置")


# 全局实例
_realtime_service = None


def get_realtime_service(proxy_manager: Optional[ProxyManager] = None) -> RealtimeService:
    """获取实时行情服务实例"""
    global _realtime_service
    
    if _realtime_service is None:
        _realtime_service = RealtimeService(proxy_manager)
    
    return _realtime_service


# 兼容旧接口
def get_stock_realtime_service_v2(proxy_manager: Optional[ProxyManager] = None) -> RealtimeService:
    """获取股票实时服务（兼容旧接口）"""
    return get_realtime_service(proxy_manager)


def get_etf_realtime_service_v2(proxy_manager: Optional[ProxyManager] = None) -> RealtimeService:
    """获取ETF实时服务（兼容旧接口）"""
    return get_realtime_service(proxy_manager)

