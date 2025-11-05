# -*- coding: utf-8 -*-
"""
股票数据管理服务
实现股票清单和股票走势数据的管理和检查功能

主要功能:
1. 股票清单管理: 初始化和更新股票基本信息
2. 股票走势数据管理: 获取、存储和更新股票历史交易数据
3. API频率限制控制: 通过TushareRateLimiter类确保API调用不超过限制
4. 数据补偿机制: 对获取失败的股票数据进行补偿处理
5. 系统启动检查: 在系统启动时检查数据完整性

架构说明:
纯异步IO模式 - 使用asyncio实现高效并发，无需多线程/多进程
"""
import asyncio
import logging
from datetime import datetime, time, timedelta
from typing import Dict, List, Optional, Tuple
import json
import redis.asyncio as redis
import tushare as ts
import pandas as pd
from app.core.config import settings
import time as time_module
from collections import defaultdict
import threading

logger = logging.getLogger(__name__)

class TushareRateLimiter:
    """Tushare API频率限制器 - 纯异步IO模式"""
    
    def __init__(self, max_calls_per_minute=240):
        self.call_times = []  # 记录调用时间
        self.max_calls_per_minute = max_calls_per_minute  # Tushare限制（实际250次/分钟，设置240留余量）
        self.daily_limit_reached = False
        self.daily_limit_check_time = None
        self.lock = threading.Lock()
        self.async_lock = None  # 异步锁，用于并发控制
        
    def _record_call(self):
        """记录API调用"""
        with self.lock:
            current_time = time_module.time()
            self.call_times.append(current_time)
            # 只保留最近1分钟的记录
            cutoff_time = current_time - 60
            self.call_times = [t for t in self.call_times if t > cutoff_time]
    
    def _check_rate_limit(self) -> bool:
        """检查是否触发频率限制"""
        with self.lock:
            current_time = time_module.time()
            # 清理过期记录
            cutoff_time = current_time - 60
            self.call_times = [t for t in self.call_times if t > cutoff_time]
            
            # 检查是否超过限制
            return len(self.call_times) >= self.max_calls_per_minute
    
    async def wait_for_rate_limit(self):
        """等待频率限制解除 - 纯异步模式，支持并发安全"""
        # 初始化异步锁（延迟初始化，确保在正确的事件循环中）
        if self.async_lock is None:
            self.async_lock = asyncio.Lock()
        
        # 使用异步锁保护，避免并发竞态条件
        async with self.async_lock:
            # 在锁内再次检查，确保并发安全
            if self._check_rate_limit():
                # 计算等待时间：等待最早的API调用过期（60秒后）
                with self.lock:
                    if self.call_times:
                        oldest_call = min(self.call_times)
                        elapsed = time_module.time() - oldest_call
                        wait_seconds = max(5.0, 60 - elapsed + 1.0)  # 最少等5秒，确保有足够恢复时间
                    else:
                        wait_seconds = 5.0
                
                logger.warning(f"触发Tushare频率限制（{len(self.call_times)}/{self.max_calls_per_minute}），等待 {wait_seconds:.1f} 秒...")
                
                await asyncio.sleep(wait_seconds)
                
                # 等待后立即清理过期记录
                with self.lock:
                    current_time = time_module.time()
                    cutoff_time = current_time - 60
                    old_count = len(self.call_times)
                    self.call_times = [t for t in self.call_times if t > cutoff_time]
                    new_count = len(self.call_times)
                    if old_count > new_count:
                        logger.info(f"清理过期API记录: {old_count} → {new_count}")
                
                logger.info("频率限制解除，继续数据获取...")
    
    def handle_daily_limit_error(self, ts_code: str, days: int):
        """处理每日限制错误"""
        self.daily_limit_reached = True
        self.daily_limit_check_time = datetime.now()
        logger.error("Tushare每日调用量已达上限！")
        logger.info("每日限制将在明天0点重置")
    
    def check_daily_limit_reset(self):
        """检查每日限制是否重置"""
        if (self.daily_limit_reached and self.daily_limit_check_time and 
            datetime.now().date() > self.daily_limit_check_time.date()):
            self.daily_limit_reached = False
            self.daily_limit_check_time = None
            logger.info("Tushare每日限制已重置")

