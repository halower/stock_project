# -*- coding: utf-8 -*-
"""
股票实时行情服务V2 - 支持动态代理IP
基于akshare接口，添加代理支持
"""

import requests
import pandas as pd
import time
import random
from datetime import datetime
from typing import Dict, Any, List, Optional
from enum import Enum
from concurrent.futures import ThreadPoolExecutor, as_completed

from app.core.logging import logger
from .proxy_manager import ProxyManager, ProxyInfo


class DataProvider(str, Enum):
    """数据提供商枚举"""
    EASTMONEY = "eastmoney"  # 东方财富
    SINA = "sina"            # 新浪财经
    AUTO = "auto"            # 自动选择


class StockRealtimeServiceV2:
    """
    股票实时行情服务V2
    
    特点：
    1. 支持动态代理IP
    2. 参考akshare源码实现
    3. 支持多数据源切换
    4. 完整的错误处理和重试机制
    """
    
    def __init__(
        self,
        proxy_manager: Optional[ProxyManager] = None,
        default_provider: str = "eastmoney",
        auto_switch: bool = True,
        retry_times: int = 3,
        timeout: int = 10
    ):
        """
        初始化服务
        
        Args:
            proxy_manager: 代理管理器
            default_provider: 默认数据源
            auto_switch: 是否自动切换数据源
            retry_times: 重试次数
            timeout: 请求超时时间（秒）
        """
        self.proxy_manager = proxy_manager
        self.default_provider = DataProvider(default_provider)
        self.auto_switch = auto_switch
        self.retry_times = retry_times
        self.timeout = timeout
        
        # 统计信息
        self.stats = {
            'eastmoney': {'success': 0, 'fail': 0, 'last_success_time': None},
            'sina': {'success': 0, 'fail': 0, 'last_success_time': None},
            'total_requests': 0,
            'proxy_used': 0,
            'direct_used': 0
        }
        
        logger.info(f"股票实时服务V2初始化: provider={default_provider}, proxy={'enabled' if proxy_manager and proxy_manager.enable_proxy else 'disabled'}")
    
    def get_all_stocks_realtime(self, provider: Optional[str] = None) -> Dict[str, Any]:
        """
        获取所有A股实时行情
        
        Args:
            provider: 指定数据源
            
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
        use_provider = DataProvider(provider) if provider else self.default_provider
        
        # 定义尝试顺序
        if use_provider == DataProvider.AUTO:
            # 根据成功率排序
            if self.stats['eastmoney']['success'] >= self.stats['sina']['success']:
                providers_to_try = [DataProvider.EASTMONEY, DataProvider.SINA]
            else:
                providers_to_try = [DataProvider.SINA, DataProvider.EASTMONEY]
        else:
            providers_to_try = [use_provider]
            if self.auto_switch:
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
            for retry in range(self.retry_times):
                proxy_info = None
                try:
                    # 获取代理
                    if self.proxy_manager and self.proxy_manager.enable_proxy:
                        proxy_info = self.proxy_manager.get_proxy()
                        if proxy_info:
                            self.stats['proxy_used'] += 1
                        else:
                            self.stats['direct_used'] += 1
                            logger.warning("无可用代理，使用直连")
                    else:
                        self.stats['direct_used'] += 1
                    
                    # 调用对应数据源
                    if prov == DataProvider.EASTMONEY:
                        result = self._fetch_eastmoney_spot(proxy_info)
                    elif prov == DataProvider.SINA:
                        result = self._fetch_sina_spot(proxy_info)
                    else:
                        continue
                    
                    # 成功
                    if result.get('success'):
                        self.stats[prov.value]['success'] += 1
                        self.stats[prov.value]['last_success_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                        
                        # 标记代理成功
                        if proxy_info and self.proxy_manager:
                            self.proxy_manager.mark_proxy_success(proxy_info)
                        
                        logger.info(f"成功从{prov.value}获取{result.get('count', 0)}只股票实时数据")
                        return result
                    
                    last_error = result.get('error', '未知错误')
                    
                except Exception as e:
                    last_error = str(e)
                    logger.warning(f"获取股票实时数据失败 (provider={prov.value}, retry={retry+1}): {e}")
                    
                    # 标记代理失败，传递错误信息
                    if proxy_info and self.proxy_manager:
                        self.proxy_manager.mark_proxy_failed(proxy_info, error_msg=last_error)
                    
                    # 重试前等待
                    if retry < self.retry_times - 1:
                        delay = random.uniform(1.0, 2.0)
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
            'source': 'none',
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    
    def _fetch_single_page_thread(
        self,
        url: str,
        page_num: int,
        base_time: int,
        proxies: Optional[Dict] = None
    ) -> tuple:
        """在线程中获取单页数据（使用同一个代理）"""
        try:
            params = {
                "pn": str(page_num),
                "pz": "100",
                "po": "1",
                "np": "1",
                "ut": "bd1d9ddb04089700cf9c27f6f7426281",
                "fltt": "2",
                "invt": "2",
                "fid": "f3",
                "fs": "m:0 t:6,m:0 t:80,m:1 t:2,m:1 t:23,m:0 t:81 s:2048",
                "fields": "f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f12,f13,f14,f15,f16,f17,f18,f20,f21,f23,f24,f25,f22,f11,f62,f128,f136,f115,f152",
                "_": str(base_time + page_num)
            }
            
            response = requests.get(
                url,
                params=params,
                proxies=proxies,
                timeout=30,
                headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
            )
            
            if response.status_code != 200:
                return page_num, None, f'HTTP {response.status_code}'
            
            data = response.json()
            if data.get('rc') == 0 and data.get('data') and data['data'].get('diff'):
                return page_num, data['data']['diff'], None
            return page_num, None, '返回空数据'
            
        except Exception as e:
            return page_num, None, str(e)
    
    def _fetch_all_pages_concurrent(
        self,
        url: str,
        total_pages: int,
        proxies: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """使用多线程并发获取所有页面（使用同一个代理）"""
        base_time = int(time.time() * 1000)
        all_data = []
        failed_pages = []
        
        logger.info(f"开始多线程并发获取{total_pages}个页面...")
        
        # 使用线程池并发获取
        with ThreadPoolExecutor(max_workers=20) as executor:
            # 提交所有任务
            future_to_page = {
                executor.submit(self._fetch_single_page_thread, url, page, base_time, proxies): page
                for page in range(1, total_pages + 1)
            }
            
            # 等待所有任务完成
            for future in as_completed(future_to_page):
                page_num = future_to_page[future]
                try:
                    page_num, page_data, error = future.result()
                    if error:
                        failed_pages.append((page_num, error))
                    elif page_data:
                        all_data.extend(page_data)
                except Exception as e:
                    failed_pages.append((page_num, str(e)))
        
        if failed_pages:
            error_msg = f'部分页面失败: {failed_pages[:3]}'  # 只显示前3个错误
            logger.warning(error_msg)
            return {
                'success': False,
                'error': error_msg,
                'data': [],
                'count': 0
            }
        
        logger.info(f"多线程并发获取完成，共{len(all_data)}条数据")
        return {
            'success': True,
            'data': all_data,
            'count': len(all_data)
        }
    
    def _fetch_eastmoney_spot(self, proxy_info: Optional[ProxyInfo] = None) -> Dict[str, Any]:
        """
        从东方财富获取实时行情（内部多线程并发，外部同步接口）
        使用同一个代理IP多线程并发获取所有页面，然后一次性返回所有数据
        
        Args:
            proxy_info: 代理信息
            
        Returns:
            标准化数据格式
        """
        try:
            # 准备代理
            proxies = proxy_info.proxy_dict if proxy_info else None
            
            logger.info(f"使用{'代理' if proxies else '直连'}获取东方财富数据")
            
            # 东方财富API
            url = "http://82.push2.eastmoney.com/api/qt/clist/get"
            
            # 先用同步请求获取总数（快速获取总页数）
            first_params = {
                "pn": "1",
                "pz": "100",
                "po": "1",
                "np": "1",
                "ut": "bd1d9ddb04089700cf9c27f6f7426281",
                "fltt": "2",
                "invt": "2",
                "fid": "f3",
                "fs": "m:0 t:6,m:0 t:80,m:1 t:2,m:1 t:23,m:0 t:81 s:2048",
                "fields": "f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f12,f13,f14,f15,f16,f17,f18,f20,f21,f23,f24,f25,f22,f11,f62,f128,f136,f115,f152",
                "_": str(int(time.time() * 1000))
            }
            
            response = requests.get(url, params=first_params, proxies=proxies, timeout=self.timeout,
                                   headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'})
            
            if response.status_code != 200:
                return {'success': False, 'error': f'HTTP {response.status_code}', 'data': [], 'count': 0, 'source': 'eastmoney'}
            
            data = response.json()
            if data.get('rc') != 0 or not data.get('data'):
                return {'success': False, 'error': '东方财富返回空数据', 'data': [], 'count': 0, 'source': 'eastmoney'}
            
            # 获取总数并计算总页数
            total = data['data'].get('total', 0)
            page_size = 100
            total_pages = (total + page_size - 1) // page_size
            
            logger.info(f"总共{total}条数据，需要多线程并发获取{total_pages}页")
            
            # 使用多线程并发获取（使用同一个代理）
            result = self._fetch_all_pages_concurrent(url, total_pages, proxies)
            
            if not result['success']:
                logger.error(f"多线程并发获取失败: {result['error']}")
                return {
                    'success': False,
                    'error': result['error'],
                    'data': [],
                    'count': 0,
                    'source': 'eastmoney'
                }
            
            all_data = result['data']
            
            if not all_data:
                return {
                    'success': False,
                    'error': '东方财富返回空数据',
                    'data': [],
                    'count': 0,
                    'source': 'eastmoney'
                }
            
            # 转换数据格式
            realtime_data = []
            for item in all_data:
                try:
                    stock_data = {
                        'code': str(item.get('f12', '')),  # 股票代码
                        'name': str(item.get('f14', '')),  # 股票名称
                        'price': float(item.get('f2', 0)),  # 最新价
                        'change': float(item.get('f4', 0)),  # 涨跌额
                        'change_percent': float(item.get('f3', 0)),  # 涨跌幅
                        'volume': float(item.get('f5', 0)),  # 成交量（手）
                        'amount': float(item.get('f6', 0)),  # 成交额（元）
                        'amplitude': float(item.get('f7', 0)),  # 振幅
                        'high': float(item.get('f15', 0)),  # 最高
                        'low': float(item.get('f16', 0)),  # 最低
                        'open': float(item.get('f17', 0)),  # 今开
                        'pre_close': float(item.get('f18', 0)),  # 昨收
                        'volume_ratio': float(item.get('f10', 0)),  # 量比
                        'turnover_rate': float(item.get('f8', 0)),  # 换手率
                        'pe_ratio': float(item.get('f9', 0)),  # 市盈率
                        'pb_ratio': float(item.get('f23', 0)),  # 市净率
                        'total_value': float(item.get('f20', 0)),  # 总市值
                        'circulation_value': float(item.get('f21', 0)),  # 流通市值
                        'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    }
                    realtime_data.append(stock_data)
                except Exception as e:
                    logger.debug(f"解析东方财富数据行失败: {e}")
                    continue
            
            return {
                'success': True,
                'data': realtime_data,
                'count': len(realtime_data),
                'source': 'eastmoney',
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except requests.RequestException as e:
            return {
                'success': False,
                'error': f'网络请求失败: {str(e)}',
                'data': [],
                'count': 0,
                'source': 'eastmoney'
            }
        except Exception as e:
            return {
                'success': False,
                'error': f'数据解析失败: {str(e)}',
                'data': [],
                'count': 0,
                'source': 'eastmoney'
            }
    
    def _fetch_sina_spot(self, proxy_info: Optional[ProxyInfo] = None) -> Dict[str, Any]:
        """
        从新浪财经获取实时行情
        参考akshare的stock_zh_a_spot实现
        
        Args:
            proxy_info: 代理信息
            
        Returns:
            标准化数据格式
        """
        try:
            # 新浪实时行情接口（参考akshare源码）
            url = "http://vip.stock.finance.sina.com.cn/quotes_service/api/json_v2.php/Market_Center.getHQNodeData"
            params = {
                "page": "1",
                "num": "10000",  # 获取所有股票
                "sort": "symbol",
                "asc": "1",
                "node": "hs_a",  # A股
                "symbol": "",
                "_s_r_a": "page"
            }
            
            # 准备代理
            proxies = proxy_info.proxy_dict if proxy_info else None
            
            # 发送请求
            response = requests.get(
                url,
                params=params,
                proxies=proxies,
                timeout=self.timeout,
                headers={
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
            )
            
            if response.status_code != 200:
                return {
                    'success': False,
                    'error': f'HTTP {response.status_code}',
                    'data': [],
                    'count': 0,
                    'source': 'sina'
                }
            
            # 新浪返回的是JSON数组
            data = response.json()
            
            if not data or not isinstance(data, list):
                return {
                    'success': False,
                    'error': '新浪财经返回空数据',
                    'data': [],
                    'count': 0,
                    'source': 'sina'
                }
            
            # 转换数据格式
            realtime_data = []
            for item in data:
                try:
                    # 清理代码格式
                    raw_code = str(item.get('symbol', ''))
                    code = raw_code.replace('sh', '').replace('sz', '').replace('bj', '')
                    
                    stock_data = {
                        'code': code,
                        'name': str(item.get('name', '')),
                        'price': float(item.get('trade', 0)),  # 最新价
                        'change': float(item.get('pricechange', 0)),  # 涨跌额
                        'change_percent': float(item.get('changepercent', 0)),  # 涨跌幅
                        'volume': float(item.get('volume', 0)),  # 成交量
                        'amount': float(item.get('amount', 0)),  # 成交额
                        'high': float(item.get('high', 0)),  # 最高
                        'low': float(item.get('low', 0)),  # 最低
                        'open': float(item.get('open', 0)),  # 今开
                        'pre_close': float(item.get('settlement', 0)),  # 昨收
                        'turnover_rate': float(item.get('turnoverratio', 0)),  # 换手率
                        'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    }
                    realtime_data.append(stock_data)
                except Exception as e:
                    logger.debug(f"解析新浪数据行失败: {e}")
                    continue
            
            return {
                'success': True,
                'data': realtime_data,
                'count': len(realtime_data),
                'source': 'sina',
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except requests.RequestException as e:
            return {
                'success': False,
                'error': f'网络请求失败: {str(e)}',
                'data': [],
                'count': 0,
                'source': 'sina'
            }
        except Exception as e:
            return {
                'success': False,
                'error': f'数据解析失败: {str(e)}',
                'data': [],
                'count': 0,
                'source': 'sina'
            }
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        return self.stats.copy()


# 全局单例
_stock_realtime_service_v2: Optional[StockRealtimeServiceV2] = None


def get_stock_realtime_service_v2(
    proxy_manager: Optional[ProxyManager] = None,
    **kwargs
) -> StockRealtimeServiceV2:
    """
    获取股票实时服务V2单例
    
    Args:
        proxy_manager: 代理管理器
        **kwargs: 其他配置参数
    """
    global _stock_realtime_service_v2
    
    if _stock_realtime_service_v2 is None:
        import os
        
        default_provider = os.getenv('REALTIME_PROVIDER', kwargs.get('default_provider', 'eastmoney'))
        auto_switch = os.getenv('REALTIME_AUTO_SWITCH', 'true').lower() in ('true', '1', 'yes')
        retry_times = int(os.getenv('REALTIME_RETRY_TIMES', kwargs.get('retry_times', 3)))
        timeout = int(os.getenv('REALTIME_TIMEOUT', kwargs.get('timeout', 10)))
        
        _stock_realtime_service_v2 = StockRealtimeServiceV2(
            proxy_manager=proxy_manager,
            default_provider=default_provider,
            auto_switch=auto_switch,
            retry_times=retry_times,
            timeout=timeout
        )
    
    return _stock_realtime_service_v2

