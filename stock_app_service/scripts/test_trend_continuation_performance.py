#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
趋势延续策略性能测试脚本

用于对比优化前后的性能差异
"""

import sys
import os
import time
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# 添加项目路径
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.indicators.trend_continuation_strategy import TrendContinuationStrategy


def generate_test_data(size: int = 1000) -> pd.DataFrame:
    """
    生成测试用的OHLCV数据
    
    Args:
        size: 数据条数
        
    Returns:
        测试用的DataFrame
    """
    np.random.seed(42)
    
    # 生成模拟股票数据
    base_price = 100.0
    dates = pd.date_range(end=datetime.now(), periods=size, freq='D')
    
    # 生成价格波动
    returns = np.random.normal(0.001, 0.02, size)  # 日收益率
    close_prices = base_price * (1 + returns).cumprod()
    
    # 生成OHLC数据
    high_prices = close_prices * (1 + np.abs(np.random.normal(0, 0.01, size)))
    low_prices = close_prices * (1 - np.abs(np.random.normal(0, 0.01, size)))
    open_prices = np.roll(close_prices, 1)
    open_prices[0] = base_price
    
    # 确保 OHLC 的逻辑正确
    for i in range(size):
        high_prices[i] = max(high_prices[i], open_prices[i], close_prices[i])
        low_prices[i] = min(low_prices[i], open_prices[i], close_prices[i])
    
    # 生成成交量
    volume = np.random.randint(1000000, 10000000, size)
    
    df = pd.DataFrame({
        'date': dates,
        'open': open_prices,
        'high': high_prices,
        'low': low_prices,
        'close': close_prices,
        'volume': volume
    })
    
    return df


def test_performance(df: pd.DataFrame, length: int = 5, iterations: int = 5):
    """
    测试策略性能
    
    Args:
        df: 测试数据
        length: 策略参数
        iterations: 重复测试次数
    """
    print(f"\n{'='*60}")
    print(f"测试数据量: {len(df)} 条K线")
    print(f"策略参数: length={length}")
    print(f"重复次数: {iterations}")
    print(f"{'='*60}\n")
    
    elapsed_times = []
    signal_counts = []
    
    for i in range(iterations):
        start_time = time.time()
        
        result_df, signals = TrendContinuationStrategy.apply_strategy(
            df.copy(),
            length=length,
            use_close_candle=False,
            stop_loss_ratio=0.05
        )
        
        elapsed = time.time() - start_time
        elapsed_times.append(elapsed)
        signal_counts.append(len(signals))
        
        print(f"第 {i+1} 次测试: 耗时 {elapsed:.4f} 秒, 信号数 {len(signals)}")
    
    avg_time = np.mean(elapsed_times)
    std_time = np.std(elapsed_times)
    avg_signals = np.mean(signal_counts)
    
    print(f"\n{'='*60}")
    print(f"平均耗时: {avg_time:.4f} ± {std_time:.4f} 秒")
    print(f"平均信号数: {avg_signals:.1f}")
    print(f"{'='*60}\n")
    
    return avg_time, avg_signals


def test_signal_validity(df: pd.DataFrame):
    """
    测试生成的信号是否合理
    
    Args:
        df: 测试数据
    """
    print(f"\n{'='*60}")
    print("信号有效性测试")
    print(f"{'='*60}\n")
    
    result_df, signals = TrendContinuationStrategy.apply_strategy(
        df.copy(),
        length=5,
        use_close_candle=False,
        stop_loss_ratio=0.05
    )
    
    # 统计信号类型
    buy_signals = [s for s in signals if s['type'] == 'buy']
    sell_signals = [s for s in signals if s['type'] == 'sell']
    
    print(f"总信号数: {len(signals)}")
    print(f"买入信号: {len(buy_signals)}")
    print(f"卖出信号: {len(sell_signals)}")
    
    if buy_signals:
        print(f"\n买入信号示例:")
        for signal in buy_signals[:3]:
            print(f"  索引: {signal['index']}, "
                  f"入场价: {signal['price']:.2f}, "
                  f"止损: {signal['stop_loss']:.2f}, "
                  f"止盈: {signal['take_profit']:.2f}")
    
    if sell_signals:
        print(f"\n卖出信号示例:")
        for signal in sell_signals[:3]:
            print(f"  索引: {signal['index']}, "
                  f"价格: {signal['price']:.2f}")
    
    # 检查止损止盈的合理性
    if buy_signals:
        print(f"\n止损止盈合理性检查:")
        for signal in buy_signals[:5]:
            entry = signal['price']
            stop = signal['stop_loss']
            profit = signal['take_profit']
            
            risk = entry - stop
            reward = profit - entry
            risk_ratio = (risk / entry) * 100
            reward_ratio = (reward / entry) * 100
            rr_ratio = reward / risk if risk > 0 else 0
            
            print(f"  入场: {entry:.2f}, "
                  f"风险: {risk_ratio:.2f}%, "
                  f"回报: {reward_ratio:.2f}%, "
                  f"风险回报比: 1:{rr_ratio:.2f}")
    
    print(f"\n{'='*60}\n")


def main():
    """主测试函数"""
    print("\n" + "="*60)
    print("趋势延续策略性能测试")
    print("="*60)
    
    # 测试不同数据量
    test_sizes = [100, 500, 1000, 2000]
    
    results = []
    
    for size in test_sizes:
        df = generate_test_data(size)
        avg_time, avg_signals = test_performance(df, length=5, iterations=5)
        results.append({
            'size': size,
            'avg_time': avg_time,
            'avg_signals': avg_signals,
            'time_per_row': avg_time / size * 1000  # 毫秒/行
        })
    
    # 输出汇总结果
    print("\n" + "="*60)
    print("性能测试汇总")
    print("="*60)
    print(f"{'数据量':<10} {'平均耗时(秒)':<15} {'信号数':<10} {'每行耗时(ms)':<15}")
    print("-"*60)
    
    for result in results:
        print(f"{result['size']:<10} "
              f"{result['avg_time']:<15.4f} "
              f"{result['avg_signals']:<10.1f} "
              f"{result['time_per_row']:<15.4f}")
    
    print("="*60)
    
    # 测试信号有效性
    df = generate_test_data(1000)
    test_signal_validity(df)
    
    print("\n测试完成！\n")


if __name__ == "__main__":
    main()

