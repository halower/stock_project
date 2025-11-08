# -*- coding: utf-8 -*-
"""简化的代理管理器"""

import random
from typing import Dict, Optional, List
from datetime import datetime
from dataclasses import dataclass

from app.core.logging import logger


@dataclass
class ProxyInfo:
    """代理信息"""
    proxy: str
    proxy_dict: Dict[str, str]
    success_count: int = 0
    failed_count: int = 0
    last_used: Optional[str] = None


class ProxyManager:
    """
    代理管理器（简化版）
    
    功能：
    1. 代理池管理
    2. 成功/失败统计
    3. 黑名单管理
    4. 自动切换
    """
    
    def __init__(self, enable_proxy: bool = False):
        """
        初始化代理管理器
        
        Args:
            enable_proxy: 是否启用代理
        """
        self.enable_proxy = enable_proxy
        self.proxies: List[ProxyInfo] = []
        self.proxy_stats: Dict[str, Dict] = {}
        self.blacklist: set = set()
        
        logger.info(f"代理管理器初始化: {'启用' if enable_proxy else '禁用'}")
    
    def add_proxy(self, proxy: str):
        """
        添加代理
        
        Args:
            proxy: 代理地址，格式: http://ip:port 或 http://user:pass@ip:port
        """
        if proxy not in [p.proxy for p in self.proxies]:
            proxy_info = ProxyInfo(
                proxy=proxy,
                proxy_dict={'http': proxy, 'https': proxy}
            )
            self.proxies.append(proxy_info)
            self.proxy_stats[proxy] = {
                'success': 0,
                'failed': 0,
                'last_success': None,
                'last_failed': None
            }
            logger.info(f"添加代理: {proxy}")
    
    def add_proxies(self, proxies: List[str]):
        """批量添加代理"""
        for proxy in proxies:
            self.add_proxy(proxy)
    
    def get_proxy(self) -> Optional[ProxyInfo]:
        """
        获取可用代理
        
        Returns:
            代理信息，如果没有可用代理则返回None
        """
        if not self.enable_proxy or not self.proxies:
            return None
        
        # 过滤黑名单
        available = [p for p in self.proxies if p.proxy not in self.blacklist]
        
        if not available:
            logger.warning("所有代理都在黑名单中")
            # 清空黑名单，重新尝试
            self.blacklist.clear()
            logger.info("黑名单已清空，重新尝试所有代理")
            available = self.proxies
        
        # 随机选择
        proxy = random.choice(available)
        proxy.last_used = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        return proxy
    
    def mark_proxy_success(self, proxy_info: ProxyInfo):
        """
        标记代理成功
        
        Args:
            proxy_info: 代理信息
        """
        proxy_str = proxy_info.proxy
        
        # 更新代理信息
        proxy_info.success_count += 1
        
        # 更新统计
        if proxy_str in self.proxy_stats:
            self.proxy_stats[proxy_str]['success'] += 1
            self.proxy_stats[proxy_str]['last_success'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # 从黑名单移除
        if proxy_str in self.blacklist:
            self.blacklist.remove(proxy_str)
            logger.info(f"代理 {proxy_str} 恢复正常，移出黑名单")
    
    def mark_proxy_failed(self, proxy_info: ProxyInfo, error_msg: str = ""):
        """
        标记代理失败
        
        Args:
            proxy_info: 代理信息
            error_msg: 错误信息
        """
        proxy_str = proxy_info.proxy
        
        # 更新代理信息
        proxy_info.failed_count += 1
        
        # 更新统计
        if proxy_str in self.proxy_stats:
            self.proxy_stats[proxy_str]['failed'] += 1
            self.proxy_stats[proxy_str]['last_failed'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            
            # 失败次数过多，加入黑名单
            if self.proxy_stats[proxy_str]['failed'] >= 3:
                self.blacklist.add(proxy_str)
                logger.warning(f"代理 {proxy_str} 失败次数过多({self.proxy_stats[proxy_str]['failed']}次)，加入黑名单")
    
    def remove_proxy(self, proxy: str):
        """
        移除代理
        
        Args:
            proxy: 代理地址
        """
        self.proxies = [p for p in self.proxies if p.proxy != proxy]
        if proxy in self.proxy_stats:
            del self.proxy_stats[proxy]
        if proxy in self.blacklist:
            self.blacklist.remove(proxy)
        logger.info(f"移除代理: {proxy}")
    
    def get_stats(self) -> Dict:
        """
        获取统计信息
        
        Returns:
            统计信息字典
        """
        return {
            'total_proxies': len(self.proxies),
            'available_proxies': len([p for p in self.proxies if p.proxy not in self.blacklist]),
            'blacklisted_proxies': len(self.blacklist),
            'blacklist': list(self.blacklist),
            'proxy_stats': self.proxy_stats.copy()
        }
    
    def clear_blacklist(self):
        """清空黑名单"""
        self.blacklist.clear()
        logger.info("代理黑名单已清空")
    
    def reset_stats(self):
        """重置统计信息"""
        for proxy_info in self.proxies:
            proxy_info.success_count = 0
            proxy_info.failed_count = 0
        
        for proxy in self.proxy_stats:
            self.proxy_stats[proxy] = {
                'success': 0,
                'failed': 0,
                'last_success': None,
                'last_failed': None
            }
        
        self.blacklist.clear()
        logger.info("代理统计信息已重置")


# 全局实例
_proxy_manager = None


def get_proxy_manager() -> ProxyManager:
    """获取代理管理器实例"""
    global _proxy_manager
    
    if _proxy_manager is None:
        _proxy_manager = ProxyManager(enable_proxy=False)
    
    return _proxy_manager
