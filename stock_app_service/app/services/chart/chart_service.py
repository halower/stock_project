# -*- coding: utf-8 -*-
"""股票图表生成服务 - 重构版本使用策略模式"""

import os
import pandas as pd
import numpy as np
from datetime import datetime
from sqlalchemy.orm import Session
from typing import List, Dict, Any, Optional
import uuid
from pathlib import Path

from app.core.config import CHART_DIR, CHART_MAX_FILES
from app.models.stock import StockHistory
from app.services.stock.stock_crud import get_stock_history, get_stock_by_code
# 使用策略工厂接口替代直接引入具体策略类
from app.indicators import apply_strategy, get_strategy_by_code, VolumeWaveStrategy
# 引入新的图表策略模块
from app.charts import generate_chart_html, get_chart_strategy_by_code

# 确保图表目录存在
os.makedirs(CHART_DIR, exist_ok=True)

def prepare_stock_data(db: Session, stock_code: str, strategy: str = 'volume_wave') -> Optional[Dict[str, Any]]:
    """
    准备股票数据并计算指标
    
    Args:
        db: 数据库会话
        stock_code: 股票代码
        strategy: 使用的策略类型，可选 'volume_wave' 或 'trend_continuation'
    """
    try:
        # 获取股票信息
        stock = get_stock_by_code(db, stock_code)
        if not stock:
            return None
        
        # 获取历史数据
        history_data = get_stock_history(db, stock_code)
        if not history_data or len(history_data) == 0:
            return None
        
        # 检查是否需要添加当天的实时数据
        today = datetime.now().date()
        
        # 检查当前历史数据中是否已包含今天的数据
        has_today_data = any(h.trade_date == today for h in history_data)
        
        # 注意：实时数据现在直接更新到历史数据表中，不再需要单独的实时数据表
        # 如果历史数据中没有当天数据，说明可能还没有获取到当天的数据
        if not has_today_data:
            # 这里可以选择性地记录日志，但不再尝试从实时数据表获取数据
            # 因为实时数据现在直接更新到历史数据表中
            pass
        
        # 转换成DataFrame便于处理
        df = pd.DataFrame([{
            'date': item.trade_date,
            'open': float(item.open),
            'high': float(item.high),
            'low': float(item.low),
            'close': float(item.close),
            'volume': float(item.volume) if item.volume else 0.0
        } for item in history_data])
        
        # 确保按日期排序
        df = df.sort_values('date')
        
        # 处理数据中的NaN值 - 使用推荐的新方法
        df = df.ffill()  # 前向填充，替代fillna(method='ffill')
        df = df.bfill()  # 后向填充，替代fillna(method='bfill')
        
        # 确保所有价格数据至少为0.01
        for col in ['open', 'high', 'low', 'close']:
            df[col] = df[col].apply(lambda x: max(0.01, x))
        
        # 确保列名统一为小写
        df.columns = [col.lower() for col in df.columns]
        
        # 使用策略工厂接口应用策略
        if strategy == 'volume_wave':
            # 对于波动策略，先单独计算基础技术指标
            close_values = df['close'].to_numpy()
            df['ema6'] = pd.Series(VolumeWaveStrategy.calculate_ema(close_values, 6))
            df['ema17'] = pd.Series(VolumeWaveStrategy.calculate_ema(close_values, 17))
            
        # 使用统一的接口应用策略
        df_with_indicators, signals = apply_strategy(strategy, df)
        
        # 调试信息：打印趋势延续策略的信号详情
        if strategy == 'trend_continuation' and signals:
            for i, signal in enumerate(signals[-3:]):  # 只显示最后3个信号
                if signal.get('type') == 'buy':
                    entry_price = signal.get('price', 0)
                    stop_loss = signal.get('stop_loss', 0)
                    take_profit = signal.get('take_profit', 0)
        # 对于波动策略，确保EMA指标存在
        if strategy == 'volume_wave':
            if 'ema6' not in df_with_indicators.columns:
                df_with_indicators['ema6'] = df['ema6']
            if 'ema17' not in df_with_indicators.columns:
                df_with_indicators['ema17'] = df['ema17']
        
        # 确保列名统一为小写
        df_with_indicators.columns = [col.lower() for col in df_with_indicators.columns]
        
        # 为每个信号添加策略标识（如果没有的话）
        for signal in signals:
            if 'strategy' not in signal:
                signal['strategy'] = strategy
            
        return {
            'stock': stock,
            'data': df_with_indicators,
            'signals': signals,
            'strategy': strategy
        }
    except Exception as e:
        print(f"准备股票数据时出错: {str(e)}")
        return None

def generate_chart(db: Session, stock_code: str, strategy: str = 'volume_wave', theme: str = 'dark') -> Optional[str]:
    """
    生成图表并返回访问URL
    
    Args:
        db: 数据库会话
        stock_code: 股票代码
        strategy: 使用的策略类型，可选 'volume_wave' 或 'trend_continuation'
        theme: 图表主题，可选 'light' 或 'dark'，默认 'dark'
    """
    try:
        # 准备数据
        stock_data = prepare_stock_data(db, stock_code, strategy)
        if not stock_data:
            print(f"无法为股票 {stock_code} 准备数据")
            return None
        
        stock = stock_data['stock']
        df = stock_data['data']
        strategy_type = stock_data['strategy']
        
        # 数据检查
        if df.empty:
            print(f"股票 {stock_code} 数据为空")
            return None
            
        # 调试信息
        print(f"DataFrame列名: {df.columns.tolist()}")
        
        # 验证图表策略是否存在
        chart_strategy = get_chart_strategy_by_code(strategy_type)
        if not chart_strategy:
            print(f"不支持的图表策略: {strategy_type}")
            return None
        
        # 生成唯一文件名（包含主题信息）
        chart_file = f"{stock.code}_{strategy_type}_{theme}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid.uuid4().hex[:8]}.html"
        chart_path = os.path.join(CHART_DIR, chart_file)
        
        # 使用新的图表策略模式生成HTML内容，传递主题参数
        html_content = generate_chart_html(strategy_type, stock_data, theme=theme)
        
        if not html_content:
            print(f"无法生成股票 {stock_code} 的图表HTML内容")
            return None
        
        # 写入HTML文件
        with open(chart_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        # 返回图表URL
        return f"/static/charts/{chart_file}"
    except Exception as e:
        print(f"生成图表时出错: {str(e)}")
        return None

def cleanup_old_charts(max_files: int = CHART_MAX_FILES):
    """清理旧图表文件，保留最新的N个"""
    try:
        files = list(Path(CHART_DIR).glob("*.html"))
        # 按修改时间排序
        files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
        
        # 删除旧文件
        for file in files[max_files:]:
            os.remove(file)
    except Exception as e:
        print(f"清理旧图表失败: {e}")

# 为了向后兼容，保留原有的函数接口（已弃用，建议使用新的策略模式）
def generate_chart_legacy(db: Session, stock_code: str, strategy: str = 'volume_wave') -> Optional[str]:
    """
    旧版图表生成函数（已弃用）
    
    为了向后兼容而保留，建议使用新的 generate_chart 函数
    """
    print("警告: generate_chart_legacy 函数已弃用，请使用新的 generate_chart 函数")
    return generate_chart(db, stock_code, strategy) 