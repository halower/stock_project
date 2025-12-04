# -*- coding: utf-8 -*-
"""
指数图表服务 - 使用动量守恒增强版策略绘制指数图表
"""

import pandas as pd
import os
import uuid
from typing import Dict, Any, Optional
from datetime import datetime
from app.core.logging import logger
from app.core.config import CHART_DIR
from app.charts import generate_chart_html
from app import indicators
from app.services.index.index_service import index_service


# 确保图表目录存在
os.makedirs(CHART_DIR, exist_ok=True)


class IndexChartService:
    """指数图表服务类"""
    
    def __init__(self):
        """初始化指数图表服务"""
        logger.info("指数图表服务初始化成功")
    
    async def generate_index_chart(
        self,
        index_code: str = "000001.SH",
        days: int = 180,
        theme: str = "dark"
    ) -> Dict[str, Any]:
        """
        生成指数图表HTML文件
        
        Args:
            index_code: 指数代码，默认000001.SH（上证指数）
            days: 获取天数，默认180天
            theme: 图表主题，light或dark
            
        Returns:
            {
                'success': bool,
                'chart_url': str,  # 图表URL
                'index_code': str,
                'index_name': str,
                'error': str  # 错误信息（如果失败）
            }
        """
        try:
            logger.info(f"开始生成指数 {index_code} 的图表，天数: {days}, 主题: {theme}")
            
            # 1. 获取指数日线数据
            index_data = await index_service.get_index_daily(index_code, days)
            
            if not index_data['success'] or not index_data['data']:
                return {
                    'success': False,
                    'error': index_data.get('error', '获取指数数据失败'),
                    'index_code': index_code
                }
            
            # 2. 转换为DataFrame
            df = pd.DataFrame(index_data['data'])
            
            # 确保数据格式正确
            if 'trade_date' in df.columns:
                # 转换trade_date格式 (20250102 -> 2025-01-02)
                def convert_date(date_str):
                    date_str = str(date_str)
                    if len(date_str) == 8 and date_str.isdigit():
                        return f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
                    return date_str
                
                df['date'] = pd.to_datetime(df['trade_date'].apply(convert_date))
            else:
                df['date'] = pd.to_datetime(df['date'])
            
            df = df.sort_values('date').reset_index(drop=True)
            
            # 重命名列以匹配图表策略的要求
            if 'vol' in df.columns and 'volume' not in df.columns:
                df['volume'] = df['vol']
            
            # 确保所有必需的列都存在
            required_columns = ['date', 'open', 'high', 'low', 'close', 'volume']
            for col in required_columns:
                if col not in df.columns:
                    logger.error(f"缺少必需列: {col}")
                    return {
                        'success': False,
                        'error': f'数据格式错误，缺少{col}列',
                        'index_code': index_code
                    }
            
            # 3. 应用动量守恒增强版策略
            try:
                processed_df, signals = indicators.apply_strategy('volume_wave_enhanced', df)
                logger.info(f"策略应用成功: 生成 {len(signals)} 个信号")
            except Exception as e:
                logger.error(f"策略应用失败: {e}")
                return {
                    'success': False,
                    'error': f'策略应用失败: {str(e)}',
                    'index_code': index_code
                }
            
            # 4. 准备图表数据
            stock_data = {
                'stock': {
                    'code': index_code,
                    'name': index_data['index_name']
                },
                'data': processed_df,
                'signals': signals,
                'strategy': 'volume_wave_enhanced',
                'theme': theme
            }
            
            # 5. 生成图表HTML
            try:
                chart_file = f"index_{index_code.replace('.', '_')}_{theme}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid.uuid4().hex[:8]}.html"
                chart_path = os.path.join(CHART_DIR, chart_file)
                
                # 生成HTML内容
                html_content = generate_chart_html('volume_wave_enhanced', stock_data, theme=theme)
                
                if not html_content:
                    return {
                        'success': False,
                        'error': '生成图表HTML失败',
                        'index_code': index_code
                    }
                
                # 写入文件
                with open(chart_path, 'w', encoding='utf-8') as f:
                    f.write(html_content)
                
                chart_url = f"/static/charts/{chart_file}"
                
                logger.info(f"成功生成指数 {index_code} 的图表: {chart_url}")
                
                return {
                    'success': True,
                    'chart_url': chart_url,
                    'index_code': index_code,
                    'index_name': index_data['index_name']
                }
                
            except Exception as e:
                logger.error(f"生成图表文件失败: {e}")
                import traceback
                logger.error(traceback.format_exc())
                return {
                    'success': False,
                    'error': f'生成图表文件失败: {str(e)}',
                    'index_code': index_code
                }
            
        except Exception as e:
            logger.error(f"生成指数图表失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'error': str(e),
                'index_code': index_code
            }
    
    async def get_index_analysis(
        self,
        index_code: str = "000001.SH",
        days: int = 180,
        theme: str = "dark"
    ) -> Dict[str, Any]:
        """
        获取指数分析数据（包含图表和统计信息）
        
        Args:
            index_code: 指数代码
            days: 获取天数
            theme: 图表主题
            
        Returns:
            {
                'success': bool,
                'chart_url': str,  # 图表URL
                'statistics': Dict,  # 统计信息
                'index_code': str,
                'index_name': str
            }
        """
        try:
            # 1. 生成图表
            chart_result = await self.generate_index_chart(index_code, days, theme)
            
            if not chart_result['success']:
                return chart_result
            
            # 2. 获取原始数据用于统计
            index_data = await index_service.get_index_daily(index_code, days)
            
            if not index_data['success']:
                return chart_result  # 至少返回图表数据
            
            # 3. 计算统计信息
            df = pd.DataFrame(index_data['data'])
            
            statistics = {
                'latest_close': float(df.iloc[-1]['close']),
                'latest_change': float(df.iloc[-1]['change']),
                'latest_pct_chg': float(df.iloc[-1]['pct_chg']),
                'period_high': float(df['high'].max()),
                'period_low': float(df['low'].min()),
                'period_avg': float(df['close'].mean()),
                'total_volume': float(df['vol'].sum()),
                'total_amount': float(df['amount'].sum()),
                'up_days': int((df['pct_chg'] > 0).sum()),
                'down_days': int((df['pct_chg'] < 0).sum()),
                'period_return': float((df.iloc[-1]['close'] - df.iloc[0]['close']) / df.iloc[0]['close'] * 100)
            }
            
            chart_result['statistics'] = statistics
            
            logger.info(f"成功生成指数 {index_code} 的分析数据")
            
            return chart_result
            
        except Exception as e:
            logger.error(f"获取指数分析数据失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'error': str(e),
                'index_code': index_code
            }


# 创建全局实例
index_chart_service = IndexChartService()
