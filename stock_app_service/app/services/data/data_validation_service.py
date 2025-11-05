# -*- coding: utf-8 -*-
"""数据校验服务 - 检查股票数据完整性"""

from sqlalchemy.orm import Session
from typing import List, Dict, Any, Optional
from datetime import datetime, date, timedelta
import random

from app.core.logging import logger
from app.services.stock.stock_crud import get_all_stocks, get_latest_history_date, get_history_count, get_latest_history_updated_at


def check_stock_data_integrity_by_updated_at(db: Session, stock_code: str) -> Dict[str, Any]:
    """
    基于 updated_at 时间检查单个股票的数据完整性
    
    判断逻辑：
    1. 检查 updated_at 如果是当天15:00（包含）以后更新的说明当前股票不需要更新，no_action
    2. 检查 updated_at 如果是小于当天15:00（包含）以前的且大于前一天15:00（包含）当前股票就需要增量更新 incremental_update_partial
    3. 检查 updated_at 如果是小于前一天15:00（包含）当前股票就需要全量更新 full_update_partial
    
    Args:
        db: 数据库会话
        stock_code: 股票代码
        
    Returns:
        数据完整性报告
    """
    try:
        # 获取最新数据更新时间
        latest_updated_at = get_latest_history_updated_at(db, stock_code)
        
        # 获取当前时间
        now = datetime.now()
        today = now.date()
        
        # 计算关键时间点
        today_15_00 = datetime.combine(today, datetime.min.time().replace(hour=15, minute=0))
        yesterday = today - timedelta(days=1)
        yesterday_15_00 = datetime.combine(yesterday, datetime.min.time().replace(hour=15, minute=0))
        
        # 分析数据状态
        status = "unknown"
        recommendation = "no_action"
        issues = []
        
        if latest_updated_at is None:
            status = "no_data"
            recommendation = "full_update"
            issues.append("没有任何历史数据")
        else:
            # 判断更新策略
            if latest_updated_at >= today_15_00:
                # 当天15:00以后更新的，不需要更新
                status = "up_to_date"
                recommendation = "no_action"
            elif latest_updated_at >= yesterday_15_00:
                # 昨天15:00到今天15:00之间更新的，需要增量更新
                status = "need_incremental"
                recommendation = "incremental_update"
                hours_behind = (now - latest_updated_at).total_seconds() / 3600
                issues.append(f"数据更新时间滞后 {hours_behind:.1f} 小时")
            else:
                # 昨天15:00之前更新的，需要全量更新
                status = "need_full_update"
                recommendation = "full_update"
                days_behind = (now - latest_updated_at).days
                issues.append(f"数据更新时间滞后 {days_behind} 天")
        
        return {
            "stock_code": stock_code,
            "status": status,
            "recommendation": recommendation,
            "latest_updated_at": latest_updated_at.strftime("%Y-%m-%d %H:%M:%S") if latest_updated_at else None,
            "today_15_00": today_15_00.strftime("%Y-%m-%d %H:%M:%S"),
            "yesterday_15_00": yesterday_15_00.strftime("%Y-%m-%d %H:%M:%S"),
            "issues": issues,
            "check_time": now.strftime("%Y-%m-%d %H:%M:%S")
        }
        
    except Exception as e:
        logger.error(f"检查股票 {stock_code} 数据完整性失败: {str(e)}")
        return {
            "stock_code": stock_code,
            "status": "error",
            "recommendation": "full_update",
            "error": str(e)
        }


