# -*- coding: utf-8 -*-
"""股票数据CRUD操作服务"""

from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
from datetime import datetime, date
from sqlalchemy import desc, asc, func
from sqlalchemy.sql import text

from app.models.stock import StockInfo, StockHistory, StockSignal
from app.core.config import MAX_HISTORY_RECORDS
from app.core.logging import logger

def get_stock_by_code(db: Session, code: str) -> Optional[StockInfo]:
    """根据股票代码获取股票信息"""
    return db.query(StockInfo).filter(StockInfo.code == code).first()

def get_stocks(db: Session, skip: int = 0, limit: int = 100) -> List[StockInfo]:
    """获取股票列表,带分页"""
    return db.query(StockInfo).offset(skip).limit(limit).all()

def get_all_stocks(db: Session, exclude_st: bool = False) -> List[StockInfo]:
    """获取所有股票信息
    
    Args:
        db: 数据库会话
        exclude_st: 是否排除ST股票（以ST开头的股票）
        
    Returns:
        股票信息列表
    """
    query = db.query(StockInfo)
    
    if exclude_st:
        # 过滤掉以ST开头的股票
        query = query.filter(~StockInfo.name.like('ST%'))
    
    return query.all()

def create_stock(db: Session, code: str, name: str) -> StockInfo:
    """创建股票信息,如果存在则更新"""
    # 检查股票是否已存在
    stock = get_stock_by_code(db, code)
    if stock:
        # 更新名称
        stock.name = name
    else:
        # 创建新股票记录
        stock = StockInfo(code=code, name=name)
        db.add(stock)
    
    db.commit()
    db.refresh(stock)
    return stock

def get_stock_history(db: Session, code: str) -> List[StockHistory]:
    """获取指定股票的所有历史数据"""
    return db.query(StockHistory).filter(StockHistory.stock_code == code).order_by(StockHistory.trade_date).all()

def get_latest_history_date(db: Session, code: str) -> Optional[date]:
    """获取指定股票最新的历史数据日期"""
    latest = db.query(StockHistory).filter(StockHistory.stock_code == code).order_by(desc(StockHistory.trade_date)).first()
    return latest.trade_date if latest else None

def get_latest_history_updated_at(db: Session, code: str) -> Optional[datetime]:
    """获取指定股票最新的历史数据更新时间"""
    latest = db.query(StockHistory).filter(StockHistory.stock_code == code).order_by(desc(StockHistory.updated_at)).first()
    return latest.updated_at if latest else None

def get_latest_stock_history(db: Session, code: str) -> Optional[StockHistory]:
    """获取指定股票最新的历史数据记录"""
    return db.query(StockHistory).filter(StockHistory.stock_code == code).order_by(desc(StockHistory.trade_date)).first()

def get_history_count(db: Session, code: str) -> int:
    """获取指定股票的历史数据记录数量"""
    return db.query(func.count(StockHistory.trade_date)).filter(StockHistory.stock_code == code).scalar()

def get_current_stock_data(db: Session, code: str) -> Optional[StockHistory]:
    """获取指定股票的当日数据（实时价格）"""
    today = datetime.now().date()
    return db.query(StockHistory).filter(
        StockHistory.stock_code == code,
        StockHistory.trade_date == today
    ).first()

def manage_history_records(db: Session, code: str):
    """管理历史记录数量,保持在限制范围内"""
    try:
        # 获取当前记录数
        count = get_history_count(db, code)
        
        # 如果超过最大限制,删除最早的记录
        while count > MAX_HISTORY_RECORDS:
            if delete_oldest_record(db, code):
                count -= 1
            else:
                break
    except Exception as e:
        logger.warning(f"管理历史记录数量时出错（将忽略此错误）: {str(e)}")
        # 静默处理错误，不中断主流程

def delete_oldest_record(db: Session, code: str) -> bool:
    """删除指定股票最早的一条历史记录，处理可能的过期对象问题"""
    try:
        # 使用SQL直接删除而不是先查询再删除，避免对象过期问题
        # 使用PostgreSQL兼容的写法
        sql = text("""
            DELETE FROM stock_history
            WHERE id IN (
                SELECT id FROM stock_history
                WHERE stock_code = :code
                ORDER BY trade_date ASC
                LIMIT 1
            )
        """)
        result = db.execute(sql, {"code": code})
        db.commit()
        affected = result.rowcount
        if affected > 0:
            logger.debug(f"删除了股票 {code} 的一条最早历史记录")
        return affected > 0
    except Exception as e:
        logger.error(f"删除最早记录时出错: {str(e)}")
        # 只有当会话状态正常时才尝试回滚
        try:
            db.rollback()
        except Exception as rollback_error:
            logger.warning(f"回滚删除操作失败: {str(rollback_error)}")
        return False

