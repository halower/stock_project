# -*- coding: utf-8 -*-
"""实时数据和交易状态API路由"""

from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Dict, Any, List
from sqlalchemy.orm import Session
import pandas as pd
import datetime
import concurrent.futures
import threading
import time

from app.core.logging import logger
from app.db.session import get_db, SessionLocal
from app.services.stock.stock_crud import get_all_stocks, create_or_update_stock_realtime, sanitize_float_value
from app.services.realtime import get_proxy_manager, get_stock_realtime_service_v2

# 简单的替代函数
def set_background_task_status(status):
    """设置后台任务状态的简单替代函数"""
    logger.info(f"后台任务状态: {status}")
    pass

def get_background_task_status():
    """获取后台任务状态的简单替代函数"""
    return {"running": False}

def is_trading_time():
    """检查是否为交易时间的简单替代函数"""
    import datetime
    now = datetime.datetime.now()
    # 简单判断：工作日的9:30-15:00
    if now.weekday() >= 5:  # 周末
        return False
    if now.hour < 9 or (now.hour == 9 and now.minute < 30):
        return False
    if now.hour >= 15:
        return False
    return True
from app.api.dependencies import verify_token

router = APIRouter()

# 从路由器中移除API接口，改为内部函数，供调度器调用
def update_realtime_data(
    db: Session,
    batch_size: int = 100
) -> Dict[str, Any]:
    """
    执行一次实时数据更新，从第三方API获取最新价格并更新数据库
    (内部函数，不再暴露为API接口)
    
    Args:
        db: 数据库会话
        batch_size: 每批处理的股票数量
        
    Returns:
        更新结果信息
    """
    try:
        # 获取股票列表
        stocks = get_all_stocks(db)
        
        if not stocks:
            logger.error("没有找到任何股票信息，请先初始化股票数据")
            return {
                "total": 0,
                "updated": 0,
                "failed": 0,
                "success_rate": 0,
                "error": "没有找到任何股票信息"
            }
        
        # 创建结果统计
        results = {
            "total": len(stocks),
            "updated": 0,
            "failed": 0,
            "success_rate": 0,
            "details": []
        }
        
        # 获取A股最新行情（使用V2实时行情服务，不依赖akshare）
        try:
            logger.info("正在从实时行情服务获取A股实时行情数据...")
            proxy_manager = get_proxy_manager()
            realtime_service = get_stock_realtime_service_v2(proxy_manager=proxy_manager)
            result = realtime_service.get_all_stocks_realtime()
            
            if not result.get('success'):
                raise Exception(f"获取实时数据失败: {result.get('error', '未知错误')}")
            
            realtime_data_list = result.get('data', [])
            if not realtime_data_list:
                raise Exception("获取的实时数据为空")
            
            # 转换为DataFrame并设置代码作为索引，方便根据代码查询数据
            spot_df = pd.DataFrame(realtime_data_list)
            spot_df = spot_df.set_index("code")
            logger.info(f"成功获取{len(spot_df)}只股票的实时行情数据，数据源: {result.get('source', 'unknown')}")
        except Exception as e:
            logger.error(f"获取A股实时行情数据失败: {str(e)}")
            return {
                "total": len(stocks),
                "updated": 0,
                "failed": len(stocks),
                "success_rate": 0,
                "error": f"获取A股实时行情数据失败: {str(e)}"
            }
        
        # 使用多线程并行处理数据更新
        def update_stock(stock):
            # 为每个线程创建独立的数据库会话
            thread_db = SessionLocal()
            
            try:
                # 检查是否有该股票的实时数据
                if stock.code in spot_df.index:
                    # 获取该股票的实时数据行
                    row = spot_df.loc[stock.code]
                    
                    # 将行数据转换为字典
                    realtime_data = row.to_dict()
                    
                    # 转换字段名以兼容数据库存储（实时服务返回的是英文字段）
                    # 实时服务字段: code, name, price, change, change_percent, open, high, low, volume, amount等
                    # 需要转换为akshare格式的中文字段名以兼容现有的数据库函数
                    converted_data = {
                        "最新价": realtime_data.get("price", 0),
                        "涨跌幅": realtime_data.get("change_percent", 0),
                        "涨跌额": realtime_data.get("change", 0),
                        "今开": realtime_data.get("open", 0),
                        "最高": realtime_data.get("high", 0),
                        "最低": realtime_data.get("low", 0),
                        "成交量": realtime_data.get("volume", 0),
                        "成交额": realtime_data.get("amount", 0),
                        "换手率": realtime_data.get("turnover_rate", 0),
                    }
                    
                    # 更新数据库
                    create_or_update_stock_realtime(thread_db, stock.code, converted_data)
                    
                    return {
                        "code": stock.code,
                        "name": stock.name,
                        "status": "success",
                        "price": sanitize_float_value(realtime_data.get("price")),
                        "change_percent": sanitize_float_value(realtime_data.get("change_percent"))
                    }
                else:
                    logger.warning(f"股票 {stock.code} 在实时行情数据中未找到")
                    return {
                        "code": stock.code,
                        "name": stock.name,
                        "status": "failed",
                        "error": "在实时行情数据中未找到该股票"
                    }
            except Exception as e:
                logger.error(f"更新股票 {stock.code} 的实时数据失败: {str(e)}")
                return {
                    "code": stock.code,
                    "name": stock.name,
                    "status": "failed",
                    "error": str(e)
                }
            finally:
                # 确保关闭线程专用的数据库会话
                thread_db.close()
        
        # 使用线程池并行处理股票更新
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            # 提交所有股票的更新任务
            future_to_stock = {executor.submit(update_stock, stock): stock for stock in stocks}
            
            # 处理完成的任务结果
            for future in concurrent.futures.as_completed(future_to_stock):
                result = future.result()
                if result:
                    results["details"].append(result)
                    if result["status"] == "success":
                        results["updated"] += 1
                    else:
                        results["failed"] += 1
        
        # 计算成功率
        if results["total"] > 0:
            success_rate = results["updated"] / results["total"] * 100
            results["success_rate"] = sanitize_float_value(round(success_rate, 2)) or 0.0
        
        return results
        
    except Exception as e:
        logger.error(f"执行实时数据更新过程中发生异常: {str(e)}")
        return {
            "total": 0,
            "updated": 0,
            "failed": 0,
            "success_rate": 0,
            "error": f"执行实时数据更新过程中发生异常: {str(e)}"
        } 