def check_stock_data_integrity(db: Session, stock_code: str, check_days: int = 30) -> Dict[str, Any]:
    """
    检查单个股票的数据完整性（保留原有逻辑作为备用）
    
    Args:
        db: 数据库会话
        stock_code: 股票代码
        check_days: 检查最近多少天的数据
        
    Returns:
        数据完整性报告
    """
    try:
        # 获取最新数据日期
        latest_date = get_latest_history_date(db, stock_code)
        
        # 获取历史数据记录数
        total_records = get_history_count(db, stock_code)
        
        # 计算预期的检查日期范围
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=check_days)
        
        # 分析数据状态
        status = "unknown"
        recommendation = "no_action"
        issues = []
        
        if latest_date is None:
            status = "no_data"
            recommendation = "immediate_update"
            issues.append("没有任何历史数据")
        else:
            # 计算数据滞后天数
            days_behind = (end_date - latest_date).days
            
            if days_behind == 0:
                status = "up_to_date"
                recommendation = "no_action"
            elif days_behind <= 3:
                status = "slightly_behind"
                recommendation = "routine_update"
                issues.append(f"数据滞后 {days_behind} 天")
            elif days_behind <= 7:
                status = "moderately_behind"
                recommendation = "priority_update"
                issues.append(f"数据滞后 {days_behind} 天")
            else:
                status = "severely_behind"
                recommendation = "immediate_update"
                issues.append(f"数据严重滞后 {days_behind} 天")
        
        return {
            "stock_code": stock_code,
            "status": status,
            "recommendation": recommendation,
            "latest_date": latest_date.strftime("%Y-%m-%d") if latest_date else None,
            "total_records": total_records,
            "days_behind": (end_date - latest_date).days if latest_date else None,
            "issues": issues,
            "check_date": end_date.strftime("%Y-%m-%d"),
            "check_days": check_days
        }
        
    except Exception as e:
        logger.error(f"检查股票 {stock_code} 数据完整性失败: {str(e)}")
        return {
            "stock_code": stock_code,
            "status": "error",
            "recommendation": "immediate_update",
            "error": str(e)
        }


