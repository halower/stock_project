#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import akshare as ak
import pandas as pd
from datetime import datetime

def get_stock_realtime_data():
    """获取股票实时数据"""
    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - 获取股票实时数据...")
    
    try:
        # 使用新浪接口获取实时数据（已验证有效）
        df = ak.stock_zh_a_spot()
        
        if not df.empty:
            # 添加获取时间戳和数据来源
            df['获取时间'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            df['数据来源'] = '新浪'
            
            print(f"✓ 成功获取 {len(df)} 只股票的实时数据")
            return df
        else:
            print("✗ 获取的数据为空")
            return None
    except Exception as e:
        print(f"✗ 获取股票实时数据失败: {str(e)}")
        return None

def analyze_stock_data(df):
    """分析股票数据"""
    if df is None or df.empty:
        return None
    
    analysis = {
        '获取时间': df['获取时间'].iloc[0],
        '数据来源': df['数据来源'].iloc[0],
        '总股票数': len(df)
    }
    
    # 涨跌统计
    change_col = '涨跌幅' if '涨跌幅' in df.columns else None
    
    if change_col:
        up_count = len(df[df[change_col] > 0])
        down_count = len(df[df[change_col] < 0])
        flat_count = len(df[df[change_col] == 0])
        
        analysis['上涨数'] = up_count
        analysis['下跌数'] = down_count
        analysis['平盘数'] = flat_count
        analysis['上涨比例'] = f"{up_count/len(df)*100:.2f}%"
        analysis['下跌比例'] = f"{down_count/len(df)*100:.2f}%"
        
        # 涨幅榜
        top_gainers = df.nlargest(10, change_col)
        analysis['涨幅榜'] = []
        
        code_col = '代码' if '代码' in df.columns else 'symbol'
        name_col = '名称' if '名称' in df.columns else 'name'
        price_col = '最新价' if '最新价' in df.columns else 'price'
        
        for _, row in top_gainers.iterrows():
            code = row[code_col]
            name = row[name_col] if name_col in row else ''
            price = row[price_col] if price_col in row else ''
            change = row[change_col]
            
            analysis['涨幅榜'].append({
                '代码': code,
                '名称': name,
                '价格': price,
                '涨跌幅': f"+{change:.2f}%"
            })
        
        # 跌幅榜
        top_losers = df.nsmallest(10, change_col)
        analysis['跌幅榜'] = []
        
        for _, row in top_losers.iterrows():
            code = row[code_col]
            name = row[name_col] if name_col in row else ''
            price = row[price_col] if price_col in row else ''
            change = row[change_col]
            
            analysis['跌幅榜'].append({
                '代码': code,
                '名称': name,
                '价格': price,
                '涨跌幅': f"{change:.2f}%"
            })
    
    # 成交额统计
    if '成交额' in df.columns:
        total_amount = df['成交额'].sum()
        analysis['总成交额(亿元)'] = round(total_amount / 100000000, 2)
    
    return analysis

def display_stock_analysis(analysis):
    """显示股票分析结果"""
    if not analysis:
        print("无分析数据")
        return
    
    print("\n" + "="*60)
    print(f"股票实时数据分析 - {analysis['获取时间']}")
    print(f"数据来源: {analysis['数据来源']}")
    print("="*60)
    
    print(f"总股票数: {analysis['总股票数']}")
    
    if '上涨数' in analysis:
        print(f"\n涨跌分布:")
        print(f"  上涨: {analysis['上涨数']} ({analysis['上涨比例']})")
        print(f"  下跌: {analysis['下跌数']} ({analysis['下跌比例']})")
        print(f"  平盘: {analysis['平盘数']}")
        
        print(f"\n涨幅榜前10:")
        for stock in analysis['涨幅榜']:
            print(f"  {stock['代码']} {stock['名称']}: {stock['价格']} {stock['涨跌幅']}")
        
        print(f"\n跌幅榜前10:")
        for stock in analysis['跌幅榜']:
            print(f"  {stock['代码']} {stock['名称']}: {stock['价格']} {stock['涨跌幅']}")
    
    if '总成交额(亿元)' in analysis:
        print(f"\n总成交额: {analysis['总成交额(亿元)']} 亿元")

def save_stock_data(df, analysis):
    """保存股票数据"""
    if df is None or df.empty:
        return
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # 保存原始数据
    data_file = f"stock_realtime_{timestamp}.csv"
    df.to_csv(data_file, index=False, encoding='utf-8-sig')
    print(f"\n股票数据已保存到: {data_file}")
    
    # 保存分析结果
    if analysis:
        import json
        analysis_file = f"stock_analysis_{timestamp}.json"
        
        with open(analysis_file, 'w', encoding='utf-8') as f:
            json.dump(analysis, f, ensure_ascii=False, indent=2)
        
        print(f"分析结果已保存到: {analysis_file}")

def main():
    print("="*60)
    print("股票实时数据获取系统")
    print("="*60)
    
    # 获取股票实时数据
    df = get_stock_realtime_data()
    
    if df is not None:
        # 分析数据
        analysis = analyze_stock_data(df)
        
        # 显示分析
        display_stock_analysis(analysis)
        
        # 保存数据
        save_stock_data(df, analysis)
        
        print("\n✓ 股票实时数据获取完成")
    else:
        print("\n✗ 未能获取到股票实时数据")

if __name__ == "__main__":
    main()