# -*- coding: utf-8 -*-
"""
动态代理IP管理器
支持从代理服务商API获取和管理代理IP池
"""

import time
import random
import requests
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from dataclasses import dataclass
from enum import Enum
from app.core.logging import logger


class ProxyStatus(Enum):
    """代理状态"""
    AVAILABLE = "available"  # 可用
    IN_USE = "in_use"        # 使用中
    FAILED = "failed"        # 失败
    EXPIRED = "expired"      # 过期


@dataclass
class ProxyInfo:
    """代理信息"""
    proxy_ip: str           # 真实出口IP
    server: str             # 代理服务器地址（格式：ip:port）
    area: str               # 地区
    isp: str                # 运营商
    deadline: str           # 过期时间
    status: ProxyStatus = ProxyStatus.AVAILABLE
    fail_count: int = 0     # 失败次数
    last_use_time: Optional[datetime] = None
    username: Optional[str] = None  # 代理用户名（如果需要）
    password: Optional[str] = None  # 代理密码（如果需要）
    
    @property
    def is_expired(self) -> bool:
        """检查是否过期"""
        try:
            deadline_time = datetime.strptime(self.deadline, '%Y-%m-%d %H:%M:%S')
            return datetime.now() >= deadline_time
        except Exception:
            return True
    
    @property
    def proxy_dict(self) -> Dict[str, str]:
        """返回requests库使用的代理字典"""
        # 如果有认证信息，添加到代理URL中
        if self.username and self.password:
            proxy_url = f'http://{self.username}:{self.password}@{self.server}'
        else:
            proxy_url = f'http://{self.server}'
        
        return {
            'http': proxy_url,
            'https': proxy_url  # HTTPS也使用HTTP代理协议
        }


