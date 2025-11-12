# -*- coding: utf-8 -*-
"""
实时行情服务 - 仅使用Tushare
简化版本，只保留Tushare数据源实现
"""

import time
from datetime import datetime
from typing import Dict, Any, Optional

from app.core.logging import logger
from .config import realtime_config


class RealtimeService:
    """
    实时行情服务（仅Tushare）
    
    特点：
    1. 支持股票和ETF
    2. 仅使用Tushare数据源
    3. 完整的错误处理和重试机制
    """
    
    def __init__(self):
        """初始化服务"""
        self.config = realtime_config
        
        # 统计信息
        self.stats = {
            'total_requests': 0,
            'tushare': {'success': 0, 'failed': 0, 'last_success_time': None},
            'last_update': None
        }
        
        logger.info(f"实时行情服务初始化（仅Tushare）: 实时更新={'启用' if self.config.enable_realtime_update else '禁用'}")
    
    def get_all_stocks_realtime(
        self, 
        include_etf: bool = False
    ) -> Dict[str, Any]:
        """
        获取所有股票实时数据（使用Tushare）
        
        Args:
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
        
        # 重试机制
        last_error = None
        for retry in range(self.config.retry_times):
            try:
                result = self._fetch_tushare_spot(include_etf)
                
                # 成功
                if result.get('success'):
                    self._mark_success()
                    logger.info(f"成功从Tushare获取{result.get('count', 0)}只{'股票+ETF' if include_etf else '股票'}实时数据")
                    return result
                
                last_error = result.get('error', '未知错误')
                
            except Exception as e:
                last_error = str(e)
                logger.warning(f"获取实时数据失败 (retry={retry+1}/{self.config.retry_times}): {e}")
                
                # 重试前等待
                if retry < self.config.retry_times - 1:
                    time.sleep(1.5)
        
        # 所有重试都失败
        self.stats['tushare']['failed'] += 1
        error_msg = f"Tushare数据获取失败（重试{self.config.retry_times}次）: {last_error}"
        logger.error(error_msg)
        
        return {
            'success': False,
            'error': error_msg,
            'data': [],
            'count': 0,
            'source': 'tushare',
            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    
    def get_all_etfs_realtime(self) -> Dict[str, Any]:
        """
        获取所有ETF实时数据
        
        Returns:
            标准化数据格式
        """
        # 复用股票方法，但只返回ETF
        result = self.get_all_stocks_realtime(include_etf=True)
        
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
    
    def _mark_success(self):
        """标记成功"""
        self.stats['tushare']['success'] += 1
        self.stats['tushare']['last_success_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        self.stats['last_update'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    def _is_etf(self, code: str) -> bool:
        """判断是否为ETF（代码以5或1开头）"""
        return code.startswith(('5', '1'))
    
    def _fetch_tushare_spot(self, include_etf: bool = False) -> Dict[str, Any]:
        """
        从Tushare获取实时行情
        
        使用Tushare的daily接口获取最新日线数据作为实时数据
        
        Args:
            include_etf: 是否包含ETF
            
        Returns:
            标准化数据格式
        """
        try:
            import tushare as ts
            from app.core.config import TUSHARE_TOKEN
            
            if not TUSHARE_TOKEN:
                return {
                    'success': False, 
                    'error': 'Tushare Token未配置', 
                    'data': [], 
                    'count': 0, 
                    'source': 'tushare'
                }
            
            logger.info(f"使用Tushare获取实时数据（include_etf={include_etf}）")
            
            # 初始化Tushare Pro API
            pro = ts.pro_api(TUSHARE_TOKEN)
            
            formatted_data = []
            today = datetime.now().strftime('%Y%m%d')
            
            # 获取股票实时数据
            try:
                logger.debug("获取股票实时日K线数据...")
                
                # 使用rt_k接口获取实时日K线（盘中数据）
                # 使用通配符一次性获取全市场：3*.SZ（创业板）,6*.SH（沪市）,0*.SZ（深市主板）,9*.BJ（北交所）
                # 注意：单次最大6000条，等同于全市场
                logger.info("使用通配符获取全市场实时数据...")
                df_stocks = pro.rt_k(ts_code='3*.SZ,6*.SH,0*.SZ,9*.BJ')
                
                if df_stocks is not None and not df_stocks.empty:
                    logger.info(f"Tushare rt_k接口返回 {len(df_stocks)} 条实时数据")
                    
                    for _, row in df_stocks.iterrows():
                        ts_code = str(row.get('ts_code', ''))
                        code_only = ts_code.split('.')[0] if '.' in ts_code else ts_code
                        
                        # rt_k接口字段：ts_code, name, pre_close, high, open, low, close, vol, amount, num, trade_time
                        # 注意：这是实时日K线，不是分钟K线
                        close_price = float(row.get('close', 0))
                        open_price = float(row.get('open', 0))
                        high_price = float(row.get('high', 0))
                        low_price = float(row.get('low', 0))
                        pre_close_price = float(row.get('pre_close', 0))
                        
                        # 计算涨跌额和涨跌幅
                        change = close_price - pre_close_price
                        pct_chg = (change / pre_close_price * 100) if pre_close_price > 0 else 0
                        
                        formatted_data.append({
                            'code': code_only,
                            'name': str(row.get('name', '')),  # rt_k接口返回name字段
                            'price': close_price,
                            'change': change,
                            'change_pct': pct_chg,
                            'volume': float(row.get('vol', 0)),  # 成交量（股）
                            'amount': float(row.get('amount', 0)),  # 成交额（元）
                            'high': high_price,
                            'low': low_price,
                            'open': open_price,
                            'pre_close': pre_close_price,
                            'ts_code': ts_code
                        })
                    
                    logger.info(f"成功从Tushare获取 {len(formatted_data)} 只股票实时数据")
                else:
                    logger.warning(f"Tushare rt_k接口返回空数据（可能非交易时间或权限不足）")
                
            except Exception as e:
                logger.error(f"Tushare股票数据获取失败: {e}")
                import traceback
                logger.error(traceback.format_exc())
                return {
                    'success': False, 
                    'error': f'股票数据获取失败: {str(e)}', 
                    'data': [], 
                    'count': 0, 
                    'source': 'tushare'
                }
            
            # ETF盘中不需要实时更新，只在全量更新（17:00）时更新
            # include_etf参数保留用于全量更新，但盘中实时更新不处理ETF
            if include_etf:
                logger.info("注意：ETF盘中不进行实时更新，仅在全量更新时更新")
            
            return {
                'success': True,
                'data': formatted_data,
                'count': len(formatted_data),
                'source': 'tushare',
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
        except Exception as e:
            logger.error(f"Tushare数据获取失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False, 
                'error': str(e), 
                'data': [], 
                'count': 0, 
                'source': 'tushare'
            }
    
    def get_stats(self) -> Dict:
        """获取统计信息"""
        return self.stats.copy()
    
    def reset_stats(self):
        """重置统计信息"""
        self.stats = {
            'total_requests': 0,
            'tushare': {'success': 0, 'failed': 0, 'last_success_time': None},
            'last_update': None
        }
        logger.info("统计信息已重置")


# 全局实例
_realtime_service = None


def get_realtime_service() -> RealtimeService:
    """获取实时行情服务实例"""
    global _realtime_service
    
    if _realtime_service is None:
        _realtime_service = RealtimeService()
    
    return _realtime_service
