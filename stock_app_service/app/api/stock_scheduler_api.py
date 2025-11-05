# -*- coding: utf-8 -*-
"""股票数据调度器API路由"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from typing import Dict, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field

from app.core.logging import logger
from app.api.dependencies import verify_token
from app.services.scheduler.stock_scheduler import (
    get_stock_scheduler_status, 
    trigger_stock_task,
    STOCK_KEYS
)
from app.db.session import RedisCache

# Redis缓存客户端
redis_cache = RedisCache()

# 定义响应模型
class StockSchedulerResponse(BaseModel):
    success: bool = Field(..., description="是否成功")
    message: str = Field(..., description="消息")
    data: Optional[Dict[str, Any]] = Field(None, description="数据")

# 定义手动触发请求模型
class TriggerTaskRequest(BaseModel):
    task_type: str = Field(..., description="任务类型: init_system, clear_refetch, calc_signals, update_realtime")
    is_closing_update: bool = Field(False, description="是否为收盘数据更新（仅当task_type=update_realtime时有效）")

router = APIRouter(tags=["Stock Scheduler"])

@router.get(
    "/api/stocks/scheduler/status",
    dependencies=[Depends(verify_token)],
    response_model=StockSchedulerResponse,
    summary="获取股票调度器状态",
    description="""
    获取股票数据调度器的运行状态和统计信息。
    
    包含信息：
    - 调度器运行状态和定时任务配置
    - 股票代码数量和策略信号统计
    - 交易日和交易时间判断
    - 最近任务执行日志
    - 各类数据缓存状态
    
    🕐 定时任务说明：
    - 股票代码检查: 每周一8:00 + 启动时立即执行
    - K线数据获取: 每个工作日18:00
    - 策略信号计算: 交易时间内每30分钟
    - 实时数据更新: 交易时间内每5分钟
    """,
    response_description="返回调度器状态和执行统计"
)
async def get_stock_scheduler_status_api():
    """
    获取股票调度器状态
    
    提供完整的股票数据调度系统状态信息
    """
    try:
        status_data = get_stock_scheduler_status()
        
        return StockSchedulerResponse(
            success=True,
            message="获取股票调度器状态成功",
            data=status_data
        )
        
    except Exception as e:
        logger.error(f"获取股票调度器状态失败：{str(e)}")
        return StockSchedulerResponse(
            success=False,
            message=f"获取股票调度器状态失败：{str(e)}",
            data={"error": str(e)}
        )

@router.post(
    "/api/stocks/scheduler/init",
    dependencies=[Depends(verify_token)],
    response_model=StockSchedulerResponse,
    summary="初始化股票/ETF系统",
    description="""
    初始化股票和ETF系统数据，用户可选择不同的初始化模式。
    
    初始化模式：
    - **skip**: 跳过初始化 - 启动时什么都不执行，等待手动触发（推荐默认模式）
    - **tasks_only**: 仅执行任务 - 不获取历史K线数据，只执行信号计算、新闻获取等任务
    - **full_init**: 完整初始化 - 清空所有数据（股票+ETF）重新获取
    - **etf_only**: 仅初始化ETF - 只获取和更新ETF数据
    
    📋 执行内容：
    - 获取最新股票/ETF代码列表
    - 根据模式选择性清空或检查历史数据
    - 异步获取需要更新的股票/ETF历史数据
    - 计算买入信号
    
    执行方式：
    - 异步执行，立即返回
    - 可通过状态接口查看执行进度
    
    使用场景：
    - **skip**: 不执行任何初始化
    - **tasks_only**: 日常维护、快速启动、只执行信号计算和新闻获取等任务
    - **full_init**: 系统首次部署、数据问题、定期全量刷新（股票+ETF）
    - **etf_only**: 仅更新ETF数据和信号
    
    注意：为了向后兼容，仍然支持旧模式名称（none, only_tasks, clear_all）
    """,
    response_description="返回初始化结果"
)
async def init_stock_system_api(
    mode: str = Query("tasks_only", description="初始化模式: skip/tasks_only/full_init/etf_only（也支持旧名称: none/only_tasks/clear_all）")
):
    """
    初始化股票/ETF系统
    
    提供多种初始化模式，支持股票和ETF的灵活管理
    """
    try:
        # 验证模式参数（支持新旧模式名称）
        valid_modes = ["skip", "tasks_only", "full_init", "etf_only", "none", "only_tasks", "clear_all"]
        if mode not in valid_modes:
            return StockSchedulerResponse(
                success=False,
                message=f"无效的模式参数，支持的模式: {', '.join(valid_modes[:4])}（也支持旧名称: {', '.join(valid_modes[4:])}）",
                data=None
            )
        
        result = trigger_stock_task('init_system', mode=mode)
        
        return StockSchedulerResponse(
            success=result['success'],
            message=result['message'],
            data=result
        )
        
    except Exception as e:
        logger.error(f"初始化股票系统失败：{str(e)}")
        return StockSchedulerResponse(
            success=False,
            message=f"初始化股票系统失败：{str(e)}",
            data={"error": str(e)}
        )

@router.post(
    "/api/stocks/scheduler/trigger",
    dependencies=[Depends(verify_token)],
    response_model=StockSchedulerResponse,
    summary="手动触发股票任务",
    description="""
    手动触发股票数据处理任务，不影响定时调度。
    
    📋 可触发的任务类型：
    - **init_system**: 初始化股票系统（请使用专用初始化接口）
    - **clear_refetch**: 清空并重新获取所有K线数据（每日17:30定时任务）
    - **calc_signals**: 计算策略买入信号（每30分钟定时任务）
    - **update_realtime**: 更新实时股票数据（每15分钟定时任务）
    
    执行方式：
    - 异步执行，立即返回
    - 不阻塞其他请求
    - 可通过状态接口查看执行结果
    
    使用场景：
    - 手动触发定时任务（测试或应急）
    - 系统维护时的数据更新
    - 调试各个任务模块功能
    """,
    response_description="返回触发结果"
)
async def trigger_stock_task_api(request: TriggerTaskRequest):
    """
    手动触发股票任务
    
    支持触发不同类型的股票数据处理任务
    """
    try:
        result = trigger_stock_task(request.task_type, is_closing_update=request.is_closing_update)
        
        return StockSchedulerResponse(
            success=result['success'],
            message=result['message'],
            data=result
        )
        
    except Exception as e:
        logger.error(f"触发股票任务失败：{str(e)}")
        return StockSchedulerResponse(
            success=False,
            message=f"触发股票任务失败：{str(e)}",
            data={"error": str(e)}
        )

@router.get(
    "/api/stocks/codes",
    dependencies=[Depends(verify_token)],
    response_model=StockSchedulerResponse,
    summary="获取股票代码列表",
    description="""
    获取系统中缓存的股票代码列表。
    
    数据包含：
    - 股票代码 (ts_code)
    - 股票名称 (name) 
    - 交易所 (market)
    - 行业分类 (industry)
    - 地区信息 (area)
    
    💾 数据来源：
    - 优先使用Tushare数据源
    - 数据永久缓存在Redis中
    - 自动检查数据完整性（>=5000条）
    """,
    response_description="返回股票代码列表"
)
async def get_stock_codes():
    """
    获取股票代码列表
    
    从Redis缓存中获取所有股票代码信息
    """
    try:
        # 从Redis获取股票代码数据
        stock_codes = redis_cache.get_cache(STOCK_KEYS['stock_codes'])
        
        if not stock_codes:
            return StockSchedulerResponse(
                success=True,
                message="股票代码数据为空，请先触发初始化任务",
                data={
                    "codes": [],
                    "count": 0,
                    "status": "empty",
                    "suggestion": "调用 /api/stocks/scheduler/trigger 触发 check_codes 任务"
                }
            )
        
        # 返回股票代码数据
        return StockSchedulerResponse(
            success=True,
            message=f"获取股票代码成功，共 {len(stock_codes)} 只股票",
            data={
                "codes": stock_codes[:100],  # 只返回前100条，避免响应过大
                "total_count": len(stock_codes),
                "displayed_count": min(100, len(stock_codes)),
                "status": "success",
                "data_source": "redis_cache",
                "note": "为避免响应过大，仅显示前100条数据"
            }
        )
        
    except Exception as e:
        logger.error(f"获取股票代码失败：{str(e)}")
        return StockSchedulerResponse(
            success=False,
            message=f"获取股票代码失败：{str(e)}",
            data={"error": str(e)}
        )

@router.post(
    "/api/stocks/scheduler/refresh-stocks",
    dependencies=[Depends(verify_token)],
    response_model=StockSchedulerResponse,
    summary="刷新股票列表",
    description="""
    使用实时API刷新股票列表，获取最新的A股股票代码和名称。
    
    功能说明：
    - 调用akshare的stock_zh_a_spot_em()获取最新股票列表
    - 更新Redis缓存中的股票代码数据
    - 适用于定期更新股票列表或新股上市后的更新
    
    注意事项：
    - 该接口会进行网络请求，可能耗时较长
    - 建议在非交易时间进行，避免影响实时数据更新
    - 更新成功后，系统会自动使用新的股票列表
    
    使用场景：
    - 系统启动后，需要获取完整的股票列表
    - 定期更新股票代码（如每月一次）
    - 新股上市后更新股票列表
    """,
    response_description="返回股票列表刷新结果"
)
async def refresh_stock_list_api():
    """
    刷新股票列表
    
    使用实时API获取最新的股票代码列表并更新缓存
    """
    try:
        from app.services.scheduler.stock_scheduler import refresh_stock_list
        
        result = refresh_stock_list()
        
        return StockSchedulerResponse(
            success=result['success'],
            message=result['message'],
            data=result['data']
        )
        
    except Exception as e:
        logger.error(f"刷新股票列表失败：{str(e)}")
        return StockSchedulerResponse(
            success=False,
            message=f"刷新股票列表失败：{str(e)}",
            data={"error": str(e)}
        )

@router.get(
    "/api/stocks/batch-price",
    dependencies=[Depends(verify_token)],
    summary="批量获取股票价格信息",
    description="""
    批量获取股票的最新价格信息，基于最后一根K线数据。
    
    数据来源：
    - 从Redis中获取股票K线数据
    - 取最后一根K线作为最新价格
    - 避免实时API限流问题
    
    返回数据：
    - 股票代码和名称
    - 最新价格和涨跌幅
    - 成交量信息
    - 数据更新时间
    
    📋 参数格式：
    - codes: 股票代码列表，用逗号分隔
    - 示例: codes=000001,000002,300001
    
    优势：
    - 批量查询，提高效率
    - 基于K线数据，稳定可靠
    - 无API限流问题
    """,
    response_description="返回股票价格信息列表"
)
async def get_batch_stock_prices(
    codes: str = Query(..., description="股票代码列表，用逗号分隔，如：000001,000002,300001")
):
    """
    批量获取股票价格信息
    
    从Redis K线数据中获取最后一根K线作为最新价格信息
    """
    try:
        # 解析股票代码列表
        code_list = [code.strip() for code in codes.split(',') if code.strip()]
        
        if not code_list:
            return {
                "success": False,
                "message": "请提供有效的股票代码",
                "data": []
            }
        
        if len(code_list) > 50:
            return {
                "success": False,
                "message": "单次查询股票数量不能超过50只",
                "data": []
            }
        
        results = []
        redis_cache = RedisCache()
        
        # 获取股票代码列表，用于获取股票名称
        stock_codes = redis_cache.get_cache(STOCK_KEYS['stock_codes'])
        stock_name_map = {}
        
        if stock_codes:
            for stock in stock_codes:
                clean_code = stock.get('code', '').split('.')[0] if '.' in stock.get('code', '') else stock.get('code', '')
                stock_name_map[clean_code] = stock.get('name', '')
        
        for code in code_list:
            try:
                # 尝试不同的ts_code格式
                possible_ts_codes = []
                if code.startswith('6'):
                    possible_ts_codes = [f"{code}.SH"]
                elif code.startswith(('0', '3')):
                    possible_ts_codes = [f"{code}.SZ"]
                elif code.startswith(('43', '83', '87', '88')):
                    possible_ts_codes = [f"{code}.BJ"]
                else:
                    # 如果不确定，多个都试试
                    possible_ts_codes = [f"{code}.SH", f"{code}.SZ", f"{code}.BJ"]
                
                stock_data = None
                used_ts_code = None
                
                # 尝试获取K线数据
                for ts_code in possible_ts_codes:
                    kline_key = f"stock_trend:{ts_code}"
                    kline_data = redis_cache.get_cache(kline_key)
                    
                    if kline_data:
                        used_ts_code = ts_code
                        stock_data = kline_data
                        break
                
                if not stock_data:
                    # 没有找到K线数据
                    results.append({
                        "code": code,
                        "name": stock_name_map.get(code, "未知"),
                        "price": 0,
                        "change_percent": 0,
                        "volume": 0,
                        "update_time": None,
                        "status": "no_data",
                        "message": "暂无K线数据"
                    })
                    continue
                
                # 解析K线数据，处理不同的存储格式
                kline_list = []
                if isinstance(stock_data, dict):
                    # 新格式：{data: [...], updated_at: ..., source: ...}
                    kline_list = stock_data.get('data', [])
                elif isinstance(stock_data, list):
                    # 旧格式：直接是K线数据列表
                    kline_list = stock_data
                
                if not kline_list:
                    results.append({
                        "code": code,
                        "name": stock_name_map.get(code, "未知"),
                        "price": 0,
                        "change_percent": 0,
                        "volume": 0,
                        "update_time": None,
                        "status": "empty_data",
                        "message": "K线数据为空"
                    })
                    continue
                
                # 获取最后一根K线数据
                last_kline = kline_list[-1]
                
                # 提取价格信息
                price = float(last_kline.get('close', 0))
                open_price = float(last_kline.get('open', 0))
                volume = int(last_kline.get('volume', 0) or last_kline.get('vol', 0))
                
                # 计算涨跌幅
                change_percent = 0
                if 'pct_chg' in last_kline:
                    change_percent = float(last_kline['pct_chg'])
                elif open_price > 0:
                    # 如果没有pct_chg，用开盘价计算当日涨跌幅
                    change_percent = round((price - open_price) / open_price * 100, 2)
                
                # 获取日期信息
                update_time = None
                if 'date' in last_kline:
                    update_time = last_kline['date']
                elif 'trade_date' in last_kline:
                    trade_date = str(last_kline['trade_date'])
                    if len(trade_date) == 8:
                        # 格式：20241220 -> 2024-12-20
                        update_time = f"{trade_date[:4]}-{trade_date[4:6]}-{trade_date[6:8]}"
                    else:
                        update_time = trade_date
                
                results.append({
                    "code": code,
                    "name": stock_name_map.get(code, "未知"),
                    "price": round(price, 2),
                    "change_percent": round(change_percent, 2),
                    "volume": volume,
                    "update_time": update_time,
                    "status": "success",
                    "ts_code": used_ts_code
                })
                
            except Exception as e:
                logger.error(f"获取股票 {code} 价格信息失败: {str(e)}")
                results.append({
                    "code": code,
                    "name": stock_name_map.get(code, "未知"),
                    "price": 0,
                    "change_percent": 0,
                    "volume": 0,
                    "update_time": None,
                    "status": "error",
                    "message": str(e)
                })
        
        # 统计结果
        success_count = len([r for r in results if r.get('status') == 'success'])
        
        return {
            "success": True,
            "message": f"批量查询完成，成功获取 {success_count}/{len(code_list)} 只股票信息",
            "data": results,
            "summary": {
                "total_requested": len(code_list),
                "success_count": success_count,
                "failed_count": len(code_list) - success_count,
                "query_time": datetime.now().isoformat()
            }
        }
        
    except Exception as e:
        logger.error(f"批量获取股票价格失败：{str(e)}")
        return {
            "success": False,
            "message": f"批量获取股票价格失败：{str(e)}",
            "data": []
        }

# 股票调度器API说明：
# 
# 主要功能：
# - /api/stocks/scheduler/status - 调度器状态和统计
# - /api/stocks/scheduler/init - 初始化股票系统
# - /api/stocks/scheduler/trigger - 手动触发任务
# - /api/stocks/scheduler/refresh-stocks - 刷新股票列表
# - /api/stocks/codes - 获取股票代码列表
# 
# 🕐 任务调度时间：
# - K线数据获取: 每个工作日17:30
# - 策略信号计算: 交易时间内每30分钟
# - 收盘后信号计算: 每个交易日15:30
# - 实时数据更新: 交易时间内每15分钟
# 
# 💾 数据存储策略：
# - 股票代码: 永久保存
# - K线数据: 30天TTL
# - 策略信号: 1小时TTL
# - 实时数据: 5分钟TTL
# - 执行日志: 7天TTL 