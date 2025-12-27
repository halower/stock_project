# -*- coding: utf-8 -*-
"""
指标池混入类补丁 - 实现混合策略

将此方法替换到 indicator_pool_mixin.py 中的对应方法
"""

@classmethod
def _generate_indicator_metadata_only(cls, df: pd.DataFrame = None) -> Dict[str, Any]:
    """
    生成指标池元数据配置（智能混合策略）
    
    策略：
    - 轻量级指标（EMA等）：data=None，前端计算
    - 重量级指标（背离检测等）：data=预计算，服务端计算
    
    Args:
        df: 股票数据DataFrame（可选，用于服务端预计算重量级指标）
    
    Returns:
        指标池配置字典
    """
    from app.trading.indicators.indicator_registry import IndicatorRegistry
    from app.trading.renderers.indicator_auto_renderer import IndicatorAutoRenderer
    
    indicator_pool = {}
    all_indicators = IndicatorRegistry.get_all()
    
    # 定义轻量级指标列表（前端计算，快速加载）
    lightweight_indicators = {
        'ema6', 'ema12', 'ema18', 'ema144', 'ema169',
        'mirror_candle',  # 镜像K线：前端计算
    }
    
    # 定义重量级指标列表（服务端计算，避免维护两套代码）
    heavyweight_indicators = {
        'divergence_detector',  # 背离检测：复杂，服务端计算
        'volume_profile_pivot',  # 成交量分布：计算量大，服务端计算
        'pivot_order_blocks',  # 支撑阻力：服务端计算更稳定
    }
    
    for indicator_id, indicator_def in all_indicators.items():
        # 构建基础配置
        config = {
            'name': indicator_def.name,
            'category': indicator_def.category,
            'renderType': indicator_def.render_type,
            'enabled': indicator_def.enabled_by_default,
            'color': indicator_def.color,
            'params': indicator_def.default_params
        }
        
        # 智能选择计算方式
        if indicator_id in lightweight_indicators:
            # 轻量级：前端计算
            config['data'] = None
            logger.debug(f"📱 {indicator_def.name}: 前端计算")
        elif indicator_id in heavyweight_indicators and df is not None:
            # 重量级：服务端预计算
            try:
                logger.debug(f"🖥️  开始计算 {indicator_def.name}...")
                calculated_data = IndicatorRegistry.calculate(indicator_id, df)
                
                # 转换为JS格式
                js_data = IndicatorAutoRenderer.prepare_indicator_data_for_js(
                    indicator_id, calculated_data, df
                )
                config['data'] = js_data
                
                logger.info(f"✅ {indicator_def.name}: 服务端预计算完成，数据量: {len(js_data) if isinstance(js_data, list) else 'N/A'}")
            except Exception as e:
                logger.warning(f"⚠️  服务端计算 {indicator_def.name} 失败: {e}")
                config['data'] = None
        else:
            # 默认：尝试前端计算
            config['data'] = None
            logger.debug(f"⚡ {indicator_def.name}: 尝试前端计算")
        
        # 如果是复合指标
        if indicator_def.is_composite:
            config['isComposite'] = True
            config['subIndicators'] = indicator_def.sub_indicators
        
        # 如果有render_config
        if indicator_def.render_config:
            config['renderConfig'] = indicator_def.render_config
            if 'render_function' in indicator_def.render_config:
                config['renderFunction'] = indicator_def.render_config['render_function']
        
        indicator_pool[indicator_id] = config
    
    # 统计
    lightweight_count = sum(1 for id in indicator_pool.keys() if id in lightweight_indicators)
    heavyweight_count = sum(1 for id in indicator_pool.keys() if id in heavyweight_indicators)
    
    logger.info(f"✅ 生成指标配置（混合策略）: 总计 {len(indicator_pool)} 个")
    logger.info(f"   - 轻量级（前端计算）: {lightweight_count} 个")
    logger.info(f"   - 重量级（服务端计算）: {heavyweight_count} 个")
    
    return indicator_pool

