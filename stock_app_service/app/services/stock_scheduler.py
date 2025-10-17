# -*- coding: utf-8 -*-
"""
股票数据调度器
简化逻辑，增加稳定性
- 删除时效性检查
- 周1-5每天17:30全量清空重新获取历史数据
- 15:35收盘后初步信号计算，17:35最终信号计算
- 实时数据更新时自动合并到K线数据
"""

import asyncio
import threading
import traceback
from datetime import datetime, time, timedelta
from typing import Dict, Any, List
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

from app.core.logging import logger
from app.core.config import settings
from app.db.session import RedisCache
from app.services.stock_data_manager import StockDataManager
# 移除全局线程池导入，scheduler不应该影响API服务
# from app.core.thread_pool import global_thread_pool
from app.services.signal_manager import signal_manager
import akshare as ak
import pandas as pd
import json

# Redis缓存客户端
redis_cache = RedisCache()

# 调度器实例
scheduler = None
job_logs = []  # 存储最近的任务执行日志

# 信号计算锁，防止重复执行
_signal_calculation_lock = threading.Lock()
_signal_calculation_running = False

# Redis键名规则
STOCK_KEYS = {
    'stock_codes': 'stocks:codes:all',               # 股票代码列表（修正：应为stocks:codes:all）
    'stock_kline': 'stock_trend:{}',                 # K线数据格式，需要用ts_code填充
    'strategy_signals': 'stock:buy_signals',         # 策略信号
    'realtime_data': 'stock:realtime',               # 实时数据
    'scheduler_log': 'stock:scheduler:log',          # 调度器日志
    'last_update': 'stock:last_update',              # 最后更新时间
}

def add_stock_job_log(job_type: str, status: str, message: str, count: int = 0, execution_time: float = 0.0):
    """添加股票任务执行日志"""
    log_entry = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'job_type': job_type,
        'status': status,
        'message': message,
        'count': count,
        'execution_time': round(execution_time, 2)
    }
    
    # 内存日志（最近10条）
    global job_logs
    job_logs.insert(0, log_entry)
    job_logs = job_logs[:10]
    
    # Redis日志（最近20条）
    redis_logs = redis_cache.get_cache(STOCK_KEYS['scheduler_log']) or []
    redis_logs.insert(0, log_entry)
    redis_logs = redis_logs[:20]
    redis_cache.set_cache(STOCK_KEYS['scheduler_log'], redis_logs, ttl=86400)
    
    logger.info(f"[{job_type}] {message}")

def is_trading_time() -> bool:
    """判断是否为交易时间"""
    now = datetime.now()
    
    # 周末不交易
    if now.weekday() >= 5:  # 5=周六, 6=周日
        return False
    
    current_time = now.time()
    
    # 交易时间: 9:30-11:30, 13:00-15:00
    morning_start = time(9, 30)
    morning_end = time(11, 30)
    afternoon_start = time(13, 0)
    afternoon_end = time(15, 0)
    
    return ((morning_start <= current_time <= morning_end) or 
            (afternoon_start <= current_time <= afternoon_end))

def is_trading_day() -> bool:
    """判断是否为交易日（周一到周五）"""
    return datetime.now().weekday() < 5

# ===================== 任务函数 =====================

def _init_etf_only():
    """仅初始化 ETF 数据（包括清单和K线数据）"""
    try:
        logger.info("========== 开始 ETF 专项初始化 ==========")
        
        def run_etf_init():
            """在新线程中运行 ETF 初始化"""
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                async def init_etf():
                    # 初始化 StockDataManager
                    from app.services.stock_data_manager import StockDataManager
                    sdm = StockDataManager()
                    await sdm.initialize()
                    
                    # 1. 初始化 ETF 清单
                    logger.info("步骤 1: 初始化 ETF 清单...")
                    etf_success = await sdm.initialize_etf_list()
                    if not etf_success:
                        logger.error("ETF 清单初始化失败")
                        return False
                    
                    # 2. 获取 ETF 列表（从 CSV，已过滤 LOF）
                    from app.services.etf_manager import etf_manager
                    etf_list = etf_manager.get_etf_list(enrich=False, use_csv=True)
                    
                    if not etf_list:
                        logger.error("无法获取 ETF 列表")
                        return False
                    
                    logger.info(f"步骤 2: 获取 {len(etf_list)} 个 ETF 的K线数据...")
                    
                    # 3. 获取 ETF K线数据
                    success_count = 0
                    failed_count = 0
                    
                    for i, etf in enumerate(etf_list, 1):
                        ts_code = etf['ts_code']
                        try:
                            # 获取180天K线数据
                            success = await sdm.update_stock_trend_data(ts_code, days=180)
                            if success:
                                success_count += 1
                                logger.info(f"[{i}/{len(etf_list)}] ✅ {ts_code} {etf['name']}")
                            else:
                                failed_count += 1
                                logger.warning(f"[{i}/{len(etf_list)}] ❌ {ts_code} {etf['name']} - 获取失败")
                        except Exception as e:
                            failed_count += 1
                            logger.error(f"[{i}/{len(etf_list)}] ❌ {ts_code} {etf['name']} - 错误: {e}")
                    
                    logger.info(f"✅ ETF K线数据获取完成: 成功 {success_count}, 失败 {failed_count}")
                    
                    # 4. 先计算股票信号（优先，清空旧信号）
                    logger.info("步骤 3: 计算股票买入信号（优先，清空旧信号）...")
                    await _calculate_signals_async(stock_only=True, clear_existing=True)
                    
                    # 5. 再计算 ETF 信号（追加，不清空）
                    logger.info("步骤 4: 计算 ETF 买入信号（追加到股票信号后）...")
                    await _calculate_signals_async(etf_only=True, clear_existing=False)
                    
                    logger.info("========== ETF 专项初始化完成 ==========")
                    await sdm.close()
                    return True
                
                loop.run_until_complete(init_etf())
            except Exception as e:
                logger.error(f"ETF 初始化失败: {e}")
                import traceback
                logger.error(traceback.format_exc())
            finally:
                loop.close()
        
        # 在新线程中执行
        init_thread = threading.Thread(target=run_etf_init, daemon=True)
        init_thread.start()
        logger.info("ETF 初始化任务已在后台启动")
        
    except Exception as e:
        logger.error(f"启动 ETF 初始化失败: {e}")

