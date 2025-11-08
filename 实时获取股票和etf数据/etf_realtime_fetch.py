#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import akshare as ak
import pandas as pd
from datetime import datetime

def get_etf_realtime_data():
    """获取ETF实时数据"""
    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - 获取ETF实时数据...")
    
    try:
        # 使用同花顺ETF数据接口
        df = ak.fund_etf_spot_sina()
        
        if not df.empty:
            # 添加获取时间戳和数据来源
            df['获取时间'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            df['数据来源'] = '同花顺'
            
            print(f"✓ 成功获取 {len(df)} 只ETF的实时数据")
            return df
        else:
            print("✗ 获取的数据为空")
            return None
    except Exception as e:
        print(f"✗ 获取ETF实时数据失败: {str(e)}")
        
        # 尝试备用接口
        try:
            print("尝试备用接口...")
            df = ak.fund_etf_category_sina(symbol="ETF基金")
            
            if not df.empty:
                # 添加获取时间戳和数据来源
                df['获取时间'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                df['数据来源'] = '新浪备用'
                
                print(f"✓ 备用接口成功获取 {len(df)} 只ETF的实时数据")
                return df
            else:
                print("✗ 备用接口返回空数据")
                return None
        except Exception as e2:
            print(f"✗ 备用接口也失败: {str(e2)}")
            return None

def analyze_etf_data(df):
    """分析ETF数据"""
    if df is None or df.empty:
        return None
    
    analysis = {
        '获取时间': df['获取时间'].iloc[0],
        '数据来源': df['数据来源'].iloc[0],
        '总ETF数': len(df)
    }
    
    # 尝试找到涨跌幅列
    change_col = None
    possible_change_cols = ['涨跌幅', '涨跌%', 'change_percent', 'pct_change', '涨跌']
    for col in possible_change_cols:
        if col in df.columns:
            change_col = col
            break
    
    if change_col:
        # 涨跌统计
        try:
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
                    '涨跌幅': f"+{float(change):.2f}%" if isinstance(change, (int, float)) else f"+{change}%"
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
                    '涨跌幅': f"{float(change):.2f}%" if isinstance(change, (int, float)) else f"{change}%"
                })
        except Exception as e:
            print(f"分析涨跌数据出错: {str(e)}")
    
    # 成交额统计
    amount_col = None
    possible_amount_cols = ['成交额', '成交量', 'amount', 'volume']
    for col in possible_amount_cols:
        if col in df.columns:
            amount_col = col
            break
    
    if amount_col:
        try:
            total_amount = df[amount_col].sum()
            if '成交额' in amount_col:
                analysis['总成交额(亿元)'] = round(total_amount / 100000000, 2)
            else:  # 成交量
                analysis['总成交量(亿份)'] = round(total_amount / 100000000, 2)
        except Exception as e:
            print(f"分析成交数据出错: {str(e)}")
    
    # ETF类型分布
    if '类型' in df.columns:
        type_stats = df['类型'].value_counts()
        analysis['类型分布'] = {}
        
        for etf_type, count in type_stats.items():
            analysis['类型分布'][etf_type] = {
                '数量': count,
                '比例': f"{count/len(df)*100:.2f}%"
            }
    
    return analysis

def display_etf_analysis(analysis):
    """显示ETF分析结果"""
    if not analysis:
        print("无分析数据")
        return
    
    print("\n" + "="*60)
    print(f"ETF实时数据分析 - {analysis['获取时间']}")
    print(f"数据来源: {analysis['数据来源']}")
    print("="*60)
    
    print(f"总ETF数: {analysis['总ETF数']}")
    
    if '上涨数' in analysis:
        print(f"\n涨跌分布:")
        print(f"  上涨: {analysis['上涨数']} ({analysis['上涨比例']})")
        print(f"  下跌: {analysis['下跌数']} ({analysis['下跌比例']})")
        print(f"  平盘: {analysis['平盘数']}")
        
        print(f"\n涨幅榜前10:")
        for etf in analysis['涨幅榜']:
            print(f"  {etf['代码']} {etf['名称']}: {etf['价格']} {etf['涨跌幅']}")
        
        print(f"\n跌幅榜前10:")
        for etf in analysis['跌幅榜']:
            print(f"  {etf['代码']} {etf['名称']}: {etf['价格']} {etf['涨跌幅']}")
    
    if '总成交额(亿元)' in analysis:
        print(f"\n总成交额: {analysis['总成交额(亿元)']} 亿元")
    
    if '总成交量(亿份)' in analysis:
        print(f"\n总成交量: {analysis['总成交量(亿份)']} 亿份")
    
    if '类型分布' in analysis:
        print(f"\nETF类型分布:")
        for etf_type, stats in analysis['类型分布'].items():
            print(f"  {etf_type}: {stats['数量']} ({stats['比例']})")

def save_etf_data(df, analysis):
    """保存ETF数据"""
    if df is None or df.empty:
        return
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    source = analysis['数据来源'] if analysis else 'unknown'
    
    # 保存原始数据
    data_file = f"etf_realtime_{source}_{timestamp}.csv"
    df.to_csv(data_file, index=False, encoding='utf-8-sig')
    print(f"\nETF数据已保存到: {data_file}")
    
    # 保存分析结果
    if analysis:
        import json
        analysis_file = f"etf_analysis_{source}_{timestamp}.json"
        
        with open(analysis_file, 'w', encoding='utf-8') as f:
            json.dump(analysis, f, ensure_ascii=False, indent=2)
        
        print(f"分析结果已保存到: {analysis_file}")

def main():
    print("="*60)
    print("ETF实时数据获取系统")
    print("="*60)
    
    # 获取ETF实时数据
    df = get_etf_realtime_data()
    
    if df is not None:
        # 分析数据
        analysis = analyze_etf_data(df)
        
        # 显示分析
        display_etf_analysis(analysis)
        
        # 保存数据
        save_etf_data(df, analysis)
        
        print("\n✓ ETF实时数据获取完成")
    else:
        print("\n✗ 未能获取到ETF实时数据")

if __name__ == "__main__":
    main()