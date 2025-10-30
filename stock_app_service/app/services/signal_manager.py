# -*- coding: utf-8 -*-
"""买入信号管理器"""

import asyncio
import json
import math
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
import pandas as pd

from app.core.redis_client import get_redis_client
from app.core.logging import logger
from app.services.stock_data_manager import StockDataManager
from app import indicators


class SignalManager:
    """买入信号管理器"""
    
    def __init__(self, batch_size=50):
        self.redis_client = None
        self.batch_size = batch_size  # 批处理大小
        
        # 使用StockDataManager（纯异步IO模式，无需max_threads参数）
        # 信号计算从Redis读取数据，不需要调用API
        self.stock_data_manager = StockDataManager(
            batch_size=batch_size,
            small_batch_size=batch_size // 2,
            max_calls_per_minute=50  # 保留默认值，实际不会调用API
        )
        
        self.buy_signals_key = "buy_signals"
        # 获取可用策略
        self.strategies = indicators.get_all_strategies()
        
    
    async def _get_redis_client(self):
        """获取Redis客户端 - 复用已有连接，避免事件循环冲突"""
        try:
            # 如果已有客户端且连接正常，直接返回
            if self.redis_client:
                try:
                    # 简单的连接检查，避免复杂操作
                    return self.redis_client
                except Exception:
                    # 连接有问题，需要重新获取
                    self.redis_client = None
            
            # 获取新的客户端
            self.redis_client = await get_redis_client()
            return self.redis_client
        except Exception as e:
            logger.error(f"获取Redis客户端失败: {e}")
            raise
    
    async def initialize(self):
        """初始化SignalManager"""
        try:
            # 初始化Redis客户端
            await self._get_redis_client()
            
            # 初始化StockDataManager
            await self.stock_data_manager.initialize()
            
            logger.info(f"SignalManager初始化成功（纯异步IO模式），批处理大小: {self.batch_size}")
            return True
        except Exception as e:
            logger.error(f"SignalManager初始化失败: {e}")
            return False
    
    async def close(self):
        """关闭SignalManager"""
        try:
            # 关闭StockDataManager
            await self.stock_data_manager.close()
            
            # 不直接关闭Redis连接，让管理器来处理
            self.redis_client = None
            logger.info("SignalManager已关闭")
        except Exception as e:
            logger.error(f"SignalManager关闭失败: {e}")
            
    async def acquire_thread(self):
        """空方法 - 纯异步IO模式不需要线程管理"""
        pass
        
    def release_thread(self):
        """空方法 - 纯异步IO模式不需要线程管理"""
        pass
    
    async def initialize_all_buy_signals(self) -> bool:
        """初始化所有买入信号"""
        try:
            logger.info("开始初始化买入信号...")
            
            # 强制清空所有现有信号，重新计算最新数据
            redis_client = await self._get_redis_client()
            existing_count = await redis_client.hlen(self.buy_signals_key)
            
            if existing_count > 0:
                logger.info(f"清空现有的 {existing_count} 个买入信号，重新计算最新数据...")
                await redis_client.delete(self.buy_signals_key)
                logger.info("已清空所有现有信号")
            
            # 强制重新计算买入信号
            result = await self.calculate_buy_signals(force_recalculate=True)
            
            if result.get("status") == "success":
                logger.info(f"买入信号初始化成功: {result.get('total_signals', 0)} 个信号")
                return True
            else:
                logger.error(f"买入信号初始化失败: {result.get('message', '未知错误')}")
                return False
                
        except Exception as e:
            logger.error(f"买入信号初始化异常: {str(e)}")
            return False
        
    async def get_buy_signals_count(self) -> int:
        """获取买入信号总数"""
        try:
            redis_client = await self._get_redis_client()
            count = await redis_client.hlen(self.buy_signals_key)
            return count
        except Exception as e:
            logger.error(f"获取买入信号数量失败: {e}")
            return 0
    
    async def check_buy_signals_status(self) -> Tuple[bool, int]:
        """检查买入信号状态"""
        try:
            redis_client = await self._get_redis_client()
            signals_data = await redis_client.hgetall(self.buy_signals_key)
            
            if not signals_data:
                return False, 0
            
            # 检查是否有旧策略信号
            old_strategy_names = {"ma_breakout", "volume_price", "breakthrough"}
            valid_signals = 0
            has_old_signals = False
            
            for key, value in signals_data.items():
                try:
                    signal_data = json.loads(value)
                    strategy = signal_data.get('strategy')
                    
                    if strategy in old_strategy_names:
                        has_old_signals = True
                        continue  # 不计入有效信号
                    elif strategy in self.strategies:
                        valid_signals += 1
                except json.JSONDecodeError:
                    continue
            
            # 如果发现旧策略信号，返回不充足状态以触发重新初始化
            if has_old_signals:
                logger.info(f"发现旧策略信号，需要重新初始化")
                return False, valid_signals
            
            # 检查信号数量是否充足
            is_sufficient = valid_signals >= 10
            return is_sufficient, valid_signals
            
        except Exception as e:
            logger.error(f"检查买入信号状态失败: {str(e)}")
            return False, 0
    
    async def get_buy_signals(self, strategy: Optional[str] = None, limit: int = None) -> List[Dict[str, Any]]:
        """获取买入信号列表"""
        try:
            # 从Redis获取所有买入信号
            redis_client = await self._get_redis_client()
            signals_data = await redis_client.hgetall(self.buy_signals_key)
            
            if not signals_data:
                logger.info("Redis中没有找到买入信号数据")
                return []
            
            signals = []
            for key, value in signals_data.items():
                try:
                    signal_data = json.loads(value)
                    
                    # 如果指定了策略，只返回该策略的信号
                    if strategy and signal_data.get('strategy') != strategy:
                        continue
                        
                    signals.append(signal_data)
                except json.JSONDecodeError as e:
                    logger.error(f"解析信号数据失败: {key}, {e}")
                    continue
            
            # 更新信号中的实时价格数据
            await self._update_signals_with_realtime_prices(signals, redis_client)
            
            # 过滤掉股票名称包含ST和*ST的股票
            filtered_signals = []
            for signal in signals:
                stock_name = signal.get('name', '')
                # 检查股票名称是否包含ST或*ST
                if 'ST' in stock_name or '*ST' in stock_name:
                    logger.debug(f"过滤掉ST股票: {signal.get('code', '')} - {stock_name}")
                    continue
                filtered_signals.append(signal)
            
            logger.info(f"过滤前信号数量: {len(signals)}, 过滤后信号数量: {len(filtered_signals)}")
            
            # 分离股票和 ETF 信号
            stock_signals = []
            etf_signals = []
            
            for signal in filtered_signals:
                # 通过 market 字段判断是否为 ETF
                if signal.get('market') == 'ETF':
                    etf_signals.append(signal)
                else:
                    stock_signals.append(signal)
            
            # 分别按置信度和时间排序
            stock_signals.sort(key=lambda x: (-x.get('confidence', 0), -x.get('timestamp', 0)))
            etf_signals.sort(key=lambda x: (-x.get('confidence', 0), -x.get('timestamp', 0)))
            
            # 股票在前，ETF 在后
            filtered_signals = stock_signals + etf_signals
            
            logger.info(f"排序结果: 股票信号 {len(stock_signals)} 个，ETF 信号 {len(etf_signals)} 个")
            
            # 如果指定了限制数量，则应用限制
            if limit is not None:
                return filtered_signals[:limit]
            else:
                return filtered_signals
            
        except Exception as e:
            logger.error(f"获取买入信号失败: {str(e)}")
            return []
    
    async def _process_stock_with_thread_control(self, stock: Dict, strategy_code: str, strategy_info: Dict) -> Tuple[bool, int]:
        """使用线程控制处理单只股票的信号计算
        
        参数:
            stock: 股票信息字典
            strategy_code: 策略代码
            strategy_info: 策略信息
            
        返回:
            Tuple[bool, int]: (是否成功, 生成的信号数量)
        """
        try:
            # 获取线程资源
            await self.acquire_thread()
            
            ts_code = stock.get('ts_code')
            if not ts_code:
                return False, 0
            
            # 获取股票历史数据 - 使用实例变量避免重复获取客户端
            if not self.redis_client:
                self.redis_client = await get_redis_client()
            
            kline_key = f"stock_trend:{ts_code}"
            kline_data = await self.redis_client.get(kline_key)
            
            if not kline_data:
                logger.debug(f"    {ts_code} 没有K线数据")
                return False, 0
            
            # 解析股票趋势数据
            trend_data = json.loads(kline_data)
            kline_json = trend_data.get('data', [])
            
            if not kline_json or len(kline_json) < 20:
                logger.debug(f"    {ts_code} K线数据不足 ({len(kline_json) if kline_json else 0} 条)")
                return False, 0
            
            # 转换为DataFrame
            df = pd.DataFrame(kline_json)
            
            # 修复列名映射
            if 'vol' in df.columns and 'volume' not in df.columns:
                df['volume'] = df['vol']
            
            # 验证DataFrame结构
            required_columns = ['close', 'open', 'high', 'low', 'volume']
            missing_columns = [col for col in required_columns if col not in df.columns]
            if missing_columns:
                logger.debug(f"    {ts_code} 缺少必要列: {missing_columns}")
                return False, 0
            
            # 检查数据质量
            if df['close'].isna().all():
                logger.debug(f"    {ts_code} 收盘价全为空")
                return False, 0
                                            
            logger.debug(f"    {ts_code} 数据验证通过，K线数量: {len(df)}")
            
            # 应用策略
            processed_df, signals = indicators.apply_strategy(strategy_code, df)
            
            logger.debug(f"    {ts_code} 策略 {strategy_code} 返回 {len(signals)} 个信号")
                                            
            # 只处理最后一根K线的买入信号（实战意义）
            last_index = len(df) - 1  # 最后一根K线的索引
            signal_count = 0
            
            for signal in signals:
                if signal.get('type') == 'buy':
                    signal_index = signal.get('index', 0)
                    
                    # 只保留最后一根K线的买入信号
                    if signal_index == last_index:
                        # 存储信号逻辑（复用原有代码）
                        await self._store_signal(stock, signal, df, signal_index, strategy_code, strategy_info, self.redis_client)
                        signal_count += 1
            
            return True, signal_count
            
        except Exception as e:
            logger.warning(f"    处理股票 {stock.get('ts_code', 'unknown')} 失败: {str(e)}")
            return False, 0
        finally:
            # 释放线程资源
            self.release_thread()
    
    async def _store_signal(self, stock: Dict, signal: Dict, df: pd.DataFrame, signal_index: int, 
                           strategy_code: str, strategy_info: Dict, redis_client) -> None:
        """存储买入信号"""
        try:
            ts_code = stock.get('ts_code')
            confidence = 0.8  # 默认置信度
            
            logger.info(f"    发现最新买入信号: {ts_code} - 价格: {signal.get('price', 0)} (最后一根K线)")
            
            # 去掉ts_code的后缀，只保留纯数字代码
            clean_code = ts_code.split('.')[0] if '.' in ts_code else ts_code
            
            # 获取成交量信息
            volume = 0
            volume_ratio = 0.0  # 量能比值
            
            if signal_index < len(df) and 'volume' in df.columns:
                current_volume = df.iloc[signal_index]['volume']
                volume = float(current_volume) if not pd.isna(current_volume) else 0
                
                # 如果当前成交量为0，尝试从vol字段获取
                if volume == 0 and 'vol' in df.columns:
                    vol_value = df.iloc[signal_index]['vol']
                    volume = float(vol_value) if not pd.isna(vol_value) else 0
                
                # 计算量能比值：当前成交量/前一根K线成交量
                if signal_index > 0 and volume > 0:
                    # 获取前一根K线的成交量
                    prev_volume_raw = df.iloc[signal_index - 1]['volume']
                    prev_volume = float(prev_volume_raw) if not pd.isna(prev_volume_raw) else 0
                    
                    # 如果前一根K线成交量为0，尝试从vol字段获取
                    if prev_volume == 0 and 'vol' in df.columns:
                        prev_vol_raw = df.iloc[signal_index - 1]['vol']
                        prev_volume = float(prev_vol_raw) if not pd.isna(prev_vol_raw) else 0
                    
                    # 计算量能比值
                    if prev_volume > 0:
                        ratio = volume / prev_volume
                        # 确保比值是有效数值
                        if not math.isnan(ratio) and not math.isinf(ratio) and ratio > 0:
                            volume_ratio = round(ratio, 2)
                            logger.debug(f"    {ts_code} 量能比值计算: 当前量 {volume}, 前一根量 {prev_volume}, 比值 {volume_ratio}")
                        else:
                            logger.debug(f"    {ts_code} 量能比值计算异常: 当前量 {volume}, 前一根量 {prev_volume}, 比值 {ratio}")
                    else:
                        logger.debug(f"    {ts_code} 前一根K线成交量为0: 当前量 {volume}, 前一根量 {prev_volume}")
                else:
                    if volume == 0:
                        logger.debug(f"    {ts_code} 当前成交量为0，无法计算量能比值")
                    elif signal_index == 0:
                        logger.debug(f"    {ts_code} 是第一根K线，无法计算量能比值")
            else:
                logger.debug(f"    {ts_code} 缺少成交量数据列，无法计算量能比值")
            
            # 计算涨跌幅
            change_percent = 0.0
            if signal_index < len(df):
                signal_row = df.iloc[signal_index]
                if 'close' in df.columns and 'pre_close' in df.columns:
                    close_price = float(signal_row['close']) if not pd.isna(signal_row['close']) else 0
                    pre_close_price = float(signal_row['pre_close']) if not pd.isna(signal_row['pre_close']) else 0
                    if pre_close_price > 0:
                        change_percent = round((close_price - pre_close_price) / pre_close_price * 100, 2)
                elif 'open' in df.columns and 'close' in df.columns:
                    # 如果没有pre_close，使用开盘价计算当日涨跌幅
                    close_price = float(signal_row['close']) if not pd.isna(signal_row['close']) else 0
                    open_price = float(signal_row['open']) if not pd.isna(signal_row['open']) else 0
                    if open_price > 0:
                        change_percent = round((close_price - open_price) / open_price * 100, 2)
            
            # 清理所有数值，确保JSON序列化兼容
            def clean_value(value, default=0):
                if value is None:
                    return default
                if isinstance(value, (int, float)):
                    if math.isnan(value) or math.isinf(value):
                        return default
                    return value
                try:
                    num_value = float(value)
                    if math.isnan(num_value) or math.isinf(num_value):
                        return default
                    return num_value
                except (ValueError, TypeError):
                    return default
            
            # 获取K线对应的实际交易日期
            kline_date = None
            if signal_index < len(df) and 'date' in df.columns:
                kline_date = df.iloc[signal_index]['date']
            elif signal_index < len(df) and 'trade_date' in df.columns:
                trade_date = df.iloc[signal_index]['trade_date']
                if isinstance(trade_date, str) and len(trade_date) == 8:
                    # 格式：20241220 -> 2024-12-20
                    kline_date = f"{trade_date[:4]}-{trade_date[4:6]}-{trade_date[6:8]}"
                else:
                    kline_date = str(trade_date)
            
            signal_data = {
                'code': clean_code,
                'name': stock.get('name', ''),
                'industry': stock.get('industry', ''),  # 行业字段（ETF 为 T+0交易/T+1交易）
                'market': stock.get('market', ''),  # 市场字段（ETF 为 'ETF'）
                'strategy': strategy_code,
                'strategy_name': strategy_info['name'],
                'confidence': clean_value(confidence, 0.75),
                'kline_date': kline_date,  # K线对应的实际交易日期
                'calculated_time': datetime.now().isoformat(),  # 计算触发的时间
                'timestamp': datetime.now().timestamp(),  # 用于排序的时间戳
                'price': clean_value(signal.get('price', 0)),
                'volume': clean_value(volume),  # 成交量
                'volume_ratio': clean_value(volume_ratio),  # 量能比值
                'change_percent': clean_value(change_percent),  # 涨跌幅
                'reason': f"策略{strategy_code}最新买入信号",
                'signal_index': signal_index,
                'is_latest': True  # 标记为最新信号
            }
            
            signal_key = f"{clean_code}:{strategy_code}"
            await redis_client.hset(
                self.buy_signals_key,
                signal_key,
                json.dumps(signal_data)
            )
        except Exception as e:
            logger.error(f"存储信号失败: {str(e)}")
            
    async def _update_signals_with_realtime_prices(self, signals: List[Dict[str, Any]], redis_client) -> None:
        """更新信号中的实时价格数据"""
        try:
            updated_count = 0
            for signal in signals:
                code = signal.get('code', '')
                if not code:
                    continue
                
                # 尝试获取实时价格数据
                realtime_data = await self._get_realtime_price_data(code, redis_client)
                if realtime_data:
                    # 更新价格相关字段
                    original_price = signal.get('price', 0)
                    current_price = realtime_data.get('price', 0)
                    current_change_pct = realtime_data.get('pct_chg', 0)
                    
                    # 更新信号数据
                    signal['current_price'] = current_price  # 当前实时价格
                    signal['original_price'] = original_price  # 原始信号价格
                    signal['current_change_percent'] = current_change_pct  # 当前涨跌幅
                    signal['price_updated_at'] = realtime_data.get('update_time', '')
                    
                    # 计算从信号价格到当前价格的收益率
                    if original_price > 0:
                        price_return = round((current_price - original_price) / original_price * 100, 2)
                        signal['price_return_percent'] = price_return
                    else:
                        signal['price_return_percent'] = 0.0
                    
                    # 如果有实时价格，使用实时价格作为主要显示价格
                    if current_price > 0:
                        signal['price'] = current_price
                        signal['change_percent'] = current_change_pct
                    
                    updated_count += 1
            
            if updated_count > 0:
                logger.debug(f"已更新 {updated_count}/{len(signals)} 个信号的实时价格")
        except Exception as e:
            logger.error(f"更新信号实时价格失败: {str(e)}")

    async def _get_realtime_price_data(self, code: str, redis_client) -> Optional[Dict[str, Any]]:
        """获取股票的实时价格数据"""
        try:
            # 尝试不同的股票代码格式
            possible_keys = [
                f"stocks:realtime:{code}.SH",  # 上海交易所
                f"stocks:realtime:{code}.SZ",  # 深圳交易所
                f"stocks:realtime:{code}"      # 无后缀
            ]
            
            for key in possible_keys:
                realtime_data = await redis_client.get(key)
                if realtime_data:
                    try:
                        return json.loads(realtime_data)
                    except json.JSONDecodeError:
                                continue
            
            return None
            
        except Exception as e:
            logger.debug(f"获取股票 {code} 实时价格数据失败: {str(e)}")
            return None
    
    async def calculate_buy_signals(self, force_recalculate: bool = False, etf_only: bool = False, stock_only: bool = False, clear_existing: bool = True) -> Dict[str, Any]:
        """
        计算买入信号
        
        Args:
            force_recalculate: 是否强制重新计算
            etf_only: 是否仅计算 ETF 信号（True=仅ETF, False=包含所有或仅股票）
            stock_only: 是否仅计算股票信号（True=仅股票, False=包含所有或仅ETF）
            clear_existing: 是否清空现有信号（默认True，追加模式设为False）
        """
        try:
            start_time = datetime.now()
            if etf_only:
                signal_type = "ETF"
            elif stock_only:
                signal_type = "股票"
            else:
                signal_type = "股票+ETF"
            logger.info(f"开始计算{signal_type}买入信号...")
            
            # 根据参数决定是否清空旧信号
            if clear_existing:
                logger.info("清空所有旧信号...")
                
                # 使用同步Redis客户端，避免事件循环冲突
                from app.core.sync_redis_client import get_sync_redis_client
                sync_redis = get_sync_redis_client()
                
                # 清空新系统的信号数据
                old_signals_count = sync_redis.hlen(self.buy_signals_key)
                if old_signals_count > 0:
                    sync_redis.delete(self.buy_signals_key)
                    logger.info(f"已清空新系统 {old_signals_count} 个旧信号")
                
                # 清空旧系统的信号数据（确保兼容性）
                legacy_key = "stock:buy_signals"
                legacy_count = 0
                try:
                    # 检查旧系统键是否存在
                    if sync_redis.exists(legacy_key):
                        key_type = sync_redis.type(legacy_key)
                        legacy_count = sync_redis.hlen(legacy_key) if key_type == 'hash' else 1
                        sync_redis.delete(legacy_key)
                        logger.info(f"已清空旧系统 {legacy_count} 个旧信号")
                except Exception as e:
                    logger.debug(f"清空旧系统信号数据时出现异常（可忽略）: {e}")
                
                if old_signals_count == 0 and legacy_count == 0:
                    logger.info("无旧信号需要清空")
            else:
                logger.info(f"追加模式：不清空现有信号，新增{signal_type}信号")
            
            # 初始化异步Redis客户端用于后续操作
            self.redis_client = await get_redis_client()
            redis_client = self.redis_client
            
            # 强制重新计算所有买入信号（确保数据最新）
            logger.info("强制重新计算所有买入信号，确保数据最新...")
            
            # 获取股票列表
            # 使用已初始化的StockDataManager
            try:
                stock_list = await self.stock_data_manager._get_all_stocks()
                if not stock_list:
                    logger.error("获取股票列表失败")
                    return {
                        "status": "error",
                        "message": "获取股票列表失败"
                    }
                
                # 根据参数过滤
                if etf_only:
                    # 仅保留 ETF（market='ETF'）
                    stock_list = [s for s in stock_list if s.get('market') == 'ETF']
                    logger.info(f"获取到 {len(stock_list)} 个 ETF")
                elif stock_only:
                    # 仅保留股票（market!='ETF'）
                    stock_list = [s for s in stock_list if s.get('market') != 'ETF']
                    logger.info(f"获取到 {len(stock_list)} 只股票")
                else:
                    logger.info(f"获取到 {len(stock_list)} 只股票+ETF")
                
                # 处理所有股票/ETF（使用线程控制和优化的批处理）
                if etf_only:
                    item_type = "ETF"
                elif stock_only:
                    item_type = "股票"
                else:
                    item_type = "股票/ETF"
                logger.info(f"将处理全部 {len(stock_list)} 个{item_type}，使用纯异步IO和批处理")
                logger.info(f"配置: 批处理大小 {self.batch_size} (纯异步IO模式，无API调用限制)")
                
                total_signals = 0
                strategy_counts = {}
                processed_stocks = 0
                valid_data_stocks = 0
                
                # 为每个策略计算信号
                for strategy_idx, (strategy_code, strategy_info) in enumerate(self.strategies.items()):
                    logger.info(f"[{strategy_idx+1}/{len(self.strategies)}] 计算策略 {strategy_code} ({strategy_info['name']}) 的买入信号...")
                    
                    strategy_signals = 0
                    strategy_processed = 0
                    strategy_valid_data = 0
                    
                    # 分批处理股票，使用优化的批处理大小
                    # 限制并发数量，避免Redis连接数过多
                    batch_size = min(self.batch_size, 10)  # 将批处理大小限制为10，避免Too many connections
                    total_batches = (len(stock_list) + batch_size - 1) // batch_size
                    
                    for batch_idx in range(0, len(stock_list), batch_size):
                        batch = stock_list[batch_idx:batch_idx + batch_size]
                        current_batch = batch_idx // batch_size + 1
                        
                        logger.info(f"  处理第 {current_batch}/{total_batches} 批股票 ({len(batch)} 只)")
                        
                        # 使用信号量限制实际并发数量
                        semaphore = asyncio.Semaphore(5)  # 最多5个并发任务，避免Redis连接耗尽
                        
                        async def process_with_semaphore(stock):
                            async with semaphore:
                                return await self._process_stock_with_thread_control(stock, strategy_code, strategy_info)
                        
                        # 创建任务列表
                        tasks = [process_with_semaphore(stock) for stock in batch]
                        
                        # 并行执行任务
                        batch_results = await asyncio.gather(*tasks, return_exceptions=True)
                        
                        # 处理结果
                        batch_success = 0
                        batch_signals = 0
                        
                        for idx, result in enumerate(batch_results):
                            stock = batch[idx]
                            if isinstance(result, tuple) and len(result) == 2:
                                success, signal_count = result
                                if success:
                                    strategy_processed += 1
                                    if signal_count > 0:
                                        strategy_valid_data += 1
                                        batch_signals += signal_count
                                        strategy_signals += signal_count
                                        total_signals += signal_count
                                        batch_success += 1
                            elif isinstance(result, Exception):
                                logger.warning(f"    处理股票 {stock.get('ts_code', 'unknown')} 异常: {str(result)}")
                        
                        # 显示批次进度
                        logger.info(f"  第 {current_batch} 批完成: 成功 {batch_success} 只，信号 {batch_signals} 个")
                        
                        # 短暂休息，避免内存压力
                        await asyncio.sleep(0.1)  # 减少休息时间，加快处理速度
                    
                    strategy_counts[strategy_code] = strategy_signals
                    processed_stocks = strategy_processed
                    valid_data_stocks = strategy_valid_data
                    
                    elapsed_time = (datetime.now() - start_time).total_seconds()
                    logger.info(f"策略 {strategy_code} 完成:")
                    logger.info(f"   处理股票: {strategy_processed} 只")
                    logger.info(f"   有效数据: {strategy_valid_data} 只")
                    logger.info(f"   生成信号: {strategy_signals} 个")
                    logger.info(f"   耗时: {elapsed_time:.2f} 秒")
                
                total_elapsed = (datetime.now() - start_time).total_seconds()
                
                logger.info(f"买入信号计算完成!")
                logger.info(f"总体统计:")
                logger.info(f"   总股票数: {len(stock_list)} 只")
                logger.info(f"   处理股票: {processed_stocks} 只")
                logger.info(f"   有效数据: {valid_data_stocks} 只")
                logger.info(f"   总信号数: {total_signals} 个")
                logger.info(f"   总耗时: {total_elapsed:.2f} 秒")
                logger.info(f"各策略信号数量: {strategy_counts}")
                
                return {
                    "status": "success",
                    "message": f"买入信号计算完成",
                    "total_signals": total_signals,
                    "strategy_counts": strategy_counts,
                    "processed_stocks": processed_stocks,
                    "valid_data_stocks": valid_data_stocks,
                    "elapsed_seconds": total_elapsed
                }
                
            finally:
                pass  # 不需要关闭stock_data_manager，因为它是类的成员
        except Exception as e:
            logger.error(f"计算买入信号失败: {str(e)}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return {
                "status": "error",
                "message": f"计算买入信号失败: {str(e)}"
            }
    
    def _calculate_confidence(self, strategy_code: str) -> float:
        """计算策略置信度"""
        # 根据策略类型设置不同的置信度
        confidence_map = {
            "volume_wave": 0.85,      # 量价波动
            "trend_continuation": 0.80 # 趋势延续
        }
        return confidence_map.get(strategy_code, 0.75)
    
    async def get_signal_status(self) -> Dict[str, Any]:
        """获取信号状态"""
        try:
            redis_client = await self._get_redis_client()
            total_signals = await redis_client.hlen(self.buy_signals_key)
            
            # 按策略统计
            signals_data = await redis_client.hgetall(self.buy_signals_key)
            strategy_stats = {}
            
            for key, value in signals_data.items():
                try:
                    signal_data = json.loads(value)
                    strategy = signal_data.get('strategy', 'unknown')
                    if strategy not in strategy_stats:
                        strategy_stats[strategy] = 0
                    strategy_stats[strategy] += 1
                except json.JSONDecodeError:
                    continue
            
            return {
                "total_signals": total_signals,
                "strategy_stats": strategy_stats,
                "available_strategies": list(self.strategies.keys()),
                "last_updated": datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"获取信号状态失败: {str(e)}")
            return {"error": str(e)}
    
    async def clear_signals(self, strategy: Optional[str] = None) -> Dict[str, Any]:
        """清空信号"""
        try:
            redis_client = await self._get_redis_client()
            if strategy:
                # 清空特定策略的信号
                signals_data = await redis_client.hgetall(self.buy_signals_key)
                deleted_count = 0
                
                for key, value in signals_data.items():
                    try:
                        signal_data = json.loads(value)
                        if signal_data.get('strategy') == strategy:
                            await redis_client.hdel(self.buy_signals_key, key)
                            deleted_count += 1
                    except json.JSONDecodeError:
                        continue
                
                return {
                    "status": "success",
                    "message": f"已清空策略 {strategy} 的 {deleted_count} 个信号"
                }
            else:
                # 清空所有信号
                deleted_count = await redis_client.hlen(self.buy_signals_key)
                await redis_client.delete(self.buy_signals_key)
                
                return {
                    "status": "success",
                    "message": f"已清空所有 {deleted_count} 个信号"
                }
                
        except Exception as e:
            logger.error(f"清空信号失败: {str(e)}")
            return {"status": "error", "message": str(e)}
    
    async def get_available_strategies(self) -> List[Dict[str, str]]:
        """获取可用策略列表"""
        try:
            strategies_info = indicators.get_all_strategies()
            return [
                {
                    "code": code,
                    "name": info["name"],
                    "description": info["description"]
                }
                for code, info in strategies_info.items()
            ]
        except Exception as e:
            logger.error(f"获取策略列表失败: {str(e)}")
            return []

    async def smart_update_signals(self) -> Tuple[int, int]:
        """智能更新买入信号
        
        Returns:
            Tuple[int, int]: (更新数量, 跳过数量)
        """
        try:
            logger.info("开始智能更新买入信号...")
            
            # 调用完整的信号计算
            result = await self.calculate_buy_signals(force_recalculate=True)
            
            if result.get("status") == "success":
                updated_count = result.get("total_signals", 0)
                logger.info(f"智能更新完成: 更新了 {updated_count} 个信号")
                return updated_count, 0
            else:
                logger.error(f"智能更新失败: {result.get('message', '未知错误')}")
                return 0, 0
                
        except Exception as e:
            logger.error(f"智能更新买入信号异常: {str(e)}")
            return 0, 0


# 全局实例
signal_manager = SignalManager() 