def create_or_update_stock_history(db: Session, stock_code: str, history_data: Dict[str, Any]) -> StockHistory:
    """创建或更新股票历史数据，处理并发冲突和重复键问题"""
    # 转换日期字符串为日期对象
    trade_date = history_data.get("日期", None)
    if isinstance(trade_date, str):
        # 处理不同格式的日期字符串
        if "T" in trade_date:
            # ISO格式 "2025-04-01T00:00:00.000"
            trade_date = datetime.fromisoformat(trade_date.replace("Z", "+00:00")).date()
        else:
            # 简单格式 "2025-04-01"
            trade_date = datetime.strptime(trade_date, "%Y-%m-%d").date()
    
    try:
        # 先检查是否存在
        existing = db.query(StockHistory).filter(
            StockHistory.stock_code == stock_code,
            StockHistory.trade_date == trade_date
        ).first()
        
        if existing:
            # 如果存在，更新现有记录
            existing.open = history_data.get("开盘", 0.0)
            existing.close = history_data.get("收盘", 0.0)
            existing.high = history_data.get("最高", 0.0)
            existing.low = history_data.get("最低", 0.0)
            existing.volume = history_data.get("成交量", None)
            existing.amount = history_data.get("成交额", None)
            existing.amplitude = history_data.get("振幅", None)
            existing.change_percent = history_data.get("涨跌幅", None)
            existing.change_amount = history_data.get("涨跌额", None)
            existing.turnover_rate = history_data.get("换手率", None)
            existing.updated_at = datetime.now()
            
            return existing
        else:
            # 如果不存在，创建新记录
            history = StockHistory(
                stock_code=stock_code,
                trade_date=trade_date,
                open=history_data.get("开盘", 0.0),
                close=history_data.get("收盘", 0.0),
                high=history_data.get("最高", 0.0),
                low=history_data.get("最低", 0.0),
                volume=history_data.get("成交量", None),
                amount=history_data.get("成交额", None),
                amplitude=history_data.get("振幅", None),
                change_percent=history_data.get("涨跌幅", None),
                change_amount=history_data.get("涨跌额", None),
                turnover_rate=history_data.get("换手率", None),
                updated_at=datetime.now()
            )
            db.add(history)
            return history
    
    except Exception as e:
        # 捕获异常但不处理，让调用方决定如何处理事务
        logger.error(f"创建或更新历史数据时出错 {stock_code}/{trade_date}: {str(e)}")
        raise

def sanitize_float_value(value: Any) -> Optional[float]:
    """清理浮点数值，处理inf和nan值"""
    if value is None:
        return None
    
    try:
        float_val = float(value)
        # 检查是否为无穷大或NaN
        if not (float_val == float_val) or float_val == float('inf') or float_val == float('-inf'):
            return None
        return float_val
    except (ValueError, TypeError):
        return None

