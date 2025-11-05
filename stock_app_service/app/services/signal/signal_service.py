# -*- coding: utf-8 -*-
"""股票信号计算服务"""

import pandas as pd
from typing import List, Dict, Any
from sqlalchemy.orm import Session
from datetime import datetime

from app.core.logging import logger
from app.models.stock import StockInfo, StockHistory, StockSignal
from app.services.stock.stock_crud import get_all_stocks, get_stock_history
from app.indicators.volume_wave_strategy import VolumeWaveStrategy
from app.indicators.trend_continuation_strategy import TrendContinuationStrategy


def calculate_volume_wave_signals(db: Session) -> List[Dict[str, Any]]:
    """
    计算量价波动买入信号（使用现有的VolumeWaveStrategy算法）
    
    Args:
        db: 数据库会话
        
    Returns:
        符合条件的股票信号列表
    """
    signals = []
    
    try:
        # 获取所有股票（排除ST股票）
        stocks = get_all_stocks(db, exclude_st=True)
        logger.info(f"开始计算量价波动信号，共 {len(stocks)} 只股票（已排除ST股票）")
        
        for stock in stocks:
            try:
                # 获取股票历史数据
                history_data = get_stock_history(db, stock.code)
                
                if len(history_data) < 50:  # 至少需要50天数据用于EMA计算
                    continue
                
                # 转换为DataFrame，使用现有算法需要的格式
                df = pd.DataFrame([{
                    'trade_date': h.trade_date,
                    'open': h.open,
                    'high': h.high,
                    'low': h.low,
                    'close': h.close,
                    'volume': h.volume or 0
                } for h in history_data])
                
                df = df.sort_values('trade_date').reset_index(drop=True)
                
                if len(df) < 50:
                    continue
                
                # 使用现有的VolumeWaveStrategy算法
                result_df, strategy_signals = VolumeWaveStrategy.apply_strategy(df)
                
                # 查找买入信号，只要最后一根K线产生的信号
                buy_signals = [s for s in strategy_signals if s['type'] == 'buy']
                
                if buy_signals:
                    # 检查是否有最后一根K线产生的买入信号
                    last_index = len(df) - 1  # 最后一根K线的索引
                    
                    # 查找最后一根K线产生的买入信号
                    last_bar_signals = [s for s in buy_signals if s['index'] == last_index]
                    
                    if last_bar_signals:
                        # 如果最后一根K线有买入信号，使用它
                        latest_signal = last_bar_signals[0]
                        signal_row = df.iloc[last_index]
                        
                        signal = {
                            'code': stock.code,
                            'name': stock.name,
                            'industry': getattr(stock, 'industry', ''),  # 添加行业字段
                            'strategy': 'volume_wave',
                            'signal_type': 'buy',
                            'latest_price': float(signal_row['close']),
                            'signal_date': signal_row['trade_date'].strftime('%Y-%m-%d'),
                            'change_percent': ((signal_row['close'] - signal_row['open']) / signal_row['open'] * 100) if signal_row['open'] > 0 else 0,
                            'volume': float(signal_row['volume']),
                            'board': None,
                            'chart_url': None
                        }
                        signals.append(signal)
                    
            except Exception as e:
                logger.error(f"计算股票 {stock.code} 量价波动信号失败: {str(e)}")
                continue
        
        logger.info(f"量价波动计算完成，找到 {len(signals)} 个买入信号")
        return signals
        
    except Exception as e:
        logger.error(f"计算量价波动信号失败: {str(e)}")
        return []


def calculate_trend_continuation_signals(db: Session) -> List[Dict[str, Any]]:
    """
    计算趋势延续买入信号（使用现有的TrendContinuationStrategy算法）
    
    Args:
        db: 数据库会话
        
    Returns:
        符合条件的股票信号列表
    """
    signals = []
    
    try:
        stocks = get_all_stocks(db, exclude_st=True)
        logger.info(f"开始计算趋势延续信号，共 {len(stocks)} 只股票（已排除ST股票）")
        
        for stock in stocks:
            try:
                history_data = get_stock_history(db, stock.code)
                
                if len(history_data) < 50:  # 至少需要50天数据
                    continue
                
                # 转换为DataFrame，使用现有算法需要的格式
                df = pd.DataFrame([{
                    'trade_date': h.trade_date,
                    'open': h.open,
                    'high': h.high,
                    'low': h.low,
                    'close': h.close,
                    'volume': h.volume or 0
                } for h in history_data])
                
                df = df.sort_values('trade_date').reset_index(drop=True)
                
                if len(df) < 50:
                    continue
                
                # 使用现有的TrendContinuationStrategy算法
                result_df, strategy_signals = TrendContinuationStrategy.apply_strategy(df)
                
                # 查找买入信号，只要最后一根K线产生的信号
                buy_signals = [s for s in strategy_signals if s['type'] == 'buy']
                
                if buy_signals:
                    # 检查是否有最后一根K线产生的买入信号
                    last_index = len(df) - 1  # 最后一根K线的索引
                    
                    # 查找最后一根K线产生的买入信号
                    last_bar_signals = [s for s in buy_signals if s['index'] == last_index]
                    
                    if last_bar_signals:
                        # 如果最后一根K线有买入信号，使用它
                        latest_signal = last_bar_signals[0]
                        signal_row = df.iloc[last_index]
                        
                        signal = {
                            'code': stock.code,
                            'name': stock.name,
                            'industry': getattr(stock, 'industry', ''),  # 添加行业字段
                            'strategy': 'trend_continuation',
                            'signal_type': 'buy',
                            'latest_price': float(signal_row['close']),
                            'signal_date': signal_row['trade_date'].strftime('%Y-%m-%d'),
                            'change_percent': ((signal_row['close'] - signal_row['open']) / signal_row['open'] * 100) if signal_row['open'] > 0 else 0,
                            'volume': float(signal_row['volume']),
                            'board': None,
                            'chart_url': None
                        }
                        signals.append(signal)
                    
            except Exception as e:
                logger.error(f"计算股票 {stock.code} 趋势延续信号失败: {str(e)}")
                continue
        
        logger.info(f"趋势延续计算完成，找到 {len(signals)} 个买入信号")
        return signals
        
    except Exception as e:
        logger.error(f"计算趋势延续信号失败: {str(e)}")
        return []




