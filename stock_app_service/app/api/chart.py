# -*- coding: utf-8 -*-
"""图表相关API路由 - Redis版本"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Dict, Any
from datetime import datetime
import json
import pandas as pd
import os
import uuid
from pathlib import Path

from app.core.redis_client import get_redis_client
from app.core.sync_redis_client import get_sync_redis_client  # 新增：同步Redis
from app.api.dependencies import verify_token
from app.core.config import CHART_DIR
from app.core.logging import logger
from app import indicators
from app.charts import generate_chart_html

router = APIRouter(tags=["股票图表"])

# 确保图表目录存在
os.makedirs(CHART_DIR, exist_ok=True)

@router.get("/api/stocks/{stock_code}/chart", summary="生成股票K线图表", dependencies=[Depends(verify_token)])
async def generate_stock_chart(
    stock_code: str,
    strategy: str = Query("volume_wave", description="图表策略类型: volume_wave(动量守恒) 或 trend_continuation(趋势延续)"),
    theme: str = Query("dark", description="图表主题: light(亮色) 或 dark(暗色)")
) -> Dict[str, Any]:
    """
    生成指定股票的K线图表
    
    Args:
        stock_code: 股票代码
        strategy: 策略类型，可选 'volume_wave'(动量守恒) 或 'trend_continuation'(趋势延续)
        theme: 图表主题，可选 'light'(亮色背景) 或 'dark'(暗色背景)，默认暗色
        
    Returns:
        图表URL和其他信息
    """
    # 检查策略类型
    if strategy not in ["volume_wave", "trend_continuation"]:
        raise HTTPException(status_code=400, detail=f"不支持的策略类型: {strategy}")
    
    # 检查主题类型
    if theme not in ["light", "dark"]:
        theme = "dark"  # 默认暗色主题
    
    try:
        # 直接使用同步Redis客户端，完全避免事件循环问题
        logger.info("使用同步Redis客户端获取数据（避免事件循环冲突）")
        redis_client = get_sync_redis_client()
        
        # 检查股票是否存在并转换为ts_code格式
        stock_codes_key = "stocks:codes:all"
        stock_codes_data = redis_client.get(stock_codes_key)
        
        if not stock_codes_data:
            raise HTTPException(status_code=500, detail="股票代码数据不可用")
        
        stock_codes = json.loads(stock_codes_data)
        stock_info = None
        ts_code = None
        
        # 支持多种格式的股票代码查找
        for stock in stock_codes:
            # 检查ts_code格式 (如: 000001.SZ)
            if stock.get('ts_code') == stock_code:
                stock_info = stock
                ts_code = stock_code
                break
            # 检查symbol格式 (如: 000001)
            elif stock.get('symbol') == stock_code:
                stock_info = stock
                ts_code = stock.get('ts_code')
                break
            # 检查ts_code去掉后缀后是否匹配
            elif stock.get('ts_code', '').split('.')[0] == stock_code:
                stock_info = stock
                ts_code = stock.get('ts_code')
                break
        
        if not stock_info or not ts_code:
            raise HTTPException(status_code=404, detail=f"股票代码 {stock_code} 不存在")
        
        # 获取股票历史数据（同步方式）
        kline_key = f"stock_trend:{ts_code}"
        logger.info(f"正在获取股票 {stock_code} (ts_code: {ts_code}) 的历史数据，Redis键: {kline_key}")
        
        kline_data = redis_client.get(kline_key)
        
        if not kline_data:
            # 检查Redis中是否有相关的股票数据
            logger.warning(f"Redis中没有找到股票 {stock_code} 的历史数据，键: {kline_key}")
            
            # 尝试查找是否有其他格式的数据
            all_keys = []
            try:
                # 查找相关的键（同步方式）
                for key in redis_client.scan_iter(match=f"stock_trend:*{stock_code[:6]}*"):
                    all_keys.append(key)
                    
                if all_keys:
                    logger.info(f"找到相关的股票数据键: {all_keys}")
                else:
                    logger.warning(f"Redis中没有找到任何包含 {stock_code[:6]} 的股票数据")
                    
                # 检查是否正在进行数据初始化
                init_status = redis_client.get("stock_data_init_status")
                    
                if init_status:
                    logger.info(f"当前股票数据初始化状态: {init_status}")
                    
            except Exception as scan_error:
                logger.error(f"扫描Redis键时出错: {scan_error}")
            
            raise HTTPException(status_code=404, detail=f"股票 {stock_code} 没有历史数据。可能原因：1) 数据正在初始化中 2) 股票代码不存在 3) 数据获取失败")
        
        # 解析数据，处理不同的存储格式
        trend_data = json.loads(kline_data)
        
        # 处理不同的数据格式
        if isinstance(trend_data, dict):
            # 新格式：{data: [...], updated_at: ..., source: ...}
            kline_json = trend_data.get('data', [])
        elif isinstance(trend_data, list):
            # 旧格式：直接是K线数据列表
            kline_json = trend_data
        else:
            raise HTTPException(status_code=400, detail=f"股票 {stock_code} 数据格式不正确")
        
        if not kline_json or len(kline_json) < 20:
            raise HTTPException(status_code=400, detail=f"股票 {stock_code} 历史数据不足")
        
        # 转换为DataFrame
        df = pd.DataFrame(kline_json)
        
        # 智能字段映射：修复数据格式混乱导致的图表1根K线bug
        logger.info(f"原始数据列: {df.columns.tolist()}")
        logger.info(f"数据行数: {len(df)}")
        
        # 关键修复：统一处理日期字段
        if 'date' not in df.columns:
            if 'trade_date' in df.columns:
                # tushare格式：trade_date为 20250102
                def convert_tushare_date(date_str):
                    date_str = str(date_str)
                    if len(date_str) == 8 and date_str.isdigit():
                        return f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
                    return date_str
                
                df['date'] = pd.to_datetime(df['trade_date'].apply(convert_tushare_date))
                logger.info("从trade_date转换date字段成功")
            elif 'actual_trade_date' in df.columns:
                # 实际交易日期
                df['date'] = pd.to_datetime(df['actual_trade_date'])
                logger.info("从actual_trade_date转换date字段成功")
            else:
                # 最后兜底：使用索引生成日期
                df['date'] = pd.date_range(start='2024-01-01', periods=len(df), freq='D')
                logger.warning("使用默认日期范围")
        else:
            # 已经有date字段，确保是日期格式
            df['date'] = pd.to_datetime(df['date'])
            logger.info("date字段已存在，转换为datetime格式")
        
        # 关键修复：统一处理成交量字段，确保所有行都有有效的volume值
        logger.info("开始修复成交量字段...")
        
        # 检查volume字段情况
        has_volume = 'volume' in df.columns
        has_vol = 'vol' in df.columns
        
        logger.info(f"字段情况: has_volume={has_volume}, has_vol={has_vol}")
        
        if has_volume:
            # 检查volume字段中的空值情况
            volume_null_count = df['volume'].isnull().sum()
            volume_zero_count = (df['volume'] == 0).sum()
            volume_valid_count = len(df) - volume_null_count - volume_zero_count
            logger.info(f"volume字段分析: 空值={volume_null_count}, 零值={volume_zero_count}, 有效值={volume_valid_count}")
            
            # 如果volume字段大部分为空或零，尝试从vol字段补充
            if volume_null_count + volume_zero_count > len(df) * 0.8 and has_vol:
                logger.info("volume字段大部分无效，从vol字段补充...")
                # 用vol字段填补volume字段的空值和零值
                df['volume'] = df.apply(lambda row: 
                    row['vol'] * 100 if (pd.isnull(row['volume']) or row['volume'] == 0) and pd.notnull(row['vol']) and row['vol'] > 0
                    else row['volume'], axis=1)
                
                # 再次检查修复效果
                volume_null_count_after = df['volume'].isnull().sum()
                volume_zero_count_after = (df['volume'] == 0).sum()
                volume_valid_count_after = len(df) - volume_null_count_after - volume_zero_count_after
                logger.info(f"修复后volume字段: 空值={volume_null_count_after}, 零值={volume_zero_count_after}, 有效值={volume_valid_count_after}")
        
        if not has_volume and has_vol:
            # 如果没有volume字段但有vol字段，直接转换
            logger.info("没有volume字段，从vol字段创建...")
            df['volume'] = df['vol'].fillna(0) * 100
            logger.info(f"创建volume字段成功，有效值: {(df['volume'] > 0).sum()}")
        elif not has_volume and not has_vol:
            # 如果两个字段都没有，创建默认值
            logger.warning("没有任何成交量字段，创建默认值")
            df['volume'] = 1000  # 给一个非零默认值，避免图表显示问题
        
        # 最终确保volume字段没有空值和负值
        df['volume'] = df['volume'].fillna(1000)  # 空值填充为1000
        df['volume'] = df['volume'].apply(lambda x: max(x, 1) if x != 0 else 1000)  # 确保都是正值
        
        # 检查最终的volume字段
        final_volume_valid = (df['volume'] > 0).sum()
        logger.info(f"最终volume字段检查: 总行数={len(df)}, 有效值={final_volume_valid}")
        
        if final_volume_valid != len(df):
            logger.error(f"volume字段仍有问题: {len(df) - final_volume_valid} 行无效")
            # 强制修复
            df.loc[df['volume'] <= 0, 'volume'] = 1000
            logger.info(f"强制修复volume字段完成")
        
        # 处理成交额字段
        if 'amount' in df.columns:
            # tushare格式：amount (单位：千元，需要乘以1000)
            # 如果金额小于1000000，认为是千元单位，需要乘以1000
            df['amount'] = df['amount'].apply(lambda x: x * 1000 if x > 0 and x < 1000000 else x)
        
        logger.info(f"转换后数据列: {df.columns.tolist()}")
        logger.info(f"数据量: {len(df)} 条")
        
        # 验证必要列
        required_columns = ['close', 'open', 'high', 'low', 'volume']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise HTTPException(status_code=400, detail=f"数据缺少必要列: {missing_columns}")
        
        # 应用策略
        try:
            processed_df, signals = indicators.apply_strategy(strategy, df)
            logger.info(f"策略应用成功 {stock_code}: 生成 {len(signals)} 个信号")
        except Exception as e:
            logger.error(f"策略应用失败 {stock_code}: {str(e)}")
            raise HTTPException(status_code=500, detail=f"策略应用失败: {str(e)}")
        
        # 为动量守恒策略添加额外的EMA指标（仅用于图表展示）
        if strategy == 'volume_wave':
            try:
                close_values = processed_df['close'].to_numpy()
                
                # 计算EMA12（如果不存在）
                if 'ema12' not in processed_df.columns:
                    from app.indicators.volume_wave_strategy import VolumeWaveStrategy
                    processed_df['ema12'] = pd.Series(VolumeWaveStrategy.calculate_ema(close_values, 12))
                
                # 计算EMA144（Vegas隧道下轨）
                if 'ema144' not in processed_df.columns:
                    from app.indicators.volume_wave_strategy import VolumeWaveStrategy
                    processed_df['ema144'] = pd.Series(VolumeWaveStrategy.calculate_ema(close_values, 144))
                
                # 计算EMA169（Vegas隧道上轨）
                if 'ema169' not in processed_df.columns:
                    from app.indicators.volume_wave_strategy import VolumeWaveStrategy
                    processed_df['ema169'] = pd.Series(VolumeWaveStrategy.calculate_ema(close_values, 169))
                
                logger.info(f"已为图表添加Vegas隧道指标（EMA12, EMA144, EMA169）")
            except Exception as ema_error:
                logger.warning(f"添加额外EMA指标失败（不影响信号计算）: {ema_error}")
        
        # 准备图表数据
        stock_data = {
            'stock': {
                'code': stock_code,
                'name': stock_info.get('name', stock_code)
            },
            'data': processed_df,
            'signals': signals,
            'strategy': strategy,
            'theme': theme  # 添加主题参数
        }
        
        # 清理旧图表文件
        cleanup_old_charts()
        
        # 生成图表
        try:
            chart_url = await generate_chart_from_redis_data(stock_data)
            if not chart_url:
                raise HTTPException(status_code=500, detail=f"生成股票 {stock_code} 的图表失败：HTML生成返回空")
            logger.info(f"图表生成成功 {stock_code}: {chart_url}")
        except Exception as e:
            logger.error(f"图表生成失败 {stock_code}: {str(e)}")
            raise HTTPException(status_code=500, detail=f"图表生成失败: {str(e)}")
        
        # 同步Redis使用连接池，不需要关闭
        
        return {
            "code": stock_code,
            "name": stock_info.get('name', stock_code),
            "chart_url": chart_url,
            "strategy": strategy,
            "signals_count": len(signals),
            "generated_time": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"图表生成错误: {str(e)}")

@router.get("/api/chart/{stock_code}", summary="查看股票图表页面")
async def view_stock_chart(
    stock_code: str,
    strategy: str = Query("volume_wave", description="图表策略类型: volume_wave(量能波动) 或 trend_continuation(趋势延续)"),
    theme: str = Query("dark", description="图表主题: light(亮色) 或 dark(暗色)")
):
    """
    查看指定股票的K线图表页面
    
    Args:
        stock_code: 股票代码
        strategy: 策略类型，可选 'volume_wave'(量能波动) 或 'trend_continuation'(趋势延续)
        theme: 图表主题，可选 'light'(亮色背景) 或 'dark'(暗色背景)，默认暗色
        
    Returns:
        重定向到图表HTML页面
    """
    from fastapi.responses import RedirectResponse
    
    # 检查策略类型
    if strategy not in ["volume_wave", "trend_continuation"]:
        raise HTTPException(status_code=400, detail=f"不支持的策略类型: {strategy}")
    
    # 检查主题类型
    if theme not in ["light", "dark"]:
        theme = "dark"  # 默认暗色主题
    
    try:
        # 生成图表，传递主题参数
        chart_result = await generate_stock_chart(stock_code, strategy, theme)
        chart_url = chart_result.get('chart_url')
        
        if not chart_url:
            raise HTTPException(status_code=500, detail=f"生成股票 {stock_code} 的图表失败")
        
        # 重定向到图表页面
        return RedirectResponse(url=chart_url)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"图表生成错误: {str(e)}")

async def generate_chart_from_redis_data(stock_data: Dict[str, Any]) -> str:
    """
    从Redis数据生成图表的辅助函数
    
    Args:
        stock_data: 包含股票信息、数据、信号和主题的字典
        
    Returns:
        图表URL
    """
    try:
        stock = stock_data['stock']
        strategy = stock_data['strategy']
        theme = stock_data.get('theme', 'dark')  # 获取主题，默认暗色
        
        # 生成唯一文件名
        chart_file = f"{stock['code']}_{strategy}_{theme}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid.uuid4().hex[:8]}.html"
        chart_path = os.path.join(CHART_DIR, chart_file)
        
        # 生成HTML内容，传递主题参数
        html_content = generate_chart_html(strategy, stock_data, theme=theme)
        
        if not html_content:
            return None
        
        # 直接使用同步文件写入（文件I/O很快，不会阻塞）
        # 这样可以完全避免事件循环冲突问题
        _write_chart_file(chart_path, html_content)
        
        # 返回图表URL
        return f"/static/charts/{chart_file}"
        
    except Exception as e:
        logger.error(f"生成图表时出错: {str(e)}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        return None

def _write_chart_file(file_path: str, content: str):
    """同步写入图表文件（在线程池中执行）"""
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        logger.debug(f"图表文件写入成功: {file_path}")
    except Exception as e:
        logger.error(f"图表文件写入失败: {file_path}, 错误: {e}")
        raise

def cleanup_old_charts(max_files: int = 100):
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