def create_or_update_stock_realtime(db: Session, stock_code: str, realtime_data: Dict[str, Any]) -> Dict[str, Any]:
    """更新股票实时数据到历史表中（简化版本，只更新历史表）"""
    today = datetime.now().date()
    result = {}
    
    try:
        # 更新历史数据表 - 使用UPSERT模式避免唯一约束冲突
        try:
            # 使用SQL直接执行UPSERT操作
            from sqlalchemy.sql import text
            
            # 获取更新数据并清理无效值
            current_high = sanitize_float_value(realtime_data.get("最高", 0.0)) or 0.0
            current_low = sanitize_float_value(realtime_data.get("最低", 0.0)) or 0.0
            current_open = sanitize_float_value(realtime_data.get("今开", 0.0)) or 0.0
            current_close = sanitize_float_value(realtime_data.get("最新价", 0.0)) or 0.0
            current_volume = sanitize_float_value(realtime_data.get("成交量", None))
            current_amount = sanitize_float_value(realtime_data.get("成交额", None))
            current_amplitude = sanitize_float_value(realtime_data.get("振幅", None))
            current_change_percent = sanitize_float_value(realtime_data.get("涨跌幅", None))
            current_change_amount = sanitize_float_value(realtime_data.get("涨跌额", None))
            current_turnover_rate = sanitize_float_value(realtime_data.get("换手率", None))
            current_time = datetime.now()
            
            # 使用PostgreSQL的ON CONFLICT DO UPDATE语法
            upsert_sql = text("""
                INSERT INTO stock_history 
                (stock_code, trade_date, open, close, high, low, volume, amount, 
                 amplitude, change_percent, change_amount, turnover_rate, updated_at)
                VALUES 
                (:code, :date, :open, :close, :high, :low, :volume, :amount,
                 :amplitude, :change_percent, :change_amount, :turnover_rate, :updated_at)
                ON CONFLICT (stock_code, trade_date) DO UPDATE SET
                    open = CASE WHEN stock_history.open > 0 THEN stock_history.open ELSE EXCLUDED.open END,
                    close = EXCLUDED.close,
                    high = GREATEST(stock_history.high, EXCLUDED.high),
                    low = CASE 
                            WHEN stock_history.low = 0 THEN EXCLUDED.low
                            WHEN EXCLUDED.low = 0 THEN stock_history.low
                            ELSE LEAST(stock_history.low, EXCLUDED.low)
                          END,
                    volume = EXCLUDED.volume,
                    amount = EXCLUDED.amount,
                    amplitude = EXCLUDED.amplitude,
                    change_percent = EXCLUDED.change_percent,
                    change_amount = EXCLUDED.change_amount,
                    turnover_rate = EXCLUDED.turnover_rate,
                    updated_at = EXCLUDED.updated_at
                RETURNING stock_code, trade_date
            """)
            
            # 执行UPSERT
            result_proxy = db.execute(upsert_sql, {
                "code": stock_code,
                "date": today,
                "open": current_open,
                "close": current_close,
                "high": current_high,
                "low": current_low,
                "volume": current_volume,
                "amount": current_amount,
                "amplitude": current_amplitude,
                "change_percent": current_change_percent,
                "change_amount": current_change_amount,
                "turnover_rate": current_turnover_rate,
                "updated_at": current_time
            })
            
            # 获取返回的主键值
            returned_values = result_proxy.fetchone()
            returned_stock_code = returned_values[0]
            returned_trade_date = returned_values[1]
            
            # 查询更新后的记录
            history_record = db.query(StockHistory).filter(
                StockHistory.stock_code == returned_stock_code,
                StockHistory.trade_date == returned_trade_date
            ).first()
            result["history"] = history_record
            
        except Exception as e:
            logger.error(f"使用UPSERT更新股票 {stock_code} 的历史数据失败: {str(e)}")
            # 回滚历史数据更新，但不影响实时数据更新
            db.rollback()
            
            # 尝试使用传统方式更新
            try:
                # 检查是否已存在今天的记录
                existing_history = db.query(StockHistory).filter(
                    StockHistory.stock_code == stock_code,
                    StockHistory.trade_date == today
                ).first()
                
                if existing_history:
                    # 更新现有记录，使用清理后的数据
                    clean_open = sanitize_float_value(realtime_data.get("今开", 0.0)) or 0.0
                    clean_close = sanitize_float_value(realtime_data.get("最新价", 0.0)) or 0.0
                    clean_high = sanitize_float_value(realtime_data.get("最高", 0.0)) or 0.0
                    clean_low = sanitize_float_value(realtime_data.get("最低", 0.0)) or 0.0
                    
                    existing_history.open = existing_history.open if existing_history.open > 0 else clean_open
                    existing_history.close = clean_close
                    
                    # 更新最高价和最低价
                    if clean_high > existing_history.high:
                        existing_history.high = clean_high
                    
                    if clean_low < existing_history.low or existing_history.low == 0:
                        existing_history.low = clean_low
                    
                    existing_history.volume = sanitize_float_value(realtime_data.get("成交量", None))
                    existing_history.amount = sanitize_float_value(realtime_data.get("成交额", None))
                    existing_history.amplitude = sanitize_float_value(realtime_data.get("振幅", None))
                    existing_history.change_percent = sanitize_float_value(realtime_data.get("涨跌幅", None))
                    existing_history.change_amount = sanitize_float_value(realtime_data.get("涨跌额", None))
                    existing_history.turnover_rate = sanitize_float_value(realtime_data.get("换手率", None))
                    existing_history.updated_at = datetime.now()
                    history_record = existing_history
                else:
                    # 创建新记录，使用清理后的数据
                    history_record = StockHistory(
                        stock_code=stock_code,
                        trade_date=today,
                        open=sanitize_float_value(realtime_data.get("今开", 0.0)) or 0.0,
                        close=sanitize_float_value(realtime_data.get("最新价", 0.0)) or 0.0,
                        high=sanitize_float_value(realtime_data.get("最高", 0.0)) or 0.0,
                        low=sanitize_float_value(realtime_data.get("最低", 0.0)) or 0.0,
                        volume=sanitize_float_value(realtime_data.get("成交量", None)),
                        amount=sanitize_float_value(realtime_data.get("成交额", None)),
                        amplitude=sanitize_float_value(realtime_data.get("振幅", None)),
                        change_percent=sanitize_float_value(realtime_data.get("涨跌幅", None)),
                        change_amount=sanitize_float_value(realtime_data.get("涨跌额", None)),
                        turnover_rate=sanitize_float_value(realtime_data.get("换手率", None)),
                    )
                    db.add(history_record)
                
                result["history"] = history_record
            except Exception as e2:
                logger.error(f"尝试传统方式更新股票 {stock_code} 的历史数据也失败: {str(e2)}")
                # 忽略历史数据更新错误
        
        # 提交所有更改
        db.commit()
        
        # 刷新更改后的对象
        if "history" in result and result["history"] is not None:
            db.refresh(result["history"])
        
        # 管理历史记录数量,保持在限制范围内
        try:
            manage_history_records(db, stock_code)
        except Exception as e:
            # 如果管理历史记录失败，记录错误但不影响主流程
            logger.warning(f"管理股票 {stock_code} 的历史记录数量时出错: {str(e)}")
        
        logger.debug(f"已更新股票 {stock_code} 的历史数据")
        return result
        
    except Exception as e:
        # 只有当会话状态正常时才尝试回滚
        try:
            db.rollback()
        except Exception as rollback_error:
            # 如果回滚失败，说明会话可能已经处于无效状态
            logger.warning(f"回滚股票 {stock_code} 的事务失败: {str(rollback_error)}")
        
        logger.error(f"更新股票 {stock_code} 的历史数据失败: {str(e)}")
        # 返回空结果而不是抛出异常，避免中断整个批处理
        return {}

