# -*- coding: utf-8 -*-
"""日期处理工具"""

from datetime import datetime, timedelta, date
from typing import Optional, Union

def parse_date_string(date_str: str) -> Optional[date]:
    """
    解析多种格式的日期字符串为日期对象
    
    Args:
        date_str: 日期字符串，支持多种格式
        
    Returns:
        解析后的日期对象，解析失败返回None
    """
    if not date_str:
        return None
        
    try:
        # 尝试解析ISO格式的日期时间字符串 "2025-04-01T00:00:00.000"
        if 'T' in date_str:
            return datetime.fromisoformat(date_str.replace('Z', '+00:00')).date()
        
        # 尝试解析YYYYMMDD格式 "20250401"
        if len(date_str) == 8 and date_str.isdigit():
            return datetime.strptime(date_str, "%Y%m%d").date()
            
        # 尝试解析标准日期格式 "2025-04-01"
        if '-' in date_str:
            return datetime.strptime(date_str, "%Y-%m-%d").date()
            
        # 尝试解析中文日期格式 "2025年04月01日"
        if '年' in date_str:
            return datetime.strptime(date_str, "%Y年%m月%d日").date()
            
    except Exception:
        # 如果所有格式都解析失败，则返回None
        return None
        
    return None

def format_date(date_obj: Union[date, datetime], format_str: str = "%Y-%m-%d") -> str:
    """
    将日期对象格式化为字符串
    
    Args:
        date_obj: 日期或日期时间对象
        format_str: 格式化字符串
        
    Returns:
        格式化后的日期字符串
    """
    if isinstance(date_obj, datetime):
        return date_obj.strftime(format_str)
    elif isinstance(date_obj, date):
        return date_obj.strftime(format_str)
    return ""

def get_today() -> date:
    """获取当前日期"""
    return datetime.now().date()

def get_days_before(days: int) -> date:
    """获取N天前的日期"""
    return (datetime.now() - timedelta(days=days)).date()

def get_trading_days(start_date: date, end_date: date) -> int:
    """
    估算两个日期之间的交易日数量（简单算法，不考虑节假日）
    
    Args:
        start_date: 开始日期
        end_date: 结束日期
        
    Returns:
        估算的交易日数量
    """
    # 简单算法：假设周一到周五是交易日
    days = (end_date - start_date).days + 1
    weeks = days // 7
    remaining_days = days % 7
    
    # 计算完整周的交易日
    trading_days = weeks * 5
    
    # 处理剩余天数
    start_weekday = start_date.weekday()  # 0=周一, 6=周日
    for i in range(remaining_days):
        weekday = (start_weekday + i) % 7
        if weekday < 5:  # 周一到周五
            trading_days += 1
            
    return trading_days 