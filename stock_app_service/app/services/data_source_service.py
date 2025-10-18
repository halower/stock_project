# -*- coding: utf-8 -*-
"""数据源服务 - 处理不同数据源的股票历史数据获取"""

import akshare as ak
import tushare as ts
import pandas as pd
from typing import List, Dict, Any, Optional
from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session

from app.core.logging import logger
from app.services.stock_crud import create_or_update_stock_history, get_stock_by_code, delete_stock_completely

# 初始化tushare
try:
    from app.core.config import TUSHARE_TOKEN
    if TUSHARE_TOKEN:
        ts.set_token(TUSHARE_TOKEN)
        logger.info("Tushare token已配置")
    else:
        logger.warning("Tushare token未配置，请在环境变量中设置TUSHARE_TOKEN")
except Exception as e:
    logger.warning(f"Tushare初始化失败: {str(e)}")


def get_stock_history_akshare(stock_code: str, days: int = 120) -> List[Dict[str, Any]]:
    """
    通过akshare获取股票历史K线数据
    
    Args:
        stock_code: 股票代码 (如: 000001)
        days: 获取天数，默认120个交易日
        
    Returns:
        历史数据列表
    """
    try:
        logger.info(f"开始通过akshare获取股票 {stock_code} 的历史数据，天数: {days}")
        
        # 计算开始日期
        end_date = datetime.now().strftime('%Y%m%d')
        start_date = (datetime.now() - timedelta(days=days * 2)).strftime('%Y%m%d')  # 乘以2确保有足够的交易日
        
        # 使用akshare获取历史数据
        df = ak.stock_zh_a_hist(symbol=stock_code, period="daily", start_date=start_date, end_date=end_date, adjust="")
        
        if df.empty:
            logger.warning(f"akshare未获取到股票 {stock_code} 的历史数据")
            return []
        
        # 只取最近的指定天数
        df = df.tail(days)
        
        # 转换数据格式
        history_data = []
        for _, row in df.iterrows():
            data = {
                "日期": row["日期"],
                "开盘": float(row["开盘"]),
                "收盘": float(row["收盘"]),
                "最高": float(row["最高"]),
                "最低": float(row["最低"]),
                "成交量": float(row["成交量"]) if pd.notna(row["成交量"]) else None,
                "成交额": float(row["成交额"]) if pd.notna(row["成交额"]) else None,
                "振幅": float(row["振幅"]) if "振幅" in row and pd.notna(row["振幅"]) else None,
                "涨跌幅": float(row["涨跌幅"]) if "涨跌幅" in row and pd.notna(row["涨跌幅"]) else None,
                "涨跌额": float(row["涨跌额"]) if "涨跌额" in row and pd.notna(row["涨跌额"]) else None,
                "换手率": float(row["换手率"]) if "换手率" in row and pd.notna(row["换手率"]) else None,
            }
            history_data.append(data)
        
        logger.info(f"akshare成功获取股票 {stock_code} 的历史数据，共 {len(history_data)} 条")
        return history_data
        
    except Exception as e:
        logger.error(f"akshare获取股票 {stock_code} 历史数据失败: {str(e)}")
        raise