def init_stock_system(mode: str = "tasks_only"):
    """初始化股票系统数据
    
    Args:
        mode: 初始化模式
            - "skip": 跳过初始化，启动时什么都不执行，等待手动触发
            - "tasks_only": 仅执行任务，不获取历史K线数据，只执行信号计算、新闻获取等任务
            - "full_init": 完整初始化，清空所有数据（股票+ETF）重新获取
            - "etf_only": 仅初始化ETF，只获取和更新ETF数据
            
        注意：为了向后兼容，仍然支持旧模式名称（none, only_tasks, clear_all）
    """
    start_time = datetime.now()
    
    # 向后兼容：映射旧模式名称
    mode_mapping = {
        "none": "skip",
        "only_tasks": "tasks_only",
        "clear_all": "full_init"
    }
    if mode in mode_mapping:
        old_mode = mode
        mode = mode_mapping[mode]
        logger.info(f"检测到旧模式名称 '{old_mode}'，自动映射为新模式 '{mode}'")
    
    try:
        if mode == "skip":
            logger.info("用户选择【skip】模式 - 启动时什么都不执行")
            execution_time = (datetime.now() - start_time).total_seconds()
            add_stock_job_log('init_system', 'success', 'skip模式: 不执行任何初始化', 0, execution_time)
            return
        
        # 特殊模式：仅初始化 ETF
        if mode == "etf_only":
            logger.info("用户选择【etf_only】模式 - 仅初始化 ETF 数据")
            _init_etf_only()
            execution_time = (datetime.now() - start_time).total_seconds()
            add_stock_job_log('init_system', 'success', 'etf_only模式: 仅初始化ETF', 0, execution_time)
            return
        
        # tasks_only 和 full_init 模式都需要继续执行，只是在K线数据处理上有区别
        if mode == "tasks_only":
            logger.info("用户选择【tasks_only】模式 - 跳过K线数据获取，其他计划任务正常执行")
        
        # 其他模式需要获取股票列表（优先使用缓存，网络请求作为备选）
        logger.info("📥 正在获取股票列表...")
        
        # 首先尝试从缓存获取
        stock_codes = redis_cache.get_cache(STOCK_KEYS['stock_codes'])
        
        if not stock_codes or len(stock_codes) < 100:
            logger.warning(" 缓存中无股票数据或数据不完整，尝试从网络刷新...")
            refresh_result = refresh_stock_list()
            if refresh_result.get('success'):
                stock_codes = redis_cache.get_cache(STOCK_KEYS['stock_codes'])
                logger.info(f" 成功从网络刷新股票列表: {len(stock_codes)}只")
            else:
                logger.error(" 自动刷新股票列表失败，无法继续初始化")
                error_msg = refresh_result.get('error', '未知错误')
                add_stock_job_log('init_system', 'failed', f'刷新股票列表失败: {error_msg}')
                return
        else:
            logger.info(f" 使用缓存中的股票列表: {len(stock_codes)}只")

        if not stock_codes:
            logger.error(" 无法获取股票列表，初始化中断")
            add_stock_job_log('init_system', 'failed', '无法获取股票列表')
            return
        
        # K线数据处理：tasks_only 跳过，full_init 执行
        if mode == "full_init":
            logger.info("用户选择【full_init】模式 - 清空所有数据（股票+ETF）重新获取")
            
            # 清空所有历史数据
            logger.info("正在清空所有股票历史数据...")
            cleared_count = 0
            for stock in stock_codes:
                ts_code = stock.get('ts_code')
                if ts_code:
                    # 使用两种键格式确保完全清空
                    key1 = STOCK_KEYS['stock_kline'].format(ts_code)  # 旧格式
                    key2 = f"stock_trend:{ts_code}"  # 新格式
                    
                    # 删除两种可能的键
                    if redis_cache.redis_client.delete(key1):
                        cleared_count += 1
                    if redis_cache.redis_client.delete(key2):
                        logger.debug(f"额外清空新格式键: {key2}")
                    
            logger.info(f"已清空 {cleared_count} 只股票的K线数据")
            
            # 清空信号数据
            redis_cache.redis_client.delete(STOCK_KEYS['strategy_signals'])
            logger.info("已清空策略信号数据")
        
        # 统一的后台任务处理函数
        def run_background_tasks():
            """运行后台任务：K线数据获取（可选）+ 信号计算等其他任务"""
            try:
                # 创建独立的事件循环用于后台任务
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                async def execute_tasks():
                    try:
                        # 根据模式决定是否获取K线数据
                        if mode == "full_init":
                            logger.info("开始重新获取所有股票和 ETF 历史数据...")
                            await _fetch_all_kline_data(stock_codes)
                            logger.info("K线数据获取完成")
                        elif mode == "tasks_only":
                            logger.info("tasks_only模式：跳过K线数据获取")
                        
                        # 所有模式都执行信号计算等其他任务
                        logger.info("开始计算买入信号（股票+ETF）...")
                        await _calculate_signals_async()
                        logger.info("买入信号计算完成")
                        
                    except Exception as e:
                        logger.error(f"后台任务执行失败: {e}")
                
                loop.run_until_complete(execute_tasks())
            except Exception as e:
                logger.error(f"后台线程执行失败: {e}")
            finally:
                try:
                    loop.close()
                except Exception:
                    pass
        
        # 启动后台任务线程
        task_thread = threading.Thread(target=run_background_tasks, daemon=True)
        task_thread.start()
        
        execution_time = (datetime.now() - start_time).total_seconds()
        if mode == "full_init":
            logger.info(f"full_init模式启动完成，K线数据获取和信号计算正在后台执行，耗时 {execution_time:.2f}秒")
            add_stock_job_log('init_system', 'success', f'full_init模式启动: {len(stock_codes)}只股票+ETF', len(stock_codes), execution_time)
        elif mode == "tasks_only":
            logger.info(f"tasks_only模式启动完成，信号计算等任务正在后台执行，耗时 {execution_time:.2f}秒")
            add_stock_job_log('init_system', 'success', f'tasks_only模式启动: {len(stock_codes)}只股票+ETF', len(stock_codes), execution_time)
            
        
    except Exception as e:
        execution_time = (datetime.now() - start_time).total_seconds()
        error_msg = f'股票系统初始化失败: {str(e)}'
        logger.error(f" {error_msg}")
        add_stock_job_log('init_system', 'failed', error_msg, 0, execution_time)