def delete_stock_history(db: Session, stock_code: str) -> int:
    """删除指定股票的所有历史数据"""
    try:
        # 获取当前记录数，用于返回删除了多少条记录
        count = get_history_count(db, stock_code)
        
        # 使用正确的SQL语句处理分区表，确保能正确删除数据
        # 执行删除操作
        db.execute(text("DELETE FROM stock_history WHERE stock_code = :code"), {"code": stock_code})
        db.commit()
        
        logger.info(f"已成功删除股票 {stock_code} 的所有历史数据，共 {count} 条记录")
        return count
    except Exception as e:
        db.rollback()
        logger.error(f"删除股票 {stock_code} 的历史数据失败: {str(e)}")
        return 0

def delete_all_stock_history(db: Session) -> Dict[str, Any]:
    """删除所有股票的历史数据"""
    result = {
        "total_stocks": 0,
        "deleted_stocks": 0,
        "total_records_deleted": 0,
        "details": []
    }
    
    # 获取所有股票
    stocks = get_all_stocks(db)
    result["total_stocks"] = len(stocks)
    
    # 逐个删除每只股票的历史数据
    for stock in stocks:
        count = delete_stock_history(db, stock.code)
        if count > 0:
            result["deleted_stocks"] += 1
            result["total_records_deleted"] += count
            result["details"].append({
                "stock_code": stock.code,
                "stock_name": stock.name,
                "deleted_records": count
            })
    
    return result