def get_stock_history_tushare(stock_code: str, days: int = 120) -> List[Dict[str, Any]]:
    """
    通过tushare获取股票历史K线数据
    
    Args:
        stock_code: 股票代码 (如: 000001)
        days: 获取天数，默认120个交易日
        
    Returns:
        历史数据列表
    """
    try:
        logger.info(f"开始通过tushare获取股票 {stock_code} 的历史数据，天数: {days}")
        
        # 检查tushare是否已初始化
        try:
            pro = ts.pro_api()
        except Exception as e:
            logger.error(f"Tushare未正确初始化，请检查token配置: {str(e)}")
            raise Exception("Tushare未正确初始化，请检查token配置")
        
        # 转换股票代码格式 (000001 -> 000001.SZ)
        if stock_code.startswith('6'):
            ts_code = f"{stock_code}.SH"
        elif stock_code.startswith('5'):
            # 5开头是上海ETF（如510030、512660）
            ts_code = f"{stock_code}.SH"
        elif stock_code.startswith('0') or stock_code.startswith('3'):
            ts_code = f"{stock_code}.SZ"
        elif stock_code.startswith(('43', '83', '87', '88')):
            ts_code = f"{stock_code}.BJ"  # 北交所
        else:
            ts_code = f"{stock_code}.SZ"  # 默认深圳
        
        # 计算日期范围
        end_date = datetime.now().strftime('%Y%m%d')
        start_date = (datetime.now() - timedelta(days=days * 2)).strftime('%Y%m%d')
        
        # 判断是否为ETF（5开头的上海ETF，1开头的深圳ETF）
        is_etf = stock_code.startswith(('5', '1')) and len(stock_code) == 6
        
        # 获取历史数据 - ETF使用fund_daily接口，股票使用daily接口
        if is_etf:
            logger.info(f"检测到ETF {stock_code}，使用fund_daily接口")
            df = pro.fund_daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
        else:
            df = pro.daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
        
        if df.empty:
            logger.warning(f"tushare未获取到股票 {stock_code} 的历史数据")
            return []
        
        # 按日期排序并取最近的指定天数
        df = df.sort_values('trade_date').tail(days)
        
        # 转换数据格式 - 使用安全访问，避免字段不存在导致的错误
        history_data = []
        for _, row in df.iterrows():
            try:
                data = {
                    "日期": datetime.strptime(str(row["trade_date"]), '%Y%m%d').strftime('%Y-%m-%d'),
                    "开盘": float(row.get("open", 0)) if pd.notna(row.get("open")) else 0,
                    "收盘": float(row.get("close", 0)) if pd.notna(row.get("close")) else 0,
                    "最高": float(row.get("high", 0)) if pd.notna(row.get("high")) else 0,
                    "最低": float(row.get("low", 0)) if pd.notna(row.get("low")) else 0,
                    "成交量": float(row.get("vol", 0)) * 100 if pd.notna(row.get("vol")) else None,  # tushare的成交量单位是手，需要乘以100
                    "成交额": float(row.get("amount", 0)) * 1000 if pd.notna(row.get("amount")) else None,  # tushare的成交额单位是千元，需要乘以1000
                    "振幅": None,  # tushare基础接口不提供振幅数据
                    "涨跌幅": float(row.get("pct_chg", 0)) if pd.notna(row.get("pct_chg")) else None,
                    "涨跌额": float(row.get("change", 0)) if pd.notna(row.get("change")) else None,
                    "换手率": None,  # tushare基础接口不提供换手率数据
                }
                history_data.append(data)
            except Exception as e:
                logger.error(f"转换第 {len(history_data)+1} 行数据失败: {str(e)}, 原始数据: {row.to_dict()}")
                raise
        
        logger.info(f"tushare成功获取股票 {stock_code} 的历史数据，共 {len(history_data)} 条")
        return history_data
        
    except Exception as e:
        logger.error(f"tushare获取股票 {stock_code} 历史数据失败: {str(e)}")
        raise