def validate_all_stocks_data(db: Session, check_days: int = 30, sample_size: Optional[int] = None) -> Dict[str, Any]:
    """
    批量检查所有股票的数据完整性（优化版本，基于 updated_at 时间判断）
    
    Args:
        db: 数据库会话
        check_days: 检查最近多少天的数据（保留参数兼容性，但实际使用 updated_at 判断）
        sample_size: 抽样检查的股票数量，None表示检查全部（推荐全部检查）
        
    Returns:
        全市场数据完整性报告和更新策略
    """
    try:
        # 检查是否是周六，如果是周六则所有股票全量更新
        now = datetime.now()
        is_saturday = now.weekday() == 5  # 0=周一, 5=周六
        
        if is_saturday:
            logger.info("检测到当前是周六，返回全量更新所有股票的策略")
            all_stocks = get_all_stocks(db)
            return {
                "action": "full_update_all",
                "message": f"周六全量更新所有 {len(all_stocks)} 只股票（建议120天数据）",
                "update_stocks": [],  # 空数组表示全部股票
                "stats": {
                    "total": len(all_stocks),
                    "up_to_date": 0,
                    "need_update": len(all_stocks),
                    "error": 0
                },
                "timestamp": now.strftime("%Y-%m-%d %H:%M:%S"),
                "reason": "周六全量更新策略"
            }
        
        # 获取所有股票
        all_stocks = get_all_stocks(db)
        
        # 对于全市场扫描，建议检查全部股票
        if sample_size and sample_size < len(all_stocks):
            stocks_to_check = random.sample(all_stocks, sample_size)
            logger.info(f"抽样检查 {sample_size} 只股票（总共 {len(all_stocks)} 只）")
        else:
            stocks_to_check = all_stocks
            logger.info(f"全市场检查 {len(all_stocks)} 只股票")
        
        # 初始化分类列表
        up_to_date_stocks = []          # 数据最新的股票（当天15:00后更新）
        incremental_update_stocks = []   # 需要增量更新的股票（昨天15:00到今天15:00之间更新）
        full_update_stocks = []         # 需要全量更新的股票（昨天15:00之前更新或无数据）
        error_stocks = []               # 检查出错的股票
        
        # 逐个检查股票（使用优化的基于 updated_at 的检查）
        for stock in stocks_to_check:
            result = check_stock_data_integrity_by_updated_at(db, stock.code)
            
            stock_info = {
                "code": stock.code,
                "name": stock.name,
                "status": result.get("status", "error"),
                "latest_updated_at": result.get("latest_updated_at"),
                "issues": result.get("issues", [])
            }
            
            status = result.get("status", "error")
            recommendation = result.get("recommendation", "full_update")
            
            if status == "up_to_date":
                up_to_date_stocks.append(stock_info)
            elif status == "need_incremental":
                incremental_update_stocks.append(stock_info)
            elif status in ["need_full_update", "no_data"]:
                full_update_stocks.append(stock_info)
            else:
                error_stocks.append(stock_info)
        
        # 计算统计信息
        total_stocks = len(stocks_to_check)
        up_to_date_count = len(up_to_date_stocks)
        incremental_count = len(incremental_update_stocks)
        full_update_count = len(full_update_stocks)
        error_count = len(error_stocks)
        needs_update_count = incremental_count + full_update_count
        
        # 简化的返回结构 - 直接告诉用户要做什么
        result = {
            # 核心操作指令 - 一目了然
            "action": "no_action",  # 默认值，下面会根据情况修改
            "message": "",
            "update_stocks": [],    # 始终返回，空数组表示全部股票或无需更新
            
            # 统计信息
            "stats": {
                "total": total_stocks,
                "up_to_date": up_to_date_count,
                "need_update": needs_update_count,
                "error": error_count
            },
            
            # 时间戳
            "timestamp": now.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # 根据情况设置具体操作
        if needs_update_count == 0:
            result["action"] = "no_action"
            result["message"] = "所有数据都是最新的，无需更新"
            # update_stocks 保持空数组
            
        elif incremental_count > 0 and full_update_count == 0:
            # 只有增量更新的股票
            if incremental_count == total_stocks:
                result["action"] = "incremental_update_all"
                result["message"] = f"增量更新所有 {total_stocks} 只股票（建议7天数据）"
                result["update_stocks"] = []  # 空数组表示全部股票
            else:
                result["action"] = "incremental_update_partial"
                result["message"] = f"增量更新 {incremental_count} 只股票（建议7天数据）"
                result["update_stocks"] = [{"code": s["code"], "name": s["name"]} for s in incremental_update_stocks]
                
        elif full_update_count > 0 and incremental_count == 0:
            # 只有全量更新的股票
            if full_update_count == total_stocks:
                result["action"] = "full_update_all"
                result["message"] = f"全量更新所有 {total_stocks} 只股票（建议120天数据）"
                result["update_stocks"] = []  # 空数组表示全部股票
            else:
                result["action"] = "full_update_partial"
                result["message"] = f"全量更新 {full_update_count} 只股票（建议120天数据）"
                result["update_stocks"] = [{"code": s["code"], "name": s["name"]} for s in full_update_stocks]
                
        else:
            # 混合情况：优先选择数量多的操作类型
            if incremental_count >= full_update_count:
                result["action"] = "incremental_update_partial"
                result["message"] = f"增量更新 {incremental_count} 只股票（建议7天数据）"
                result["update_stocks"] = [{"code": s["code"], "name": s["name"]} for s in incremental_update_stocks]
            else:
                result["action"] = "full_update_partial"
                result["message"] = f"全量更新 {full_update_count} 只股票（建议120天数据）"
                result["update_stocks"] = [{"code": s["code"], "name": s["name"]} for s in full_update_stocks]
        
        # 如果有错误股票，总是返回
        if error_count > 0:
            result["error_stocks"] = [{"code": s["code"], "name": s["name"], "error": s.get("issues", [])} for s in error_stocks]
        
        return result
        
    except Exception as e:
        logger.error(f"全市场数据完整性检查失败: {str(e)}")
        return {
            "status": "error",
            "message": str(e),
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        } 