def clear_and_refetch_kline_data():
    """清空并重新获取所有股票K线数据（每天17:30执行）"""
    current_time = datetime.now()
    logger.info(f"========== 17:30定时任务触发 ==========")
    logger.info(f"当前时间: {current_time.strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"星期: {current_time.strftime('%A')}")
    
    if not is_trading_day():
        logger.info("⚠️ 非交易日，跳过K线数据更新")
        add_stock_job_log('clear_refetch', 'skipped', '非交易日跳过', 0, 0)
        return
    
    start_time = datetime.now()
    
    try:
        logger.info("✅ 交易日确认，开始执行K线数据全量更新任务...")
        logger.info("步骤 1/4: 获取股票列表")
        
        # 获取股票列表
        stock_codes = redis_cache.get_cache(STOCK_KEYS['stock_codes'])
        if not stock_codes:
            logger.error("❌ 股票代码列表为空，请先执行股票代码初始化")
            raise Exception("股票代码列表为空，请先执行股票代码初始化")
        
        logger.info(f"✅ 获取到 {len(stock_codes)} 只股票")
        
        # 清空所有K线数据 - 使用更安全的清空方式
        logger.info("步骤 2/4: 清空所有K线数据（包括新旧格式）")
        cleared_count = 0
        old_format_cleared = 0
        new_format_cleared = 0
        
        for stock in stock_codes:
            ts_code = stock.get('ts_code')
            if ts_code:
                # 使用两种键格式确保完全清空
                key1 = STOCK_KEYS['stock_kline'].format(ts_code)  # 旧格式
                key2 = f"stock_trend:{ts_code}"  # 新格式
                
                # 删除旧格式键
                if redis_cache.redis_client.delete(key1):
                    old_format_cleared += 1
                    cleared_count += 1
                    
                # 删除新格式键
                if redis_cache.redis_client.delete(key2):
                    new_format_cleared += 1
                    
        logger.info(f"✅ 已清空K线数据:")
        logger.info(f"   - 旧格式: {old_format_cleared} 只")
        logger.info(f"   - 新格式: {new_format_cleared} 只")
        logger.info(f"   - 总计: {cleared_count} 只")
        
        # 清空信号数据（重要：避免基于旧数据的信号残留）
        logger.info("步骤 3/4: 清空策略信号数据")
        redis_cache.redis_client.delete(STOCK_KEYS['strategy_signals'])
        logger.info("✅ 已清空策略信号数据")
        
        # 重新获取K线数据
        logger.info("步骤 4/4: 重新获取所有股票K线数据")
        logger.info(f"   预计需要时间: {len(stock_codes) * 0.5 / 60:.1f} 分钟")
        
        def run_async_fetch():
            """在新线程中运行异步获取"""
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                logger.info("🔄 异步数据获取任务启动...")
                loop.run_until_complete(_fetch_all_kline_data(stock_codes))
                logger.info("✅ 异步数据获取任务完成")
            except Exception as e:
                logger.error(f"❌ 异步数据获取任务失败: {str(e)}")
                import traceback
                logger.error(traceback.format_exc())
            finally:
                loop.close()
        
        # 在新线程中执行异步任务
        fetch_thread = threading.Thread(target=run_async_fetch, daemon=True)
        fetch_thread.start()
        logger.info("⏳ 等待数据获取完成（最长1小时）...")
        fetch_thread.join(timeout=3600)  # 最多等待1小时
        
        if fetch_thread.is_alive():
            logger.warning("⚠️ 数据获取任务超时（1小时），但任务仍在后台继续执行")
        
        execution_time = (datetime.now() - start_time).total_seconds()
        logger.info(f"✅ K线数据全量更新完成，耗时 {execution_time:.2f}秒 ({execution_time/60:.1f}分钟)")
        
        add_stock_job_log('clear_refetch', 'success', f'K线数据全量更新完成: {len(stock_codes)}只', len(stock_codes), execution_time)
        
        # K线全量更新完成后，自动触发买入信号计算
        logger.info("🔄 K线数据全量更新完成，自动触发买入信号重新计算...")
        _trigger_signal_recalculation_async()
        logger.info("========== 17:30定时任务完成 ==========")
        
    except Exception as e:
        execution_time = (datetime.now() - start_time).total_seconds()
        error_msg = f'K线数据全量更新失败: {str(e)}'
        logger.error(f"❌ {error_msg}")
        import traceback
        logger.error(f"详细错误:\n{traceback.format_exc()}")
        add_stock_job_log('clear_refetch', 'failed', error_msg, 0, execution_time)
        logger.info("========== 17:30定时任务失败 ==========")

async def _fetch_all_kline_data(stock_codes: List[Dict]):
    """异步获取所有股票K线数据"""
    # 创建股票数据管理器，使用配置文件中的多线程设置
    stock_data_manager = StockDataManager()
    await stock_data_manager.initialize()
    
    try:
        success_count = 0
        failed_count = 0
        batch_size = 10  # 减小批处理大小，避免阻塞API服务
        
        total_batches = (len(stock_codes) + batch_size - 1) // batch_size
        
        for i in range(0, len(stock_codes), batch_size):
            batch = stock_codes[i:i + batch_size]
            current_batch = i // batch_size + 1
            
            logger.info(f" 处理第 {current_batch}/{total_batches} 批股票 ({len(batch)} 只)")
            
            # 串行处理以避免占用过多资源影响API服务
            for j, stock in enumerate(batch):
                try:
                    thread_id = f"batch_{current_batch}_stock_{j}" if stock_data_manager.use_multithreading else None
                    result = await _fetch_single_stock_data(stock_data_manager, stock, thread_id)
                    
                    if isinstance(result, Exception):
                        failed_count += 1
                    elif result:
                        success_count += 1
                    else:
                        failed_count += 1
                        
                    # 根据后台任务优先级设置休息时间
                    if settings.BACKGROUND_TASK_PRIORITY == "low":
                        await asyncio.sleep(0.5)  # 低优先级：更多休息时间
                    elif settings.BACKGROUND_TASK_PRIORITY == "normal":
                        await asyncio.sleep(0.2)  # 正常优先级
                    else:  # high priority
                        await asyncio.sleep(0.1)  # 高优先级：最少休息时间
                        
                except Exception as e:
                    logger.error(f"处理股票异常: {e}")
                    failed_count += 1
            
            logger.info(f" 第 {current_batch} 批完成 | 总计成功: {success_count}, 失败: {failed_count}")
            
            # 批次间休息，避免频率限制，同时释放资源给API服务
            await asyncio.sleep(2)
        
        logger.info(f" K线数据获取完成: 成功 {success_count} 只, 失败 {failed_count} 只")
        
    finally:
        await stock_data_manager.close()

async def _fetch_single_stock_data(manager: StockDataManager, stock: Dict, thread_id: str = None) -> bool:
    """获取单只股票数据"""
    try:
        ts_code = stock.get('ts_code')
        if not ts_code:
            logger.warning(f" 股票数据缺少ts_code: {stock}")
            return False
        
        # 根据配置决定是否使用线程控制
        if manager.use_multithreading and thread_id:
            logger.debug(f"[{thread_id}] 开始获取股票数据")
            success = await manager.update_stock_trend_data(ts_code, days=180)
        else:
            # 直接获取数据
            success = await manager.update_stock_trend_data(ts_code, days=180)
        
        if success:
            logger.debug(f" {ts_code} 数据获取成功")
            return True
        else:
            logger.warning(f" {ts_code} 数据获取失败：无法获取历史数据")
            return False
        
    except Exception as e:
        # 改为warning级别，这样能看到错误信息
        logger.warning(f" 获取 {stock.get('ts_code', 'unknown')} 数据失败: {e}")
        return False

def calculate_strategy_signals():
    """计算策略买入信号（交易时间内每30分钟执行，15:00后额外执行）"""
    if not is_trading_day():
        logger.info("非交易日，跳过策略信号计算")
        return

    start_time = datetime.now()
    
    try:
        logger.info(" 开始计算策略买入信号...")
        
        def run_async_calc():
            """在新线程中运行异步计算"""
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                loop.run_until_complete(_calculate_signals_async())
            finally:
                loop.close()
        
        # 在新线程中执行异步任务，不等待完成
        calc_thread = threading.Thread(target=run_async_calc, daemon=True)
        calc_thread.start()
        # 不等待线程完成，避免阻塞主进程
        
        execution_time = (datetime.now() - start_time).total_seconds()
        logger.info(f" 策略信号计算完成，耗时 {execution_time:.2f}秒")
        
        add_stock_job_log('calc_signals', 'success', '策略信号计算完成', 0, execution_time)
        
    except Exception as e:
        execution_time = (datetime.now() - start_time).total_seconds()
        error_msg = f'策略信号计算失败: {str(e)}'
        logger.error(f" {error_msg}")
        add_stock_job_log('calc_signals', 'failed', error_msg, 0, execution_time)

async def _calculate_signals_async(etf_only: bool = False, stock_only: bool = False, clear_existing: bool = True):
    """
    异步计算信号
    
    Args:
        etf_only: 是否仅计算 ETF 信号（True=仅ETF, False=全部或仅股票）
        stock_only: 是否仅计算股票信号（True=仅股票, False=全部或仅ETF）
        clear_existing: 是否清空现有信号（默认True，追加模式设为False）
    """
    from app.services.signal_manager import SignalManager
    
    local_signal_manager = None
    try:
        local_signal_manager = SignalManager()
        await local_signal_manager.initialize()
        result = await local_signal_manager.calculate_buy_signals(
            force_recalculate=True,
            etf_only=etf_only,
            stock_only=stock_only,
            clear_existing=clear_existing
        )
        
        if result.get('status') == 'success':
            total_signals = result.get('total_signals', 0)
            if etf_only:
                signal_type = "ETF"
            elif stock_only:
                signal_type = "股票"
            else:
                signal_type = "股票+ETF"
            mode = "追加" if not clear_existing else "重新计算"
            logger.info(f"✅ {signal_type}买入信号{mode}完成: 生成 {total_signals} 个信号")
        else:
            logger.warning(f"❌ 买入信号计算失败: {result.get('message', '未知错误')}")
            
    except Exception as e:
        logger.error(f" 买入信号计算异常: {e}")
    finally:
        if local_signal_manager:
            try:
                await local_signal_manager.close()
            except Exception as e:
                logger.error(f"SignalManager关闭失败: {e}")

# 已删除calculate_final_strategy_signals函数，因为实时更新已延长到15:20
# 在K线全量更新和实时更新时会自动触发买入信号计算

def update_realtime_stock_data(force_update=False, is_closing_update=False, auto_calculate_signals=False):
    """更新实时股票数据（交易时间内每20分钟执行）
    
    Args:
        force_update: 是否强制更新，忽略交易时间检查
        is_closing_update: 是否为收盘后更新，使用不同的数据源
        auto_calculate_signals: 是否自动计算买入信号
    """
    if not force_update and not is_trading_time():
        logger.info("非交易时间，跳过实时数据更新")
        return

    start_time = datetime.now()
    
    try:
        if is_closing_update:
            logger.info(" 开始更新收盘股票数据（使用收盘价）...")
        else:
            logger.info(" 开始更新实时股票数据...")
        
        # 获取A股实时行情数据
        df = ak.stock_zh_a_spot_em()
        
        if df.empty:
            raise Exception("获取实时数据失败")
        
        # 转换数据格式
        realtime_data = []
        for _, row in df.iterrows():
            stock_data = {
                'code': row['代码'],
                'name': row['名称'],
                'price': float(row['最新价']) if pd.notna(row['最新价']) else 0,
                'change': float(row['涨跌额']) if pd.notna(row['涨跌额']) else 0,
                'change_percent': float(row['涨跌幅']) if pd.notna(row['涨跌幅']) else 0,
                'volume': float(row['成交量']) if pd.notna(row['成交量']) else 0,
                'amount': float(row['成交额']) if pd.notna(row['成交额']) else 0,
                'high': float(row['最高']) if pd.notna(row['最高']) else 0,
                'low': float(row['最低']) if pd.notna(row['最低']) else 0,
                'open': float(row['今开']) if pd.notna(row['今开']) else 0,
                'pre_close': float(row['昨收']) if pd.notna(row['昨收']) else 0,
                'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            realtime_data.append(stock_data)
        
        # 存储到Redis
        redis_cache.set_cache(STOCK_KEYS['realtime_data'], {
            'data': realtime_data,
            'count': len(realtime_data),
            'update_time': datetime.now().isoformat(),
            'data_source': 'akshare',
            'is_closing_data': is_closing_update
        }, ttl=1800)  # 30分钟过期
        
        # 新增：将实时数据合并到K线数据的最后一根K线
        logger.info("开始将实时数据合并到K线数据...")
        updated_kline_count = _merge_realtime_to_kline_data(realtime_data, is_closing_update=is_closing_update)
        logger.info(f" 已更新 {updated_kline_count} 只股票的K线数据")
        
        execution_time = (datetime.now() - start_time).total_seconds()
        logger.info(f" 实时数据更新完成: {len(realtime_data)}只股票，K线更新: {updated_kline_count}只，耗时 {execution_time:.2f}秒")
        
        add_stock_job_log('update_realtime', 'success', f'实时数据更新完成: {len(realtime_data)}只，K线更新: {updated_kline_count}只', len(realtime_data), execution_time)
        
        # 根据参数决定是否触发信号重新计算
        if auto_calculate_signals:
            logger.info("实时数据更新完成，自动触发买入信号重新计算...")
            _trigger_signal_recalculation_async()
        else:
            logger.info("实时数据更新完成，跳过信号计算（未启用auto_calculate_signals）")
        
    except Exception as e:
        execution_time = (datetime.now() - start_time).total_seconds()
        error_msg = f'实时数据更新失败: {str(e)}'
        logger.error(f" {error_msg}")
        add_stock_job_log('update_realtime', 'failed', error_msg, 0, execution_time)

def _merge_realtime_to_kline_data(realtime_data: List[Dict], is_closing_update=False) -> int:
    """将实时数据合并到K线数据的最后一根K线
    
    修复BUG: 确保字段格式统一，避免历史数据和实时数据字段冲突
    
    Args:
        realtime_data: 实时数据列表
        is_closing_update: 是否为收盘后更新，收盘后更新会强制更新价格
    
    Returns:
        更新的股票数量
    """
    updated_count = 0
    today_str = datetime.now().strftime('%Y-%m-%d')
    today_trade_date = datetime.now().strftime('%Y%m%d')
    
    try:
        for stock_data in realtime_data:
            try:
                stock_code = stock_data['code']
                
                # 构造ts_code
                if stock_code.startswith('6'):
                    ts_code = f"{stock_code}.SH"
                elif stock_code.startswith(('43', '83', '87', '88')):
                    ts_code = f"{stock_code}.BJ"
                else:
                    ts_code = f"{stock_code}.SZ"
                
                # 获取K线数据
                kline_key = STOCK_KEYS['stock_kline'].format(ts_code)
                kline_data = redis_cache.get_cache(kline_key)
                
                if not kline_data:
                    continue
                
                # 解析K线数据，处理不同的存储格式
                if isinstance(kline_data, dict):
                    trend_data = kline_data
                elif isinstance(kline_data, str):
                    trend_data = json.loads(kline_data)
                else:
                    trend_data = kline_data
                
                # 处理不同的数据格式
                if isinstance(trend_data, dict):
                    # 新格式：{data: [...], updated_at: ..., source: ...}
                    kline_list = trend_data.get('data', [])
                elif isinstance(trend_data, list):
                    # 旧格式：直接是K线数据列表
                    kline_list = trend_data
                    # 为了后续更新操作，需要包装成字典格式
                    trend_data = {
                        'data': kline_list,
                        'updated_at': datetime.now().isoformat(),
                        'data_count': len(kline_list),
                        'source': 'legacy_format'
                    }
                else:
                    continue
                
                if not kline_list:
                    continue
                
                # 关键修复：统一字段格式，避免字段冲突
                logger.debug(f"开始处理 {ts_code} 的字段格式统一...")
                
                # 统一历史数据的字段格式
                for i, kline in enumerate(kline_list):
                    # 确保所有历史数据都有统一的字段格式（tushare格式）
                    if 'ts_code' not in kline:
                        kline['ts_code'] = ts_code
                    
                    # 确保有trade_date字段
                    if 'trade_date' not in kline and 'date' in kline:
                        # 如果只有date字段，转换为trade_date
                        date_val = kline['date']
                        if isinstance(date_val, str) and len(date_val) == 10:  # YYYY-MM-DD格式
                            kline['trade_date'] = date_val.replace('-', '')
                        else:
                            kline['trade_date'] = str(date_val).replace('-', '')
                    
                    # 确保有actual_trade_date字段
                    if 'actual_trade_date' not in kline:
                        trade_date = kline.get('trade_date', '')
                        if len(str(trade_date)) == 8:
                            kline['actual_trade_date'] = f"{trade_date[:4]}-{trade_date[4:6]}-{trade_date[6:8]}"
                        else:
                            kline['actual_trade_date'] = today_str
                    
                    # 关键修复：移除实时更新字段，保持历史数据格式纯净
                    # 移除实时更新相关的额外字段，保持tushare格式的纯净性
                    historical_fields = ['ts_code', 'trade_date', 'open', 'high', 'low', 'close', 
                                       'pre_close', 'change', 'pct_chg', 'vol', 'amount', 'actual_trade_date']
                    
                    # 如果是前120条历史数据，确保只保留历史字段
                    if i < len(kline_list) - 1:  # 非最后一条数据
                        # 保留当前所有字段但确保必要字段存在
                        for field in historical_fields:
                            if field not in kline:
                                if field == 'vol' and 'volume' in kline:
                                    kline['vol'] = kline['volume']
                                elif field in ['change', 'pre_close', 'pct_chg'] and field not in kline:
                                    kline[field] = 0.0  # 默认值
                        
                        # 移除可能干扰的字段（只在历史数据中移除）
                        fields_to_remove = ['date', 'volume', 'turnover_rate', 'is_realtime_updated', 
                                          'update_time', 'realtime_source', 'realtime_volume_source']
                        for field in fields_to_remove:
                            if field in kline:
                                del kline[field]
                
                # 检查最后一根K线是否是今天的数据
                last_kline = kline_list[-1]
                last_trade_date = str(last_kline.get('trade_date', ''))
                last_date = last_kline.get('actual_trade_date', last_kline.get('date', ''))
                
                # 实时数据中的成交量数据处理
                current_volume = stock_data.get('volume', 0)
                if current_volume == 0:
                    # 如果实时成交量为0，尝试从其他字段获取
                    current_volume = stock_data.get('vol', 0)
                
                # 调试日志：记录成交量数据
                if current_volume > 0:
                    logger.debug(f"{ts_code} 实时成交量: {current_volume} (原始值), 转换后: {current_volume / 100} 手")
                
                # 确保成交量数据有效
                if current_volume is None or current_volume < 0:
                    current_volume = 0
                
                # 关键修复：今日数据处理策略
                if last_trade_date != today_trade_date and last_date != today_str:
                    # 如果最后一根K线不是今天的，追加今天的新K线
                    # 使用统一的tushare格式
                    new_kline = {
                        'ts_code': ts_code,
                        'trade_date': today_trade_date,
                        'open': stock_data['open'],
                        'high': stock_data['high'],
                        'low': stock_data['low'],
                        'close': stock_data['price'],  # 当前价格作为收盘价
                        'pre_close': stock_data['pre_close'],
                        'change': stock_data['change'],
                        'pct_chg': stock_data['change_percent'],
                        'vol': current_volume / 100 if current_volume > 100 else current_volume,  # 统一为手单位
                        'amount': stock_data['amount'] / 1000 if stock_data['amount'] > 1000 else stock_data['amount'],  # 统一为千元单位
                        'actual_trade_date': today_str,
                        'is_closing_data': is_closing_update,  # 标记是否为收盘数据
                        'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    }
                    kline_list.append(new_kline)
                    logger.debug(f"为 {ts_code} 追加今日K线: {today_str}, 历史数据: {len(kline_list)-1}条, 使用tushare格式")
                else:
                    # 关键修复：更新最后一根K线，但保持tushare格式
                    # 保留原有的成交量，如果实时成交量更大则更新
                    existing_volume = float(last_kline.get('vol', 0))
                    
                    # 成交量采用累积策略：优先使用更大的值，保证数据的准确性
                    current_volume_in_hands = current_volume / 100  # 转换为手数
                    
                    # 如果实时成交量大于0，使用实时数据；否则保留历史数据
                    if current_volume > 0:
                        final_volume = max(existing_volume, current_volume_in_hands)
                    else:
                        final_volume = existing_volume  # 保持原有成交量
                    
                    # 记录成交量更新情况
                    if current_volume > 0 and final_volume != existing_volume:
                        logger.debug(f"{ts_code} 成交量更新: {existing_volume} -> {final_volume} 手")
                    
                    # 如果是收盘后更新，强制更新价格和其他数据
                    if is_closing_update:
                        logger.debug(f" 收盘后更新 {ts_code} 的价格数据: {stock_data['price']}")
                        # 更新最后一根K线，但严格保持tushare字段格式
                        last_kline.update({
                            'ts_code': ts_code,  # 确保有ts_code
                            'trade_date': today_trade_date,  # 确保trade_date格式正确
                            'high': max(float(last_kline.get('high', 0)), stock_data['high']),
                            'low': min(float(last_kline.get('low', float('inf'))), stock_data['low']) if float(last_kline.get('low', float('inf'))) != float('inf') else stock_data['low'],
                            'close': stock_data['price'],  # 当前价格作为收盘价
                            'pre_close': stock_data['pre_close'],
                            'change': stock_data['change'],
                            'pct_chg': stock_data['change_percent'],
                            'vol': final_volume,  # 使用统一的手单位
                            'amount': stock_data['amount'] / 1000,  # 使用统一的千元单位
                            'actual_trade_date': today_str,
                            'is_closing_data': True,  # 标记为收盘数据
                            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                        })
                    else:
                        # 交易时间内的更新，只有当前价格高于最高价或低于最低价时才更新
                        current_high = max(float(last_kline.get('high', 0)), stock_data['high'])
                        current_low = min(float(last_kline.get('low', float('inf'))), stock_data['low']) if float(last_kline.get('low', float('inf'))) != float('inf') else stock_data['low']
                        
                        # 更新最后一根K线，但严格保持tushare字段格式
                        last_kline.update({
                            'ts_code': ts_code,  # 确保有ts_code
                            'trade_date': today_trade_date,  # 确保trade_date格式正确
                            'high': current_high,
                            'low': current_low,
                            'close': stock_data['price'],  # 当前价格作为收盘价
                            'pre_close': stock_data['pre_close'],
                            'change': stock_data['change'],
                            'pct_chg': stock_data['change_percent'],
                            'vol': final_volume,  # 使用统一的手单位
                            'amount': stock_data['amount'] / 1000,  # 使用统一的千元单位
                            'actual_trade_date': today_str,
                            'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                        })
                    
                    # 关键修复：移除实时更新字段，保持格式统一
                    # 移除所有实时更新相关字段，确保格式统一
                    realtime_fields_to_remove = ['date', 'volume', 'turnover_rate', 'is_realtime_updated', 
                                                'realtime_source', 'realtime_volume_source']
                    for field in realtime_fields_to_remove:
                        if field in last_kline:
                            del last_kline[field]
                    
                    if is_closing_update:
                        logger.debug(f"收盘后更新 {ts_code} 最后一根K线: 收盘价 {stock_data['price']}, 成交量: {final_volume}手")
                    else:
                        logger.debug(f"更新 {ts_code} 最后一根K线: 收盘价 {stock_data['price']}, 成交量: {final_volume}手, 保持tushare格式")
                
                # 最终验证：确保所有数据都有统一的字段格式
                logger.debug(f"{ts_code} 字段格式验证...")
                for i, kline in enumerate(kline_list):
                    # 确保每条记录都有必要的tushare字段
                    required_fields = ['ts_code', 'trade_date', 'open', 'high', 'low', 'close', 
                                     'pre_close', 'change', 'pct_chg', 'vol', 'amount', 'actual_trade_date']
                    
                    for field in required_fields:
                        if field not in kline:
                            # 填充默认值
                            if field == 'ts_code':
                                kline[field] = ts_code
                            elif field in ['change', 'pre_close', 'pct_chg']:
                                kline[field] = 0.0
                            elif field in ['vol', 'amount']:
                                kline[field] = 0.0
                            elif field == 'actual_trade_date':
                                trade_date = kline.get('trade_date', today_trade_date)
                                if len(str(trade_date)) == 8:
                                    kline[field] = f"{trade_date[:4]}-{trade_date[4:6]}-{trade_date[6:8]}"
                                else:
                                    kline[field] = today_str
                
                # 更新trend_data的元数据
                trend_data.update({
                    'data': kline_list,
                    'updated_at': datetime.now().isoformat(),
                    'data_count': len(kline_list),
                    'last_update_type': 'closing_update' if is_closing_update else 'realtime_update'
                })
                
                # 更新Redis缓存
                redis_cache.set_cache(kline_key, trend_data, ttl=None)  # 永久存储
                
                # 同时更新实时价格缓存（用于信号计算）
                realtime_price_key = f"stocks:realtime:{ts_code}"
                realtime_price_data = {
                    'price': stock_data['price'],
                    'change': stock_data['change'],
                    'pct_chg': stock_data['change_percent'],
                    'volume': stock_data['volume'],
                    'amount': stock_data['amount'],
                    'high': stock_data['high'],
                    'low': stock_data['low'],
                    'open': stock_data['open'],
                    'pre_close': stock_data['pre_close'],
                    'update_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'is_closing_data': is_closing_update
                }
                redis_cache.set_cache(realtime_price_key, json.dumps(realtime_price_data), ttl=3600)  # 1小时过期
                
                updated_count += 1
                
            except Exception as e:
                logger.error(f"处理股票 {stock_data.get('code', 'unknown')} 的实时数据失败: {str(e)}")
                continue
                
        return updated_count
        
    except Exception as e:
        logger.error(f"合并实时数据到K线数据失败: {str(e)}")
        return 0

def _trigger_signal_recalculation_async():
    """异步触发买入信号重新计算（非阻塞，防重复执行）"""
    global _signal_calculation_running
    
    # 检查是否已有信号计算任务在运行
    with _signal_calculation_lock:
        if _signal_calculation_running:
            logger.info(" 买入信号计算任务已在运行中，跳过本次触发")
            return
        _signal_calculation_running = True
    
    try:
        import concurrent.futures
        
        def _run_signal_calculation():
            """在独立线程中运行信号计算"""
            global _signal_calculation_running
            try:
                async def _calculate():
                    # 在新事件循环中创建新的signal_manager实例，避免事件循环冲突
                    from app.services.signal_manager import SignalManager
                    
                    local_signal_manager = None
                    try:
                        local_signal_manager = SignalManager()
                        await local_signal_manager.initialize()
                        logger.info("开始重新计算买入信号...")
                        
                        result = await local_signal_manager.calculate_buy_signals(force_recalculate=True)
                        
                        if result.get('status') == 'success':
                            total_signals = result.get('total_signals', 0)
                            elapsed = result.get('elapsed_seconds', 0)
                            logger.info(f" 买入信号重新计算完成: 生成 {total_signals} 个信号，耗时 {elapsed:.1f}秒")
                        else:
                            logger.warning(f" 买入信号重新计算失败: {result.get('message', '未知错误')}")
                            
                    except Exception as e:
                        logger.error(f"计算买入信号失败: {e}")
                        logger.error(f"详细错误: {traceback.format_exc()}")
                    finally:
                        if local_signal_manager:
                            try:
                                await local_signal_manager.close()
                            except Exception as e:
                                logger.error(f"SignalManager关闭失败: {e}")
                
                # 在新线程中创建新的事件循环
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                try:
                    loop.run_until_complete(_calculate())
                finally:
                    loop.close()
                
            except Exception as e:
                logger.error(f" 信号计算线程执行失败: {e}")
            finally:
                # 重置运行标志
                with _signal_calculation_lock:
                    _signal_calculation_running = False
        
        # 使用线程池执行，避免阻塞主流程
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            executor.submit(_run_signal_calculation)
            
    except Exception as e:
        logger.error(f" 触发异步信号计算失败: {e}")
        # 重置运行标志
        with _signal_calculation_lock:
            _signal_calculation_running = False

# ===================== 调度器管理 =====================

def start_stock_scheduler():
    """启动股票调度器"""
    global scheduler
    
    if scheduler and scheduler.running:
        logger.warning(" 股票调度器已经在运行中")
        return
    
    try:
        # 创建后台调度器
        scheduler = BackgroundScheduler(
            timezone='Asia/Shanghai',
            job_defaults={
                'coalesce': True,  # 合并未执行的任务
                'max_instances': 1,  # 同时只运行一个实例
                'misfire_grace_time': 300  # 5分钟的容错时间
            }
        )
        
        # 1. 系统启动完成，等待用户选择初始化方式
        logger.info(" 股票调度器启动完成，等待用户选择初始化方式...")
        logger.info("请使用API手动触发初始化:")
        logger.info("   • 清空重新初始化: POST /api/stocks/scheduler/init?clear_data=true")
        logger.info("   • 跳过清空检查现有数据: POST /api/stocks/scheduler/init?clear_data=false")
        
        # 2. K线数据全量更新任务 - 每个交易日17:30执行（收盘后获取完整数据）
        # 使用非阻塞的后台线程执行，避免阻塞API服务
        def non_blocking_kline_refresh():
            """非阻塞的K线数据刷新"""
            threading.Thread(target=clear_and_refetch_kline_data, daemon=True).start()
            
        scheduler.add_job(
            func=non_blocking_kline_refresh,
            trigger=CronTrigger(hour=17, minute=30, second=0, day_of_week='mon-fri'),
            id='daily_kline_refresh',
            name='每日K线数据全量刷新（非阻塞）',
            replace_existing=True
        )
        
        # 3. 实时数据更新任务 - 交易时间内每20分钟执行（包含收盘后20分钟）
        # 使用非阻塞的后台线程执行，避免阻塞API服务
        def non_blocking_realtime_update():
            """非阻塞的实时数据更新"""
            def run_update():
                update_realtime_stock_data(auto_calculate_signals=True)
            threading.Thread(target=run_update, daemon=True).start()
            
        scheduler.add_job(
            func=non_blocking_realtime_update,
            trigger=CronTrigger(minute='0,20,40', second=0, hour='9-11,13-15', day_of_week='mon-fri'),
            id='realtime_data_update',
            name='实时数据更新+信号计算（非阻塞）',
            replace_existing=True
        )
        
        # 已删除15:05收盘数据更新任务，因为实时更新已延长到15:20，覆盖了收盘时间
        
        # 删除原有的17:35最终信号计算任务，因为实时更新已延长到15:20
        # 在K线全量更新后会自动触发信号计算
        
        # 启动调度器
        scheduler.start()
        
        logger.info("=" * 70)
        logger.info(" 股票调度器启动成功")
        logger.info("=" * 70)
        logger.info("定时任务配置:")
        logger.info("  • K线数据刷新: 每个交易日17:30 (自动触发信号计算)")
        logger.info("  • 实时数据更新: 交易时间内每20分钟 (9:00-11:30, 13:00-15:20)")
        logger.info("  • 已删除: 15:05收盘数据更新任务（实时更新已覆盖）")
        logger.info("  • 重要改进: 实时更新延长到15:20，确保收盘价格被捕获")
        logger.info("  • 已删除: 17:35最终信号计算任务")
        logger.info("")
        logger.info("已注册的定时任务:")
        jobs = scheduler.get_jobs()
        for job in jobs:
            next_run = job.next_run_time.strftime('%Y-%m-%d %H:%M:%S') if job.next_run_time else "未安排"
            logger.info(f"  • {job.name} (ID: {job.id})")
            logger.info(f"    - 下次执行: {next_run}")
            logger.info(f"    - 触发器: {job.trigger}")
        logger.info("")
        logger.info("启动完成: 等待用户选择初始化方式")
        logger.info("=" * 70)
        
    except Exception as e:
        logger.error(f" 启动股票调度器失败: {str(e)}")

def stop_stock_scheduler():
    """停止股票调度器"""
    global scheduler
    
    if scheduler and scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("股票调度器已停止")
    else:
        logger.info("股票调度器未运行")

def get_stock_scheduler_status() -> Dict[str, Any]:
    """获取股票调度器状态"""
    global scheduler, job_logs
    
    try:
        if not scheduler:
            return {
                'running': False,
                'error': '调度器未初始化'
            }
        
        # 获取任务信息
        jobs_info = []
        if scheduler.running:
            for job in scheduler.get_jobs():
                next_run = job.next_run_time
                jobs_info.append({
                    'id': job.id,
                    'name': job.name,
                    'next_run': next_run.strftime('%Y-%m-%d %H:%M:%S') if next_run else None,
                    'trigger': str(job.trigger)
                })
        
        # 获取数据状态
        stock_codes = redis_cache.get_cache(STOCK_KEYS['stock_codes'])
        realtime_data = redis_cache.get_cache(STOCK_KEYS['realtime_data'])
        signals_data = redis_cache.get_cache(STOCK_KEYS['strategy_signals'])
        
        data_status = {
            'stock_codes': {
                'exists': stock_codes is not None,
                'count': len(stock_codes) if stock_codes else 0
            },
            'realtime_data': {
                'exists': realtime_data is not None,
                'count': realtime_data.get('count', 0) if realtime_data else 0,
                'last_update': realtime_data.get('update_time') if realtime_data else None
            },
            'strategy_signals': {
                'exists': signals_data is not None,
                'count': len(signals_data) if isinstance(signals_data, dict) else 0
            }
        }
        
        return {
            'running': scheduler.running if scheduler else False,
            'jobs': jobs_info,
            'recent_logs': job_logs[:5],  # 最近5次日志
            'data_status': data_status,
            'trading_status': {
                'is_trading_day': is_trading_day(),
                'is_trading_time': is_trading_time(),
                'current_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            },
            'scheduler_type': 'APScheduler V3 优化版',
            'description': '优化调度器，避免重复计算，20分钟更新周期，每日17:30全量刷新'
        }
        
    except Exception as e:
        return {
            'running': False,
            'error': str(e)
        }

def trigger_stock_task(task_type: str, mode: str = "only_tasks", is_closing_update: bool = False) -> Dict[str, Any]:
    """手动触发股票任务"""
    try:
        if task_type == 'init_system':
            threading.Thread(target=init_stock_system, args=(mode,), daemon=True).start()
            action_desc = {
                "clear_all": "清空所有数据重新获取 - 删除所有历史数据，重新获取",
                "only_tasks": "只执行计划任务 - 不获取K线数据，只执行信号计算、新闻获取等任务",
                "none": "不执行任何初始化 - 启动时什么都不执行"
            }.get(mode, f"未知模式: {mode}")
            
            return {
                'success': True,
                'message': f'股票系统初始化任务已触发: {action_desc}',
                'task_type': task_type,
                'mode': mode
            }
        elif task_type == 'clear_refetch':
            threading.Thread(target=clear_and_refetch_kline_data, daemon=True).start()
            return {
                'success': True,
                'message': 'K线数据全量刷新任务已触发',
                'task_type': task_type
            }
        elif task_type == 'calc_signals':
            threading.Thread(target=calculate_strategy_signals, daemon=True).start()
            return {
                'success': True,
                'message': '策略信号计算任务已触发',
                'task_type': task_type
            }
        elif task_type == 'update_realtime':
            # 使用参数控制是否为收盘更新
            threading.Thread(
                target=lambda: update_realtime_stock_data(force_update=True, is_closing_update=is_closing_update), 
                daemon=True
            ).start()
            
            update_type = "收盘价格" if is_closing_update else "实时价格"
            return {
                'success': True,
                'message': f'{update_type}更新任务已触发',
                'task_type': task_type,
                'is_closing_update': is_closing_update
            }
        else:
            return {
                'success': False,
                'message': f'未知任务类型: {task_type}',
                'task_type': task_type
            }
            
    except Exception as e:
        logger.error(f'股票任务触发失败: {str(e)}')
        return {'success': False, 'message': f'股票任务触发失败: {str(e)}', 'data': None}

def refresh_stock_list() -> Dict[str, Any]:
    """刷新股票列表（使用实时API获取完整列表）"""
    start_time = datetime.now()
    
    try:
        logger.info("📡 开始刷新股票列表（实时API）...")
        
        # 使用实时API获取最新股票列表
        df = ak.stock_zh_a_spot_em()
        
        if df.empty:
            raise Exception("获取股票列表失败")
        
        # 转换数据格式
        stock_codes = []
        for _, row in df.iterrows():
            code = row['代码']
            # 判断市场
            if code.startswith('6'):
                market = 'SH'
                ts_code = f"{code}.SH"
            elif code.startswith(('43', '83', '87', '88')):
                market = 'BJ'
                ts_code = f"{code}.BJ"
            else:
                market = 'SZ'
                ts_code = f"{code}.SZ"
            
            stock_data = {
                'code': code,
                'name': row['名称'],
                'ts_code': ts_code,
                'market': market
            }
            stock_codes.append(stock_data)
        
        # 存储到Redis
        redis_cache.set_cache(STOCK_KEYS['stock_codes'], stock_codes, ttl=86400)
        
        execution_time = (datetime.now() - start_time).total_seconds()
        logger.info(f" 股票列表刷新成功: {len(stock_codes)}只股票，耗时 {execution_time:.2f}秒")
        
        add_stock_job_log('refresh_stocks', 'success', f'股票列表刷新成功: {len(stock_codes)}只', len(stock_codes), execution_time)
        
        return {
            'success': True,
            'message': f'股票列表刷新成功: {len(stock_codes)}只股票',
            'data': {
                'count': len(stock_codes),
                'execution_time': execution_time,
                'updated_at': datetime.now().isoformat()
            }
        }
        
    except Exception as e:
        execution_time = (datetime.now() - start_time).total_seconds()
        error_msg = f'股票列表刷新失败: {str(e)}'
        logger.error(f" {error_msg}")
        
        add_stock_job_log('refresh_stocks', 'failed', error_msg, 0, execution_time)
        
        return {
            'success': False,
            'message': error_msg,
            'data': None
        } 