# 信号相关操作
def save_stock_signals(db: Session, signals: List[Dict], strategy: str, signal_type: str):
    """
    保存股票信号到数据库
    
    Args:
        db: 数据库会话
        signals: 信号列表
        strategy: 策略类型
        signal_type: 信号类型(buy/sell)
    """
    try:
        # 先删除该策略的旧信号
        db.query(StockSignal).filter(
            StockSignal.strategy == strategy,
            StockSignal.signal_type == signal_type
        ).delete()
        
        # 插入新信号
        for signal in signals:
            db_signal = StockSignal(
                code=signal.get("code"),
                name=signal.get("name"),
                strategy=strategy,
                signal_type=signal_type,
                board=signal.get("board"),
                latest_price=signal.get("latest_price"),
                signal_date=signal.get("signal_date"),
                change_percent=signal.get("change_percent"),
                volume=signal.get("volume"),
                chart_url=signal.get("chart_url")
            )
            db.add(db_signal)
        
        db.commit()
        return len(signals)
    except Exception as e:
        db.rollback()
        logger.error(f"保存{strategy}策略的{signal_type}信号失败: {str(e)}")
        return 0

def get_stock_signals(db: Session, strategy: str, signal_type: str, limit: int = 100) -> List[Dict]:
    """
    从数据库获取股票信号 - 优化版本
    
    Args:
        db: 数据库会话
        strategy: 策略类型
        signal_type: 信号类型(buy/sell)
        limit: 限制返回数量
        
    Returns:
        信号列表
    """
    try:
        # 使用预先定义的查询列，避免不必要的列
        columns = [
            StockSignal.code,
            StockSignal.name,
            StockSignal.board,
            StockSignal.latest_price,
            StockSignal.signal_date,
            StockSignal.change_percent,
            StockSignal.volume,
            StockSignal.chart_url,
            StockSignal.strategy
        ]
        
        # 创建单个查询，减少数据库交互
        query = (db.query(*columns)
                .filter(StockSignal.strategy == strategy,
                       StockSignal.signal_type == signal_type))
        
        # 添加过滤条件：排除ST股票
        query = query.filter(~StockSignal.name.like('%ST%'))
        
        # 添加排序并限制返回数量
        signals = query.order_by(StockSignal.created_at.desc()).limit(limit).all()
        
        # 使用列表推导式快速创建字典
        result = [
            {
                "code": signal[0],
                "name": signal[1],
                "board": signal[2],
                "latest_price": signal[3],
                "signal_date": signal[4],
                "change_percent": signal[5],
                "volume": signal[6],
                "chart_url": signal[7],
                "strategy": signal[8]
            }
            for signal in signals
        ]
        
        return result
    except Exception as e:
        logger.error(f"获取{strategy}策略的{signal_type}信号失败: {str(e)}")
        return []

def count_stock_signals(db: Session, strategy: str, signal_type: str) -> int:
    """
    统计某策略信号的数量
    
    Args:
        db: 数据库会话
        strategy: 策略类型
        signal_type: 信号类型(buy/sell)
        
    Returns:
        信号数量
    """
    try:
        return db.query(StockSignal).filter(
            StockSignal.strategy == strategy,
            StockSignal.signal_type == signal_type
        ).count()
    except Exception as e:
        logger.error(f"统计{strategy}策略的{signal_type}信号数量失败: {str(e)}")
        return 0

def delete_stock_completely(db: Session, stock_code: str) -> Dict[str, Any]:
    """
    完全删除股票（包括股票信息、历史数据、信号数据）
    
    Args:
        db: 数据库会话
        stock_code: 股票代码
        
    Returns:
        删除结果统计
    """
    try:
        result = {
            "stock_code": stock_code,
            "deleted_history_records": 0,
            "deleted_signal_records": 0,
            "deleted_stock_info": False,
            "status": "success"
        }
        
        # 1. 删除历史数据
        history_count = delete_stock_history(db, stock_code)
        result["deleted_history_records"] = history_count
        
        # 2. 删除信号数据
        signal_count = db.query(StockSignal).filter(StockSignal.code == stock_code).count()
        db.query(StockSignal).filter(StockSignal.code == stock_code).delete()
        result["deleted_signal_records"] = signal_count
        
        # 3. 删除股票信息
        stock_info = get_stock_by_code(db, stock_code)
        if stock_info:
            db.delete(stock_info)
            result["deleted_stock_info"] = True
        
        # 提交所有删除操作
        db.commit()
        
        logger.info(f"已完全删除股票 {stock_code}：历史数据 {history_count} 条，信号数据 {signal_count} 条")
        return result
        
    except Exception as e:
        db.rollback()
        logger.error(f"完全删除股票 {stock_code} 失败: {str(e)}")
        return {
            "stock_code": stock_code,
            "status": "error",
            "message": str(e)
        } 