class StockDataManager:
    """
    股票数据管理器
    
    主要功能:
    1. 股票清单管理: 初始化和更新股票基本信息
    2. 股票走势数据管理: 获取、存储和更新股票历史交易数据
    3. API频率限制控制: 通过TushareRateLimiter类确保API调用不超过限制
    4. 数据补偿机制: 对获取失败的股票数据进行补偿处理
    5. 系统启动检查: 在系统启动时检查数据完整性
    
    参数:
        batch_size: 常规批处理大小，默认30
        small_batch_size: 小批量处理大小，默认15
        max_calls_per_minute: 每分钟最大API调用次数，默认240（实际250次/分钟，留10次余量）
    
    架构: 纯异步IO模式，不使用多线程
    """
    
    def __init__(self, batch_size=30, small_batch_size=15, max_calls_per_minute=240):
        self.redis_client = None
        
        # 单Token配置（实际250次/分钟，设置240次留余量）
        self.tushare_token = settings.TUSHARE_TOKEN
        
        # 初始化Tushare API
        if self.tushare_token:
            ts.set_token(self.tushare_token)
            self.pro = ts.pro_api()
            logger.info(f"初始化Tushare Token: {self.tushare_token[:20]}...")
            logger.info(f"✅ Token已配置（每分钟240次请求，纯异步IO模式）")
        else:
            self.pro = None
            logger.warning("未配置Tushare Token")
        
        # 批处理参数
        self.batch_size = batch_size  # 常规批处理大小
        self.small_batch_size = small_batch_size  # 小批量处理大小
        
        # 频率限制器（纯异步模式）
        self.rate_limiter = TushareRateLimiter(max_calls_per_minute=max_calls_per_minute)
        self.failed_stocks = []  # 记录失败的股票，用于后续补偿
        
        logger.info(f"📊 数据管理器配置: 每分钟{max_calls_per_minute}次调用，纯异步IO模式")
    
        
    async def initialize(self):
        """初始化Redis连接"""
        if not self.redis_client:
            from app.core.redis_client import get_redis_client
            self.redis_client = await get_redis_client()
        return self.redis_client is not None

    async def close(self):
        """关闭连接"""
        if self.redis_client:
            await self.redis_client.close()
            self.redis_client = None
            
    async def update_processing_parameters(self, batch_size=None, small_batch_size=None, max_calls_per_minute=None):
        """
        动态更新处理参数
        
        参数:
            batch_size: 常规批处理大小
            small_batch_size: 小批量处理大小
            max_calls_per_minute: 每分钟最大API调用次数
        """
        if batch_size is not None:
            self.batch_size = batch_size
            logger.info(f"更新常规批处理大小为: {batch_size}")
            
        if small_batch_size is not None:
            self.small_batch_size = small_batch_size
            logger.info(f"更新小批量处理大小为: {small_batch_size}")
            
        if max_calls_per_minute is not None:
            self.rate_limiter.max_calls_per_minute = max_calls_per_minute
            logger.info(f"更新每分钟最大API调用次数为: {max_calls_per_minute}")
            
        return {
            "batch_size": self.batch_size,
            "small_batch_size": self.small_batch_size,
            "max_calls_per_minute": self.rate_limiter.max_calls_per_minute
        }

    async def get_processing_status(self) -> Dict:
        """
        获取当前处理状态
        
        返回:
            包含当前处理状态的字典
        """
        # 获取API调用统计
        current_minute_calls = len([t for t in self.rate_limiter.call_times if time_module.time() - t < 60])
        
        # 获取数据统计
        stock_list_count = await self.get_stock_list_count()
        trend_data_count = await self.get_stock_trend_data_count()
        
        return {
            "processing_parameters": {
                "batch_size": self.batch_size,
                "small_batch_size": self.small_batch_size,
                "max_calls_per_minute": self.rate_limiter.max_calls_per_minute,
                "architecture": "纯异步IO模式"
            },
            "api_status": {
                "current_minute_calls": current_minute_calls,
                "daily_limit_reached": self.rate_limiter.daily_limit_reached,
                "api_utilization_percentage": (current_minute_calls / self.rate_limiter.max_calls_per_minute) * 100 if self.rate_limiter.max_calls_per_minute > 0 else 0
            },
            "data_status": {
                "stock_list_count": stock_list_count,
                "trend_data_count": trend_data_count,
                "trend_data_coverage_percentage": (trend_data_count / stock_list_count) * 100 if stock_list_count > 0 else 0
            },
            "timestamp": datetime.now().isoformat()
        }
    
    # ===================== 股票清单管理 =====================
    
    async def get_stock_list_count(self) -> int:
        """获取股票清单数量（兼容旧系统格式）"""
        try:
            # 优先使用新格式
            count = await self.redis_client.hlen("stock_list")
            if count > 0:
                return count
            
            # 兼容旧格式
            old_format_stocks = await self.redis_client.get("stocks:codes:all")
            if old_format_stocks:
                import json
                stocks_data = json.loads(old_format_stocks)
                if isinstance(stocks_data, list):
                    return len(stocks_data)
                    
            return 0
        except Exception as e:
            logger.error(f"获取股票清单数量失败: {e}")
            return 0
    
    async def initialize_stock_list(self) -> bool:
        """初始化股票清单"""
        try:
            logger.info("开始初始化股票清单...")
            
            # 获取股票基本信息
            stock_list = await self._fetch_stock_basic_info()
            
            if not stock_list:
                logger.error("获取股票基本信息失败")
                return False
            
            # 存储到Redis（同时支持新旧格式）
            pipe = self.redis_client.pipeline()
            pipe.delete("stock_list")  # 清空现有数据
            
            # 新格式：Hash存储
            for stock in stock_list:
                stock_key = stock['ts_code']
                stock_data = {
                    'ts_code': stock['ts_code'],
                    'symbol': stock['symbol'],
                    'name': stock['name'],
                    'area': stock.get('area', ''),
                    'industry': stock.get('industry', ''),
                    'market': stock.get('market', ''),
                    'list_date': stock.get('list_date', ''),
                    'updated_at': datetime.now().isoformat()
                }
                pipe.hset("stock_list", stock_key, json.dumps(stock_data))
            
            # 旧格式：兼容性存储（为其他服务提供支持）
            old_format_list = []
            for stock in stock_list:
                old_format_stock = {
                    'ts_code': stock['ts_code'],
                    'symbol': stock['symbol'],
                    'name': stock['name'],
                    'area': stock.get('area', ''),
                    'industry': stock.get('industry', ''),
                    'market': stock.get('market', '')
                }
                old_format_list.append(old_format_stock)
            
            # 存储旧格式数据
            pipe.set("stocks:codes:all", json.dumps(old_format_list))
            
            await pipe.execute()
            
            count = len(stock_list)
            logger.info(f"股票清单初始化完成，共{count}只股票")
            logger.info(f"同时存储了新格式(stock_list)和旧格式(stocks:codes:all)以确保兼容性")
            return True
            
        except Exception as e:
            logger.error(f"初始化股票清单失败: {e}")
            return False
    
    async def _fetch_stock_basic_info(self) -> List[Dict]:
        """获取股票基本信息"""
        try:
            # 使用tushare获取股票基本信息
            if self.pro:
                try:
                    df = self.pro.stock_basic(exchange='', list_status='L', fields='ts_code,symbol,name,area,industry,market,list_date')
                    return df.to_dict('records')
                except Exception as e:
                    logger.warning(f"tushare获取股票基本信息失败: {e}")
            
            logger.error("未配置Tushare API，无法获取股票基本信息")
            return []
            
        except Exception as e:
            logger.error(f"获取股票基本信息失败: {e}")
            return []
    
    async def initialize_etf_list(self, clear_existing: bool = True) -> bool:
        """
        初始化 ETF 清单
        
        Args:
            clear_existing: 是否清空现有的 ETF 数据（默认 True）
        """
        try:
            logger.info("开始初始化 ETF 清单...")
            
            # 直接从配置文件获取 ETF 列表（121个精选ETF）
            from app.core.etf_config import get_etf_list
            etf_list = get_etf_list()
            
            if not etf_list:
                logger.error("获取 ETF 基本信息失败")
                return False
            
            logger.info(f"从配置文件获取到 {len(etf_list)} 个 ETF")
            
            # 清空现有的 ETF 数据
            if clear_existing:
                logger.info("清空现有的 ETF 数据...")
                
                # 1. 从 stock_list 中删除所有 ETF
                all_keys = await self.redis_client.hkeys("stock_list")
                etf_keys_to_delete = []
                
                for key in all_keys:
                    stock_data = await self.redis_client.hget("stock_list", key)
                    if stock_data:
                        try:
                            stock_info = json.loads(stock_data)
                            if stock_info.get('market') == 'ETF':
                                etf_keys_to_delete.append(key)
                        except:
                            pass
                
                if etf_keys_to_delete:
                    pipe = self.redis_client.pipeline()
                    for key in etf_keys_to_delete:
                        pipe.hdel("stock_list", key)
                    await pipe.execute()
                    logger.info(f"已从 stock_list 删除 {len(etf_keys_to_delete)} 个旧 ETF")
                
                # 2. 删除 ETF K线数据（ETF使用etf_trend:前缀）
                deleted_kline_count = 0
                for key in etf_keys_to_delete:
                    kline_key = f"etf_trend:{key}"
                    if await self.redis_client.delete(kline_key):
                        deleted_kline_count += 1
                
                if deleted_kline_count > 0:
                    logger.info(f"已删除 {deleted_kline_count} 个 ETF 的 K线数据")
                
                # 3. 删除专门的 ETF 列表
                await self.redis_client.delete("etf:list:all")
                logger.info("已清空 ETF 专用列表")
            
            # 存储新的 ETF 数据到 Redis
            pipe = self.redis_client.pipeline()
            
            # 新格式：Hash 存储到 stock_list（ETF 和股票混合存储）
            for etf in etf_list:
                etf_key = etf['ts_code']
                etf_data = {
                    'ts_code': etf['ts_code'],
                    'symbol': etf['symbol'],
                    'name': etf['name'],
                    'area': etf.get('area', ''),
                    'industry': etf.get('industry', 'T+0交易'),  # T+0交易 或 T+1交易
                    'market': etf.get('market', 'ETF'),  # 虚拟的 ETF 板块
                    'list_date': etf.get('list_date', ''),
                    'updated_at': datetime.now().isoformat()
                }
                pipe.hset("stock_list", etf_key, json.dumps(etf_data))
            
            # 同时存储到专门的 ETF 列表（方便单独查询）
            pipe.set("etf:list:all", json.dumps(etf_list))
            
            await pipe.execute()
            
            count = len(etf_list)
            logger.info(f"✅ ETF 清单初始化完成，共 {count} 个可交易 ETF")
            logger.info(f"ETF 已存储到 stock_list（与股票混合）和 etf:list:all（单独列表）")
            
            # 更新 stocks:codes:all 包含 ETF
            await self._update_stocks_codes_all()
            
            return True
            
        except Exception as e:
            logger.error(f"初始化 ETF 清单失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False
    
    async def initialize_combined_list(self) -> bool:
        """初始化股票和 ETF 的组合清单"""
        try:
            logger.info("开始初始化股票和 ETF 组合清单...")
            
            # 先初始化股票
            stock_success = await self.initialize_stock_list()
            if not stock_success:
                logger.error("股票清单初始化失败")
                return False
            
            # 再初始化 ETF
            etf_success = await self.initialize_etf_list()
            if not etf_success:
                logger.warning("ETF 清单初始化失败，但股票清单已成功")
                return True  # 股票成功就算部分成功
            
            # 更新 stocks:codes:all 包含股票和 ETF
            await self._update_stocks_codes_all()
            
            logger.info("✅ 股票和 ETF 组合清单初始化完成")
            return True
            
        except Exception as e:
            logger.error(f"初始化组合清单失败: {e}")
            return False
    
    async def _update_stocks_codes_all(self):
        """
        更新 stocks:codes:all，包含股票和 ETF
        用于兼容旧的 API（如 chart API）
        """
        try:
            # 从 stock_list 读取所有数据（包括股票和 ETF）
            all_data = await self.redis_client.hgetall("stock_list")
            
            combined_list = []
            for ts_code, data_str in all_data.items():
                try:
                    stock_data = json.loads(data_str)
                    combined_list.append({
                        'ts_code': stock_data['ts_code'],
                        'symbol': stock_data['symbol'],
                        'name': stock_data['name'],
                        'area': stock_data.get('area', ''),
                        'industry': stock_data.get('industry', ''),
                        'market': stock_data.get('market', '')
                    })
                except:
                    pass
            
            # 更新 stocks:codes:all
            await self.redis_client.set("stocks:codes:all", json.dumps(combined_list))
            logger.info(f"✅ 已更新 stocks:codes:all，包含 {len(combined_list)} 个标的（股票+ETF）")
            
        except Exception as e:
            logger.error(f"更新 stocks:codes:all 失败: {e}")
    
    async def check_stock_list_status(self) -> Tuple[bool, int]:
        """检查股票清单状态"""
        count = await self.get_stock_list_count()
        is_sufficient = count >= 5000
        
        logger.info(f"股票清单检查结果: {count}只股票, {'充足' if is_sufficient else '不足'}")
        return is_sufficient, count
    
    # ===================== 股票走势数据管理 =====================
    
    async def get_stock_trend_data_count(self) -> int:
        """获取有走势数据的股票数量"""
        try:
            # 确保有活跃的连接
            if not self.redis_client:
                await self.initialize()
            
            # 扫描所有股票走势数据key
            keys = []
            async for key in self.redis_client.scan_iter(match="stock_trend:*"):
                keys.append(key)
            return len(keys)
        except Exception as e:
            logger.error(f"获取股票走势数据数量失败: {e}")
            return 0
    
    async def initialize_all_stock_trend_data(self) -> bool:
        """初始化所有股票走势数据 - 简化为单线程串行处理"""
        try:
            logger.info("=" * 70)
            logger.info("🚀 开始初始化所有股票走势数据...")
            logger.info("=" * 70)
            
            # 设置初始化状态
            await self.redis_client.set("stock_data_init_status", "正在初始化股票数据...")
            
            # 获取股票清单
            stock_list = await self._get_all_stocks()
            if not stock_list:
                logger.error("❌ 获取股票清单失败")
                return False
            
            total_count = len(stock_list)
            logger.info(f"📊 共需要初始化 {total_count} 只股票的走势数据")
            logger.info(f"📈 每只股票获取180天K线数据（满足EMA169需求）")
            logger.info(f"⚡ API配置: 单Token, 每分钟{self.rate_limiter.max_calls_per_minute}次调用")
            logger.info(f"🔄 处理模式: 单线程串行（简单可靠）")
            
            start_time = datetime.now()
            success_count = 0
            failed_count = 0
            
            # 串行处理所有股票
            for i, stock in enumerate(stock_list, 1):
                ts_code = stock.get('ts_code')
                stock_name = stock.get('name', ts_code)
                
                try:
                    # 每100只股票显示一次进度
                    if i % 100 == 0 or i == 1:
                        elapsed = (datetime.now() - start_time).total_seconds()
                        speed = i / elapsed * 60 if elapsed > 0 else 0
                        remaining = (total_count - i) / speed if speed > 0 else 0
                        logger.info(f"📍 进度: {i}/{total_count} ({i/total_count*100:.1f}%) | "
                                  f"成功: {success_count} | 失败: {failed_count} | "
                                  f"速度: {speed:.1f}只/分钟 | 预计剩余: {remaining:.1f}分钟")
                    
                    # 获取180天数据
                    success = await self._fetch_with_tushare(ts_code, 180)
                    
                    if success:
                        success_count += 1
                        if i % 50 == 0:  # 每50只详细记录一次
                            logger.debug(f"✅ [{i}/{total_count}] {stock_name}({ts_code}) - 成功")
                    else:
                        failed_count += 1
                        logger.warning(f"❌ [{i}/{total_count}] {stock_name}({ts_code}) - 失败")
                    
                except Exception as e:
                    failed_count += 1
                    logger.error(f"❌ [{i}/{total_count}] {stock_name}({ts_code}) - 异常: {e}")
            
            # 最终统计
            total_elapsed = (datetime.now() - start_time).total_seconds()
            success_rate = (success_count / total_count) * 100 if total_count > 0 else 0
            avg_speed = total_count / total_elapsed * 60 if total_elapsed > 0 else 0
            
            # 验证实际存储的数据
            actual_count = await self.get_stock_trend_data_count()
            
            logger.info("=" * 70)
            logger.info("✨ 股票走势数据初始化完成!")
            logger.info("=" * 70)
            logger.info("📊 最终统计:")
            logger.info(f"  • 总股票数量: {total_count}")
            logger.info(f"  • 成功: {success_count} 只 ({success_rate:.1f}%)")
            logger.info(f"  • 失败: {failed_count} 只")
            logger.info(f"  • 实际存储: {actual_count} 只")
            logger.info(f"  • 总耗时: {total_elapsed/60:.1f}分钟")
            logger.info(f"  • 平均速度: {avg_speed:.1f}只/分钟")
            
            # API使用统计
            if hasattr(self.rate_limiter, 'call_times'):
                tushare_calls = len(self.rate_limiter.call_times)
                logger.info("⚡ API使用统计:")
                logger.info(f"  • Tushare调用次数: {tushare_calls}")
                logger.info(f"  • 每日限制状态: {'已达上限' if self.rate_limiter.daily_limit_reached else '正常'}")
            
            logger.info("=" * 70)
            
            # 更新初始化状态
            if success_rate >= 95:
                status_msg = f"✅ 初始化完成，成功率: {success_rate:.1f}%"
            elif success_rate >= 80:
                status_msg = f"⚠️ 初始化基本完成，成功率: {success_rate:.1f}%"
            else:
                status_msg = f"❌ 初始化未完成，成功率: {success_rate:.1f}%"
            
            await self.redis_client.set("stock_data_init_status", status_msg)
            
            # 如果成功率低于80%，记录警告
            if success_rate < 80:
                logger.warning(f"⚠️ 数据初始化成功率较低 ({success_rate:.1f}%)，请检查:")
                logger.warning("  1. 网络连接是否正常")
                logger.warning("  2. Tushare Token是否有效")
                logger.warning("  3. 是否达到API每日限额")
            
            return success_rate >= 80  # 至少80%成功才算初始化成功
            
        except Exception as e:
            logger.error(f"❌ 初始化所有股票走势数据失败: {e}")
            # 设置失败状态
            try:
                await self.redis_client.set("stock_data_init_status", f"初始化失败: {str(e)}")
            except:
                pass
            return False
    
    # 已删除复杂的并行处理函数，采用简单的串行处理
    
    async def _is_etf(self, ts_code: str) -> bool:
        """判断是否为 ETF"""
        try:
            # 从 Redis 获取股票信息
            stock_data = await self.redis_client.hget("stock_list", ts_code)
            if stock_data:
                stock_info = json.loads(stock_data)
                return stock_info.get('market') == 'ETF'
            return False
        except:
            return False
    
    async def _fetch_with_tushare(self, ts_code: str, days: int) -> bool:
        """
        使用 tushare 获取股票/ETF 数据 - 纯异步IO模式
        
        自动识别 ETF 并使用正确的接口：
        - 股票：使用 daily 接口
        - ETF：使用 fund_daily 接口
        """
        try:
            # 检查并等待API调用限制
            await self.rate_limiter.wait_for_rate_limit()
            
            # 记录API调用
            self.rate_limiter._record_call()
            
            # 计算日期范围
            end_date = datetime.now().strftime('%Y%m%d')
            start_date = (datetime.now() - timedelta(days=days * 2)).strftime('%Y%m%d')
            
            # 判断是否为 ETF
            is_etf = await self._is_etf(ts_code)
            
            # 使用对应的 Tushare API
            if is_etf:
                # ETF 使用 fund_daily 接口
                logger.debug(f"使用 fund_daily 接口获取 ETF {ts_code} 数据")
                df = self.pro.fund_daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
            else:
                # 股票使用 daily 接口
                df = self.pro.daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
            
            if not df.empty:
                df = df.sort_values('trade_date').tail(days)
                source = 'tushare_fund' if is_etf else 'tushare'
                return await self._store_stock_data(ts_code, df, source)
            return False
            
        except Exception as e:
            # 检查是否是每日限制错误
            if "每日调用量超限" in str(e) or "daily calling limit" in str(e).lower():
                self.rate_limiter.handle_daily_limit_error(ts_code, days)
            raise e
    
    # Akshare相关函数已删除，仅使用Tushare
    
    async def _store_stock_data(self, ts_code: str, df: pd.DataFrame, source: str) -> bool:
        """存储股票数据到Redis"""
        try:
            # 转换DataFrame，确保所有数据都可以JSON序列化
            data_records = df.to_dict('records')
            
            # 处理日期类型，转换为字符串
            for record in data_records:
                for key, value in record.items():
                    if pd.isna(value):
                        record[key] = None
                    elif hasattr(value, 'strftime'):  # 处理日期类型
                        record[key] = value.strftime('%Y-%m-%d') if hasattr(value, 'date') else str(value)
                    elif isinstance(value, (pd.Timestamp, datetime)):
                        record[key] = value.strftime('%Y-%m-%d')
            
            trend_data = {
                'ts_code': ts_code,
                'data': data_records,
                'updated_at': datetime.now().isoformat(),
                'data_count': len(df),
                'source': source
            }
            
            # 根据source判断是否为ETF，使用不同的Redis key
            if source == 'tushare_fund':
                key = f"etf_trend:{ts_code}"
            else:
                key = f"stock_trend:{ts_code}"
            
            await self.redis_client.set(key, json.dumps(trend_data, default=str))
            return True
            
        except Exception as e:
            logger.error(f"存储股票 {ts_code} 数据失败: {e}")
            return False
    
    async def update_stock_trend_data(self, ts_code: str, days: int = 180) -> bool:
        """更新单只股票的走势数据（默认180天以支持EMA169）"""
        try:
            # 获取历史数据
            df = await self._fetch_stock_history(ts_code, days)
            if df is None or df.empty:
                logger.debug(f"股票 {ts_code} 无法获取历史数据")
                return False
            
            # 使用标准存储方法（已修复JSON序列化问题）
            success = await self._store_stock_data(ts_code, df, 'manual_update')
            
            if success:
                logger.debug(f"股票 {ts_code} 走势数据更新成功，获取 {len(df)} 条记录")
                return True
            else:
                logger.debug(f"股票 {ts_code} 数据存储失败")
                return False
            
        except Exception as e:
            logger.debug(f"更新股票 {ts_code} 走势数据失败: {e}")
            return False
    
    async def _fetch_stock_history(self, ts_code: str, days: int = 180) -> Optional[pd.DataFrame]:
        """获取股票/ETF历史数据（支持频率控制和失败重试，默认180天以支持EMA169）"""
        try:
            # 计算开始日期
            end_date = datetime.now().strftime('%Y%m%d')
            start_date = (datetime.now() - timedelta(days=days * 2)).strftime('%Y%m%d')
            
            # 检查每日限制是否重置
            self.rate_limiter.check_daily_limit_reset()
            
            # 使用tushare获取数据
            if self.pro and not self.rate_limiter.daily_limit_reached:
                try:
                    # 检查并等待API调用限制
                    await self.rate_limiter.wait_for_rate_limit()
                    
                    # 记录API调用
                    self.rate_limiter._record_call()
                    
                    # 判断是否为 ETF
                    is_etf = await self._is_etf(ts_code)
                    
                    # 使用对应的接口
                    if is_etf:
                        logger.debug(f"使用 fund_daily 接口获取 ETF {ts_code} 数据...")
                        df = self.pro.fund_daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
                    else:
                        logger.debug(f"使用 daily 接口获取股票 {ts_code} 数据...")
                        df = self.pro.daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
                    if not df.empty:
                        df = df.sort_values('trade_date').tail(days)
                        # 添加实际交易日期字段
                        df['actual_trade_date'] = pd.to_datetime(df['trade_date'].astype(str))
                        logger.debug(f"tushare获取 {ts_code} 成功，{len(df)}条数据")
                        return df
                    else:
                        logger.debug(f"tushare获取 {ts_code} 返回空数据")
                except Exception as e:
                    logger.warning(f"tushare获取 {ts_code} 数据失败: {e}")
                    error_msg = str(e)
                    if ("每分钟最多访问" in error_msg or "500次" in error_msg or 
                        "每天最多访问" in error_msg or "20000次" in error_msg):
                        
                        # 如果是每日限制错误，特殊处理
                        if "每天最多访问" in error_msg:
                            self.rate_limiter.handle_daily_limit_error(ts_code, days)
                        else:
                            # 分钟限制错误 - 不跳过，而是暂停等待
                            logger.info(f"{ts_code} 触发分钟限制，等待恢复...")
                            await self.rate_limiter.wait_for_rate_limit()
                            # 重试一次
                            return await self._fetch_stock_history(ts_code, days)
            elif self.rate_limiter.daily_limit_reached:
                logger.debug(f"tushare每日限制已达上限，无法获取 {ts_code} 数据")
            elif not hasattr(self, 'pro') or not self.tushare_token:
                logger.debug(f"tushare未配置，无法获取 {ts_code} 数据")
            
            # 如果tushare失败，返回None
            logger.warning(f"获取 {ts_code} 数据失败")
            return None
            
        except Exception as e:
            logger.error(f"获取 {ts_code} 历史数据异常: {e}")
            return None
    
    async def _get_all_stocks(self) -> List[Dict]:
        """获取所有股票列表（兼容旧系统格式）- 使用同步Redis避免事件循环冲突"""
        try:
            # 使用同步Redis客户端，避免在不同事件循环中调用异步Redis
            from app.core.sync_redis_client import get_sync_redis_client
            sync_redis = get_sync_redis_client()
            
            # 优先使用新格式
            stocks = sync_redis.hgetall("stock_list")
            if stocks:
                result = []
                for key, data in stocks.items():
                    try:
                        # 确保data是字符串再解析
                        if isinstance(data, bytes):
                            data = data.decode('utf-8')
                        if isinstance(data, str):
                            stock_dict = json.loads(data)
                            # 确保解析后是字典
                            if isinstance(stock_dict, dict):
                                result.append(stock_dict)
                            else:
                                logger.warning(f"股票数据格式错误 {key}: {type(stock_dict)}, 数据: {str(stock_dict)[:200]}")
                        else:
                            logger.warning(f"股票数据不是字符串 {key}: {type(data)}, 数据: {str(data)[:200]}")
                    except json.JSONDecodeError as e:
                        logger.warning(f"解析股票数据JSON失败 {key}: {e}, 原始数据: {str(data)[:200]}")
                        continue
                    except Exception as e:
                        logger.warning(f"解析股票数据失败 {key}: {e}")
                        continue
                
                logger.info(f"从 stock_list 获取到 {len(result)} 条有效数据（总共 {len(stocks)} 条）")
                return result
            
            # 兼容旧格式
            old_format_stocks = sync_redis.get("stocks:codes:all")
            if old_format_stocks:
                # 同步Redis返回的是字符串或bytes，需要解析
                if isinstance(old_format_stocks, bytes):
                    old_format_stocks = old_format_stocks.decode('utf-8')
                if isinstance(old_format_stocks, str):
                    stocks_data = json.loads(old_format_stocks)
                else:
                    stocks_data = old_format_stocks
                    
                if isinstance(stocks_data, list):
                    # 确保列表中的每个元素都是字典
                    return [item for item in stocks_data if isinstance(item, dict)]
                    
            return []
        except Exception as e:
            logger.error(f"获取股票列表失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return []
    
    async def check_stock_trend_data_status(self) -> Tuple[bool, int]:
        """检查股票走势数据状态（简洁版 - 只检查数量）"""
        count = await self.get_stock_trend_data_count()
        
        # 简单检查数量是否充足（5000只股票作为充足标准）
        is_sufficient = count >= 5000
        
        logger.info(f"股票走势数据检查结果: {count}只股票有数据, {'数量充足' if is_sufficient else '数量不足'}")
        return is_sufficient, count
    
    # ===================== 智能更新机制 =====================
    
    async def is_force_update_day(self) -> bool:
        """判断是否为强制更新日（周六）"""
        return datetime.now().weekday() == 5  # 周六
    
    async def smart_update_trend_data(self) -> Tuple[int, int]:
        """简化的股票走势数据更新"""
        try:
            logger.info("开始更新股票走势数据...")
            
            # 获取所有股票
            stock_list = await self._get_all_stocks()
            if not stock_list:
                logger.error("获取股票列表失败")
                return 0, 0
            
            total_count = len(stock_list)
            logger.info(f"将更新 {total_count} 只股票的数据")
            
            # 调用已有的初始化函数
            success = await self.initialize_all_stock_trend_data()
            
            if success:
                final_count = await self.get_stock_trend_data_count()
                logger.info(f"股票数据更新完成: {final_count} 只股票")
                return final_count, 0
            else:
                logger.error("股票数据更新失败")
                return 0, total_count
                
        except Exception as e:
            logger.error(f"股票数据更新异常: {e}")
            return 0, len(stock_list) if 'stock_list' in locals() else 0
    
    # ===================== 启动检查 =====================
    
    async def startup_check(self) -> Dict[str, any]:
        """启动时数据检查"""
        logger.info("开始启动数据检查...")
        
        result = {
            'stock_list_check': False,
            'stock_list_count': 0,
            'stock_list_initialized': False,
            'trend_data_check': False,
            'trend_data_count': 0,
            'trend_data_initialized': False,
            'buy_signals_check': False,
            'buy_signals_count': 0,
            'buy_signals_initialized': False,
            'success': False
        }
        
        try:
            # 检查1: 股票清单
            list_sufficient, list_count = await self.check_stock_list_status()
            result['stock_list_check'] = list_sufficient
            result['stock_list_count'] = list_count
            
            if not list_sufficient:
                logger.info("股票清单不足，开始初始化...")
                list_init_success = await self.initialize_stock_list()
                result['stock_list_initialized'] = list_init_success
                
                if list_init_success:
                    _, result['stock_list_count'] = await self.check_stock_list_status()
            
            # 检查2: 股票走势数据
            trend_sufficient, trend_count = await self.check_stock_trend_data_status()
            result['trend_data_check'] = trend_sufficient
            result['trend_data_count'] = trend_count
            
            if not trend_sufficient:
                logger.info("股票走势数据不足，开始初始化...")
                trend_init_success = await self.initialize_all_stock_trend_data()
                result['trend_data_initialized'] = trend_init_success
                
                if trend_init_success:
                    _, result['trend_data_count'] = await self.check_stock_trend_data_status()
            else:
                # 即使数据充足，也要检查是否有遗漏的股票需要补偿
                logger.info("股票走势数据充足，检查是否有遗漏股票需要补偿...")
                missing_count = await self._check_and_compensate_missing_stocks()
                if missing_count > 0:
                    logger.info(f"已补偿 {missing_count} 只遗漏的股票")
                    _, result['trend_data_count'] = await self.check_stock_trend_data_status()
            
            # 检查3: 买入信号（需要依赖前面的数据）
            if result['stock_list_count'] > 0 and result['trend_data_count'] > 0:
                from app.services.signal.signal_manager import signal_manager
                await signal_manager.initialize()
                
                try:
                    signals_sufficient, signals_count = await signal_manager.check_buy_signals_status()
                    result['buy_signals_check'] = signals_sufficient
                    result['buy_signals_count'] = signals_count
                    
                    if not signals_sufficient:
                        logger.info("买入信号不足，开始初始化...")
                        signals_init_success = await signal_manager.initialize_all_buy_signals()
                        result['buy_signals_initialized'] = signals_init_success
                        
                        if signals_init_success:
                            _, result['buy_signals_count'] = await signal_manager.check_buy_signals_status()
                finally:
                    await signal_manager.close()
            else:
                logger.warning("股票清单或走势数据不足，跳过买入信号检查")
            
            result['success'] = True
            logger.info("启动数据检查完成")
            
        except Exception as e:
            logger.error(f"启动数据检查失败: {e}")
            result['error'] = str(e)
        
        return result
    
    async def _check_and_compensate_missing_stocks(self) -> int:
        """检查并补偿遗漏的股票数据"""
        try:
            # 获取所有股票清单
            all_stocks = await self._get_all_stocks()
            if not all_stocks:
                logger.warning("无法获取股票清单，跳过遗漏检查")
                return 0
            
            # 检查哪些股票没有走势数据
            missing_stocks = []
            
            for stock in all_stocks:
                ts_code = stock['ts_code']
                market = stock.get('market', '')
                
                # 根据market字段判断使用哪个Redis key
                if market == 'ETF':
                    key = f"etf_trend:{ts_code}"
                else:
                    key = f"stock_trend:{ts_code}"
                
                # 检查Redis中是否存在该股票的数据
                exists = await self.redis_client.exists(key)
                if not exists:
                    missing_stocks.append(stock)
            
            if not missing_stocks:
                logger.info("所有股票都有走势数据，无需补偿")
                return 0
            
            logger.info(f"发现 {len(missing_stocks)} 只股票缺少走势数据，开始补偿...")
            
            # 如果遗漏股票数量较少，使用串行补偿
            if len(missing_stocks) <= 100:
                logger.info("遗漏股票数量较少，使用串行补偿模式")
                compensated = await self._serial_compensate_missing_stocks(missing_stocks)
            else:
                logger.info("遗漏股票数量较多，使用混合补偿模式")
                # 先尝试小批量并行，失败的再串行补偿
                compensated = await self._hybrid_compensate_missing_stocks(missing_stocks)
            
            logger.info(f"遗漏股票补偿完成: 成功 {compensated}/{len(missing_stocks)} 只")
            return compensated
            
        except Exception as e:
            logger.error(f"检查和补偿遗漏股票失败: {e}")
            return 0
    
    async def _serial_compensate_missing_stocks(self, missing_stocks: List[Dict]) -> int:
        """串行补偿遗漏的股票"""
        compensated = 0
        total = len(missing_stocks)
        
        logger.info(f"开始串行补偿 {total} 只遗漏股票...")
        
        for i, stock in enumerate(missing_stocks, 1):
            ts_code = stock['ts_code']
            stock_name = stock.get('name', '')
            
            try:
                logger.debug(f"[{i}/{total}] 补偿: {ts_code} ({stock_name})")
                
                # 使用综合获取方法
                success = await self._comprehensive_fetch_single_stock(ts_code)
                
                if success:
                    compensated += 1
                    logger.debug(f"[{i}/{total}] 补偿成功: {ts_code}")
                else:
                    logger.debug(f"[{i}/{total}] 补偿失败: {ts_code}")
                
                # 控制补偿速度，避免过于频繁
                await asyncio.sleep(0.3)
                
                # 每20只股票报告一次进度
                if i % 20 == 0:
                    progress = (i / total) * 100
                    success_rate = (compensated / i) * 100
                    logger.info(f"串行补偿进度: {i}/{total} ({progress:.1f}%), 成功率: {success_rate:.1f}%")
                
            except Exception as e:
                logger.debug(f"[{i}/{total}] 补偿异常: {ts_code} - {e}")
        
        return compensated
    
    async def _hybrid_compensate_missing_stocks(self, missing_stocks: List[Dict]) -> int:
        """混合补偿遗漏的股票 - 先小批量并行(使用线程控制)，失败的再串行"""
        total = len(missing_stocks)
        logger.info(f"开始混合补偿 {total} 只遗漏股票...")
        
        # 第一步：小批量并行处理(使用线程控制)
        logger.info("第一步: 小批量并行处理(使用线程控制)...")
        parallel_success, parallel_failed = await self._small_batch_parallel_compensate(missing_stocks)
        
        # 第二步：串行处理失败的股票
        serial_success = 0
        if parallel_failed:
            logger.info(f"第二步: 串行处理 {len(parallel_failed)} 只失败股票...")
            serial_success = await self._serial_compensate_missing_stocks(parallel_failed)
        
        total_success = parallel_success + serial_success
        logger.info(f"混合补偿完成: 并行成功 {parallel_success}, 串行成功 {serial_success}, 总成功 {total_success}")
        
        return total_success
    
    async def _small_batch_parallel_compensate(self, missing_stocks: List[Dict]) -> Tuple[int, List[Dict]]:
        """小批量补偿 - 异步串行处理"""
        success_count = 0
        failed_stocks = []
        
        # 使用类中定义的小批量大小
        batch_size = self.small_batch_size
        total = len(missing_stocks)
        
        for i in range(0, total, batch_size):
            batch = missing_stocks[i:i + batch_size]
            
            logger.info(f"小批量处理 第 {i//batch_size + 1} 批 ({i+1}-{min(i + batch_size, total)}/{total})")
            
            # 异步串行处理
            batch_results = []
            for stock in batch:
                try:
                    result = await self.update_stock_trend_data(stock['ts_code'])
                    batch_results.append(result)
                except Exception as e:
                    logger.error(f"小批量处理股票 {stock['ts_code']} 异常: {e}")
                    batch_results.append(False)
            
            # 统计结果
            for idx, result in enumerate(batch_results):
                stock = batch[idx]
                if isinstance(result, bool) and result:
                    success_count += 1
                else:
                    failed_stocks.append(stock)
            
            # 批次间休息
            await asyncio.sleep(1.0)
        
        return success_count, failed_stocks

# 创建股票数据管理器工厂函数，避免单例问题
def create_stock_data_manager(batch_size=10, small_batch_size=5, max_calls_per_minute=50):
    """
    创建新的股票数据管理器实例
    
    参数:
        batch_size: 常规批处理大小
        small_batch_size: 小批量处理大小
        max_calls_per_minute: 每分钟最大API调用次数
    """
    return StockDataManager(
        batch_size=batch_size,
        small_batch_size=small_batch_size,
        max_calls_per_minute=max_calls_per_minute
    )

# 全局实例（向后兼容）
stock_data_manager = StockDataManager() 