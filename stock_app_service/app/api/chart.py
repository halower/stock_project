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