def save_stock_history_to_db(db: Session, stock_code: str, history_data: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    将股票历史数据保存到数据库
    
    Args:
        db: 数据库会话
        stock_code: 股票代码
        history_data: 历史数据列表
        
    Returns:
        保存结果统计
    """
    try:
        # 检查股票是否存在
        stock = get_stock_by_code(db, stock_code)
        if not stock:
            logger.error(f"股票代码 {stock_code} 不存在于数据库中")
            raise Exception(f"股票代码 {stock_code} 不存在")
        
        success_count = 0
        error_count = 0
        
        for data in history_data:
            try:
                create_or_update_stock_history(db, stock_code, data)
                success_count += 1
            except Exception as e:
                logger.error(f"保存股票 {stock_code} 历史数据失败: {str(e)}")
                error_count += 1
        
        # 提交事务
        db.commit()
        
        result = {
            "stock_code": stock_code,
            "total_records": len(history_data),
            "success_count": success_count,
            "error_count": error_count,
            "status": "success" if error_count == 0 else "partial_success"
        }
        
        logger.info(f"股票 {stock_code} 历史数据保存完成: {result}")
        return result
        
    except Exception as e:
        db.rollback()
        logger.error(f"保存股票 {stock_code} 历史数据到数据库失败: {str(e)}")
        raise


def fetch_and_save_akshare_history(db: Session, stock_code: str, days: int = 120, auto_delete_delisted: bool = True) -> Dict[str, Any]:
    """
    通过akshare获取股票历史数据并保存到数据库
    
    Args:
        db: 数据库会话
        stock_code: 股票代码
        days: 获取天数
        auto_delete_delisted: 是否自动删除退市股票（已废弃，保留参数但不再自动删除）
        
    Returns:
        操作结果
    """
    try:
        # 股票代码有效性校验
        if not stock_code or not isinstance(stock_code, str) or stock_code.strip() == "":
            logger.warning(f"股票代码无效，未进行任何操作: '{stock_code}'")
            return {
                "stock_code": stock_code,
                "status": "invalid_code",
                "message": "股票代码无效，未进行任何操作",
                "data_source": "akshare"
            }
        # 获取历史数据
        history_data = get_stock_history_akshare(stock_code, days)
        
        if not history_data:
            logger.warning(f"akshare未获取到股票 {stock_code} 的历史数据，不做删除，仅返回警告")
            return {
                "stock_code": stock_code,
                "status": "no_data",
                "message": "未获取到历史数据，不做删除操作",
                "data_source": "akshare"
            }
        # 保存到数据库
        result = save_stock_history_to_db(db, stock_code, history_data)
        result["data_source"] = "akshare"
        return result
    except Exception as e:
        logger.error(f"akshare获取并保存股票 {stock_code} 历史数据失败: {str(e)}")
        return {
            "stock_code": stock_code,
            "status": "error",
            "message": str(e),
            "data_source": "akshare"
        }


def fetch_and_save_tushare_history(db: Session, stock_code: str, days: int = 120, auto_delete_delisted: bool = True) -> Dict[str, Any]:
    """
    通过tushare获取股票历史数据并保存到数据库
    
    Args:
        db: 数据库会话
        stock_code: 股票代码
        days: 获取天数
        auto_delete_delisted: 是否自动删除退市股票（已废弃，保留参数但不再自动删除）
        
    Returns:
        操作结果
    """
    try:
        # 股票代码有效性校验
        if not stock_code or not isinstance(stock_code, str) or stock_code.strip() == "":
            logger.warning(f"股票代码无效，未进行任何操作: '{stock_code}'")
            return {
                "stock_code": stock_code,
                "status": "invalid_code",
                "message": "股票代码无效，未进行任何操作",
                "data_source": "tushare"
            }
        # 获取历史数据
        history_data = get_stock_history_tushare(stock_code, days)
        
        if not history_data:
            logger.warning(f"tushare未获取到股票 {stock_code} 的历史数据，不做删除，仅返回警告")
            return {
                "stock_code": stock_code,
                "status": "no_data",
                "message": "未获取到历史数据，不做删除操作",
                "data_source": "tushare"
            }
        # 保存到数据库
        result = save_stock_history_to_db(db, stock_code, history_data)
        result["data_source"] = "tushare"
        return result
    except Exception as e:
        logger.error(f"tushare获取并保存股票 {stock_code} 历史数据失败: {str(e)}")
        return {
            "stock_code": stock_code,
            "status": "error",
            "message": str(e),
            "data_source": "tushare"
        } 