class ProxyManager:
    """
    动态代理IP管理器
    
    功能：
    1. 从代理服务商API获取代理IP
    2. 管理代理IP池（自动刷新、过期清理）
    3. 提供可用代理IP
    4. 代理失败统计和自动剔除
    """
    
    def __init__(
        self,
        api_url: str,
        api_key: str,
        auth_password: Optional[str] = None,  # 代理认证密码
        pool_size: int = 1,  # 默认每次只获取1个代理，避免浪费
        refresh_interval: int = 300,  # 5分钟
        max_fail_count: int = 3,
        enable_proxy: bool = True
    ):
        """
        初始化代理管理器
        
        Args:
            api_url: 代理服务API地址
            api_key: API密钥
            auth_password: 代理认证密码（Authpwd）
            pool_size: 代理池大小
            refresh_interval: 刷新间隔（秒）
            max_fail_count: 最大失败次数
            enable_proxy: 是否启用代理
        """
        self.api_url = api_url
        self.api_key = api_key
        self.auth_password = auth_password
        self.pool_size = pool_size
        self.refresh_interval = refresh_interval
        self.max_fail_count = max_fail_count
        self.enable_proxy = enable_proxy
        
        # 代理池
        self.proxy_pool: List[ProxyInfo] = []
        self.last_refresh_time: Optional[datetime] = None
        
        # 统计信息
        self.stats = {
            'total_fetched': 0,      # 总获取数
            'total_used': 0,         # 总使用数
            'total_failed': 0,       # 总失败数
            'current_pool_size': 0,  # 当前池大小
            'last_refresh_time': None
        }
        
        logger.info(f"代理管理器初始化: enable={enable_proxy}, pool_size={pool_size}")
        
        # 如果启用代理，立即获取一批
        if self.enable_proxy:
            self._fetch_proxies()
    
    def _fetch_proxies(self, num: Optional[int] = None) -> List[ProxyInfo]:
        """
        从API获取代理IP
        
        Args:
            num: 获取数量，默认为pool_size
            
        Returns:
            代理信息列表
        """
        if num is None:
            num = self.pool_size
        
        try:
            # 构建请求参数（注意：该API不支持num参数，每次只返回1个代理）
            params = {
                'key': self.api_key,
            }
            
            logger.info(f"正在从代理API获取代理IP...")
            
            # 如果需要多个代理，需要多次调用
            all_proxies = []
            for i in range(num):
                # 发送请求
                response = requests.get(
                    self.api_url,
                    params=params,
                    timeout=10
                )
                
                if response.status_code != 200:
                    logger.error(f"代理API请求失败: HTTP {response.status_code}, {response.text}")
                    continue
                
                data = response.json()
                
                # 检查响应状态
                if data.get('code') != 'SUCCESS':
                    logger.error(f"代理API返回错误: {data.get('code')}, {data.get('message')}")
                    continue
                
                # 解析代理列表
                for item in data.get('data', []):
                    proxy_info = ProxyInfo(
                        proxy_ip=item.get('proxy_ip', ''),
                        server=item.get('server', ''),
                        area=item.get('area', ''),
                        isp=item.get('isp', ''),
                        deadline=item.get('deadline', ''),
                        status=ProxyStatus.AVAILABLE,
                        # 使用统一的认证密码
                        username=self.api_key if self.auth_password else None,
                        password=self.auth_password
                    )
                    all_proxies.append(proxy_info)
                
                # 如果只需要1个，获取到就退出
                if num == 1 and all_proxies:
                    break
            
            logger.info(f"成功获取{len(all_proxies)}个代理IP")
            
            # 更新统计
            self.stats['total_fetched'] += len(all_proxies)
            self.stats['last_refresh_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            return all_proxies
            
        except requests.RequestException as e:
            logger.error(f"代理API请求异常: {e}")
            return []
        except Exception as e:
            logger.error(f"获取代理IP失败: {e}")
            return []
    
    def _clean_expired_proxies(self):
        """清理过期和失败的代理"""
        before_count = len(self.proxy_pool)
        
        # 过滤掉过期和失败次数过多的代理
        self.proxy_pool = [
            proxy for proxy in self.proxy_pool
            if not proxy.is_expired and proxy.fail_count < self.max_fail_count
        ]
        
        cleaned_count = before_count - len(self.proxy_pool)
        if cleaned_count > 0:
            logger.info(f"清理了{cleaned_count}个无效代理")
    
    def _should_refresh(self) -> bool:
        """判断是否需要刷新代理池"""
        # 如果未启用代理，不需要刷新
        if not self.enable_proxy:
            return False
        
        # 如果代理池为空，需要刷新
        if not self.proxy_pool:
            return True
        
        # 如果从未刷新过，需要刷新
        if self.last_refresh_time is None:
            return True
        
        # 如果距离上次刷新超过间隔时间，需要刷新
        elapsed = (datetime.now() - self.last_refresh_time).total_seconds()
        if elapsed >= self.refresh_interval:
            return True
        
        # 如果可用代理数量为0，需要刷新
        available_count = sum(
            1 for p in self.proxy_pool
            if p.status == ProxyStatus.AVAILABLE and not p.is_expired
        )
        if available_count == 0:
            logger.info(f"可用代理不足({available_count}/{self.pool_size})，触发刷新")
            return True
        
        return False
    
    def _refresh_pool(self):
        """刷新代理池"""
        logger.info("开始刷新代理池...")
        
        # 清理过期代理
        self._clean_expired_proxies()
        
        # 计算需要补充的数量
        current_count = len(self.proxy_pool)
        need_count = max(self.pool_size - current_count, 1)
        
        # 获取新代理
        new_proxies = self._fetch_proxies(num=need_count)
        
        # 添加到代理池
        self.proxy_pool.extend(new_proxies)
        
        # 更新刷新时间
        self.last_refresh_time = datetime.now()
        
        # 更新统计
        self.stats['current_pool_size'] = len(self.proxy_pool)
        
        logger.info(f"代理池刷新完成，当前池大小: {len(self.proxy_pool)}")
    
    def get_proxy(self) -> Optional[ProxyInfo]:
        """
        获取一个可用的代理
        
        Returns:
            代理信息，如果没有可用代理则返回None
        """
        # 如果未启用代理，返回None
        if not self.enable_proxy:
            return None
        
        # 检查是否需要刷新
        if self._should_refresh():
            self._refresh_pool()
        
        # 查找可用代理
        available_proxies = [
            p for p in self.proxy_pool
            if p.status == ProxyStatus.AVAILABLE and not p.is_expired
        ]
        
        if not available_proxies:
            logger.warning("没有可用的代理IP")
            # 尝试强制刷新一次
            self._refresh_pool()
            available_proxies = [
                p for p in self.proxy_pool
                if p.status == ProxyStatus.AVAILABLE and not p.is_expired
            ]
            
            if not available_proxies:
                return None
        
        # 随机选择一个代理（负载均衡）
        proxy = random.choice(available_proxies)
        
        # 更新状态
        proxy.status = ProxyStatus.IN_USE
        proxy.last_use_time = datetime.now()
        
        # 更新统计
        self.stats['total_used'] += 1
        
        logger.debug(f"分配代理: {proxy.server} ({proxy.area} {proxy.isp})")
        
        return proxy
    
    def mark_proxy_success(self, proxy: ProxyInfo):
        """标记代理使用成功"""
        if proxy in self.proxy_pool:
            proxy.status = ProxyStatus.AVAILABLE
            proxy.fail_count = 0  # 重置失败计数
            logger.debug(f"代理使用成功: {proxy.server}")
    
    def mark_proxy_failed(self, proxy: ProxyInfo, error_msg: str = ""):
        """标记代理使用失败"""
        if proxy in self.proxy_pool:
            proxy.fail_count += 1
            
            # HTTP 407 代理认证失败，直接移除
            if "407" in error_msg or "Proxy Authentication Required" in error_msg:
                proxy.status = ProxyStatus.FAILED
                self.proxy_pool.remove(proxy)
                logger.warning(f"代理需要认证(HTTP 407)，已移除: {proxy.server}")
            # 如果失败次数过多，标记为失败状态
            elif proxy.fail_count >= self.max_fail_count:
                proxy.status = ProxyStatus.FAILED
                logger.warning(f"代理失败次数过多({proxy.fail_count})，已剔除: {proxy.server}")
            else:
                # 重新标记为可用，等待下次重试
                proxy.status = ProxyStatus.AVAILABLE
                logger.debug(f"代理暂时失败，稍后重试: {proxy.server}")
            
            # 更新统计
            self.stats['total_failed'] += 1
            
            logger.debug(f"代理使用失败({proxy.fail_count}/{self.max_fail_count}): {proxy.server}")
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        self.stats['current_pool_size'] = len(self.proxy_pool)
        self.stats['available_count'] = sum(
            1 for p in self.proxy_pool
            if p.status == ProxyStatus.AVAILABLE and not p.is_expired
        )
        return self.stats.copy()
    
    def clear_pool(self):
        """清空代理池"""
        self.proxy_pool.clear()
        self.last_refresh_time = None
        logger.info("代理池已清空")


# 全局单例
_proxy_manager: Optional[ProxyManager] = None


def get_proxy_manager(
    api_url: Optional[str] = None,
    api_key: Optional[str] = None,
    **kwargs
) -> ProxyManager:
    """
    获取代理管理器单例
    
    Args:
        api_url: 代理API地址（首次调用必须提供）
        api_key: API密钥（首次调用必须提供）
        **kwargs: 其他配置参数
    """
    global _proxy_manager
    
    if _proxy_manager is None:
        import os
        
        # 从环境变量或参数获取配置
        api_url = api_url or os.getenv('PROXY_API_URL', 'https://share.proxy.qg.net/get')
        api_key = api_key or os.getenv('PROXY_API_KEY', '')
        auth_password = os.getenv('PROXY_AUTH_PASSWORD', '')  # 代理认证密码
        
        if not api_key:
            logger.warning("未配置代理API密钥，代理功能将被禁用")
            enable_proxy = False
        else:
            enable_proxy = kwargs.get('enable_proxy', True)
        
        pool_size = int(os.getenv('PROXY_POOL_SIZE', kwargs.get('pool_size', 1)))  # 默认1个
        refresh_interval = int(os.getenv('PROXY_REFRESH_INTERVAL', kwargs.get('refresh_interval', 300)))
        max_fail_count = int(os.getenv('PROXY_MAX_FAIL_COUNT', kwargs.get('max_fail_count', 3)))
        
        _proxy_manager = ProxyManager(
            api_url=api_url,
            api_key=api_key,
            auth_password=auth_password,
            pool_size=pool_size,
            refresh_interval=refresh_interval,
            max_fail_count=max_fail_count,
            enable_proxy=enable_proxy
        )
    
    return _proxy_manager

