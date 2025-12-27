# -*- coding: utf-8 -*-
"""
指标自动渲染器

根据指标注册表中的配置，自动计算和渲染所有指标
实现"一次编写，到处可用"的设计理念
"""

from typing import Dict, List, Any, Optional
import pandas as pd
from app.core.logging import logger
from app.trading.indicators.indicator_registry import IndicatorRegistry, IndicatorDefinition


class IndicatorAutoRenderer:
    """指标自动渲染器"""
    
    @classmethod
    def calculate_all_indicators(cls, df: pd.DataFrame) -> Dict[str, Any]:
        """
        计算所有已注册指标的数据
        
        Args:
            df: 股票数据DataFrame
            
        Returns:
            指标数据字典 {indicator_id: calculated_data}
        """
        indicator_data = {}
        all_indicators = IndicatorRegistry.get_all()
        
        for indicator_id, indicator_def in all_indicators.items():
            try:
                # 跳过复合指标（由子指标组成）
                if indicator_def.is_composite:
                    continue
                
                # 计算指标数据
                data = IndicatorRegistry.calculate(indicator_id, df)
                indicator_data[indicator_id] = data
                
                logger.debug(f"✅ 计算指标: {indicator_def.name} ({indicator_id})")
                
            except Exception as e:
                logger.warning(f"计算指标 {indicator_def.name} ({indicator_id}) 失败: {e}")
                indicator_data[indicator_id] = None
        
        return indicator_data
    
    @classmethod
    def prepare_indicator_data_for_js(cls, indicator_id: str, data: Any, df: pd.DataFrame) -> Optional[List[Dict]]:
        """
        将指标数据转换为JavaScript可用的格式
        
        Args:
            indicator_id: 指标ID
            data: 计算后的指标数据
            df: 原始DataFrame（用于获取时间索引）
            
        Returns:
            JavaScript格式的数据列表，或None
        """
        if data is None:
            return None
        
        indicator_def = IndicatorRegistry.get(indicator_id)
        if not indicator_def:
            return None
        
        # 根据渲染类型处理数据
        if indicator_def.render_type == 'line':
            # 线条类型：转换为 [{time, value}] 格式
            return cls._prepare_line_data(data, df)
        
        elif indicator_def.render_type == 'overlay':
            # 叠加类型：根据指标ID特殊处理
            if indicator_id == 'pivot_order_blocks':
                return cls._prepare_pivot_order_blocks_data(data, df)
            elif indicator_id == 'divergence_detector':
                return cls._prepare_divergence_data(data, df)
            else:
                # 其他叠加类型：保持原始格式
                return data if isinstance(data, (list, dict)) else None
        
        elif indicator_def.render_type == 'subchart':
            # 副图类型：保持原始格式
            return data if isinstance(data, (list, dict)) else None
        
        else:
            logger.warning(f"未知的渲染类型: {indicator_def.render_type}")
            return None
    
    @classmethod
    def _get_time_string(cls, df: pd.DataFrame, idx: int) -> str:
        """
        获取指定索引的时间字符串
        
        Args:
            df: DataFrame
            idx: 索引
            
        Returns:
            时间字符串（YYYY-MM-DD格式）
        """
        try:
            if 'date' in df.columns:
                date_value = df.iloc[idx]['date']
                if pd.notna(date_value):
                    if hasattr(date_value, 'strftime'):
                        return date_value.strftime('%Y-%m-%d')
                    else:
                        return str(date_value).split(' ')[0]
            
            # 降级：使用索引
            return str(idx)
        except Exception as e:
            logger.warning(f"获取时间字符串失败 (idx={idx}): {e}")
            return str(idx)
    
    @classmethod
    def _prepare_pivot_order_blocks_data(cls, data: Optional[List[Dict]], df: pd.DataFrame) -> List[Dict]:
        """
        转换 Pivot Order Blocks 数据格式
        
        将 start_index/end_index 转换为 start_time/end_time
        
        Args:
            data: 原始订单块数据
            df: DataFrame
            
        Returns:
            转换后的数据
        """
        if not data or not isinstance(data, list):
            return []
        
        result = []
        for block in data:
            try:
                result.append({
                    'type': block.get('type', 'support'),
                    'price_high': float(block.get('price_high', 0)),
                    'price_low': float(block.get('price_low', 0)),
                    'start_time': cls._get_time_string(df, block.get('start_index', 0)),
                    'end_time': cls._get_time_string(df, block.get('end_index', len(df) - 1)),
                    'strength': float(block.get('strength', 0.8))
                })
            except Exception as e:
                logger.warning(f"转换订单块数据失败: {e}")
                continue
        
        logger.debug(f"转换 Pivot Order Blocks: {len(data)} -> {len(result)} 个区域")
        return result
    
    @classmethod
    def _prepare_divergence_data(cls, data: Optional[List[Dict]], df: pd.DataFrame) -> List[Dict]:
        """
        转换背离检测数据格式（如果需要的话）
        
        Args:
            data: 原始背离数据
            df: DataFrame
            
        Returns:
            转换后的数据
        """
        # 背离数据通常已经是正确格式，直接返回
        if not data or not isinstance(data, list):
            return []
        return data
    
    @classmethod
    def _prepare_line_data(cls, data: Any, df: pd.DataFrame) -> List[Dict]:
        """准备线条数据"""
        result = []
        
        # 如果是Series，转换为列表
        if hasattr(data, 'values'):
            values = data.values
        else:
            values = data
        
        # 获取日期列
        if 'date' in df.columns:
            dates = df['date']
        elif hasattr(df, 'index'):
            dates = df.index
        else:
            logger.warning("无法获取日期数据")
            return result
        
        # 转换为 [{time, value}] 格式
        for i, (date, value) in enumerate(zip(dates, values)):
            if pd.notna(value):
                time_str = date.strftime('%Y-%m-%d') if hasattr(date, 'strftime') else str(date)
                result.append({
                    'time': time_str,
                    'value': float(value)
                })
        
        return result
    
    @classmethod
    def generate_indicator_pool_config(cls, df: pd.DataFrame) -> Dict[str, Any]:
        """
        生成指标池配置（INDICATOR_POOL）
        
        该配置会被传递给前端JavaScript，用于渲染指标
        
        Args:
            df: 股票数据DataFrame
            
        Returns:
            指标池配置字典
        """
        indicator_pool = {}
        
        # 获取所有指标
        all_indicators = IndicatorRegistry.get_all()
        
        # 计算所有指标数据
        indicator_data = cls.calculate_all_indicators(df)
        
        # 构建指标池配置
        for indicator_id, indicator_def in all_indicators.items():
            # 获取计算后的数据
            raw_data = indicator_data.get(indicator_id)
            
            # 转换为JavaScript格式
            js_data = cls.prepare_indicator_data_for_js(indicator_id, raw_data, df)
            
            # 构建配置
            config = {
                'name': indicator_def.name,
                'category': indicator_def.category,
                'renderType': indicator_def.render_type,
                'enabled': indicator_def.enabled_by_default,
                'data': js_data,
                'color': indicator_def.color
            }
            
            # 如果是复合指标
            if indicator_def.is_composite:
                config['isComposite'] = True
                config['subIndicators'] = indicator_def.sub_indicators
            
            # 如果有render_config，添加到配置中
            if indicator_def.render_config:
                config['renderConfig'] = indicator_def.render_config
            
            # 如果有自定义渲染函数，添加函数名
            if indicator_def.render_config and 'render_function' in indicator_def.render_config:
                config['renderFunction'] = indicator_def.render_config['render_function']
            
            indicator_pool[indicator_id] = config
        
        logger.info(f"✅ 生成指标池配置，共 {len(indicator_pool)} 个指标")
        
        return indicator_pool
    
    @classmethod
    def generate_indicator_pool_js(cls, indicator_pool: Dict[str, Any]) -> str:
        """
        生成指标池JavaScript代码
        
        Args:
            indicator_pool: 指标池配置
            
        Returns:
            JavaScript代码字符串
        """
        import json
        
        # 将配置转换为JSON
        indicator_pool_json = json.dumps(indicator_pool, ensure_ascii=False, indent=2)
        
        # 生成JavaScript代码
        js_code = f"""
        // 指标池配置（自动生成）
        const INDICATOR_POOL = {indicator_pool_json};
        """
        
        return js_code