def save_signals_to_db(db: Session, signals: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    将信号保存到数据库
    
    Args:
        db: 数据库会话
        signals: 信号列表
        
    Returns:
        保存结果
    """
    try:
        success_count = 0
        error_count = 0
        
        for signal in signals:
            try:
                # 检查是否已存在相同的信号
                existing = db.query(StockSignal).filter(
                    StockSignal.code == signal['code'],
                    StockSignal.strategy == signal['strategy'],
                    StockSignal.signal_type == signal['signal_type'],
                    StockSignal.signal_date == signal['signal_date']
                ).first()
                
                if existing:
                    # 更新现有信号
                    existing.latest_price = signal['latest_price']
                    existing.change_percent = signal['change_percent']
                    existing.volume = signal['volume']
                    existing.updated_at = datetime.now()
                else:
                    # 创建新信号
                    new_signal = StockSignal(
                        code=signal['code'],
                        name=signal['name'],
                        strategy=signal['strategy'],
                        signal_type=signal['signal_type'],
                        board=signal['board'],
                        latest_price=signal['latest_price'],
                        signal_date=signal['signal_date'],
                        change_percent=signal['change_percent'],
                        volume=signal['volume'],
                        chart_url=signal['chart_url']
                    )
                    db.add(new_signal)
                
                success_count += 1
                
            except Exception as e:
                logger.error(f"保存信号失败: {str(e)}")
                error_count += 1
        
        db.commit()
        
        result = {
            "total_signals": len(signals),
            "success_count": success_count,
            "error_count": error_count,
            "status": "success" if error_count == 0 else "partial_success"
        }
        
        logger.info(f"信号保存完成: {result}")
        return result
        
    except Exception as e:
        db.rollback()
        logger.error(f"保存信号到数据库失败: {str(e)}")
        raise


def calculate_and_save_buy_signals(db: Session, strategy: str = "all") -> Dict[str, Any]:
    """
    计算并保存买入信号
    
    Args:
        db: 数据库会话
        strategy: 策略类型，可选 "volume_wave", "trend_continuation", "all"
        
    Returns:
        计算和保存结果
    """
    try:
        all_signals = []
        
        if strategy == "all" or strategy == "volume_wave":
            volume_signals = calculate_volume_wave_signals(db)
            all_signals.extend(volume_signals)
        
        if strategy == "all" or strategy == "trend_continuation":
            trend_signals = calculate_trend_continuation_signals(db)
            all_signals.extend(trend_signals)
        
        if not all_signals:
            return {
                "status": "success",
                "message": "计算完成，未找到符合条件的买入信号",
                "total_signals": 0,
                "strategy": strategy
            }
        
        # 保存信号到数据库
        save_result = save_signals_to_db(db, all_signals)
        
        return {
            "status": "success",
            "message": f"成功计算并保存买入信号",
            "strategy": strategy,
            **save_result,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
    except Exception as e:
        logger.error(f"计算并保存买入信号失败: {str(e)}")
        return {
            "status": "error",
            "message": str(e),
            "strategy": strategy
        }


def clear_buy_signals(db: Session, strategy: str = "all") -> Dict[str, Any]:
    """
    清空买入信号表
    
    Args:
        db: 数据库会话
        strategy: 策略类型，可选 "volume_wave", "trend_continuation", "all"
        
    Returns:
        清空结果
    """
    try:
        query = db.query(StockSignal).filter(StockSignal.signal_type == "buy")
        
        if strategy != "all":
            query = query.filter(StockSignal.strategy == strategy)
        
        deleted_count = query.count()
        query.delete()
        db.commit()
        
        logger.warning(f"已清空买入信号表，删除了 {deleted_count} 条记录，策略: {strategy}")
        
        return {
            "status": "success",
            "message": f"成功清空买入信号表",
            "deleted_count": deleted_count,
            "strategy": strategy,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        
    except Exception as e:
        db.rollback()
        logger.error(f"清空买入信号表失败: {str(e)}")
        raise 