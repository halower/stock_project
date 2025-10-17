# -*- coding: utf-8 -*-
"""
MCP Server - 股票筛选智能服务器
负责编排工具调用和AI分析
"""
import json
import asyncio
import aiohttp
from typing import List, Dict, Any
from datetime import datetime

from app.mcp.tools import (
    get_stock_data_loader,
    get_technical_calculator,
    get_pre_filter_engine
)
from app.core.logging import logger


class StockFilterMCPServer:
    """
    股票筛选MCP服务器
    
    工作流程：
    1. 规则预筛选（1000只 → 100-200只）
    2. 批量准备数据（并行加载）
    3. AI批量分析（单次LLM调用）
    4. 返回结果
    """
    
    def __init__(self):
        self.name = "stock-filter-mcp"
        self.version = "1.0.0"
    
    async def intelligent_filter(
        self,
        criteria: str,
        stock_pool: List[str],
        max_results: int = 20,
        ai_config: Dict[str, str] = None
    ) -> Dict[str, Any]:
        """
        智能筛选主流程
        
        Args:
            criteria: 用户筛选条件（自然语言）
            stock_pool: 股票池代码列表
            max_results: 最多返回结果数
            ai_config: AI配置
                - endpoint: AI服务端点
                - api_key: API密钥
                - model: 模型名称
        
        Returns:
            {
                "success": True/False,
                "selected_stocks": [
                    {
                        "code": "000001",
                        "name": "平安银行",
                        "score": 95,
                        "reason": "突破新高，成交量放大"
                    }
                ],
                "stats": {
                    "total_input": 100,
                    "pre_filtered": 50,
                    "final_selected": 20
                },
                "processing_time": 5.2
            }
        """
        start_time = datetime.now()
        
        try:
            logger.info(f"MCP筛选开始：条件='{criteria}'，候选池={len(stock_pool)}只")
            
            # Phase 1: 规则预筛选
            logger.info("=" * 60)
            logger.info("Phase 1: 规则预筛选")
            pre_filter_engine = get_pre_filter_engine()
            candidates = await pre_filter_engine.pre_filter(stock_pool, criteria)
            logger.info(f"预筛选完成：{len(stock_pool)} → {len(candidates)}只")
            
            # 如果候选数量仍然太多，限制到100只
            if len(candidates) > 100:
                import random
                random.shuffle(candidates)
                candidates = candidates[:100]
                logger.info(f"候选数量过多，随机采样至100只")
            
            if not candidates:
                logger.warning("预筛选后无候选股票")
                return {
                    "success": False,
                    "message": "没有符合条件的股票",
                    "selected_stocks": [],
                    "stats": {
                        "total_input": len(stock_pool),
                        "pre_filtered": 0,
                        "final_selected": 0
                    },
                    "processing_time": 0
                }
            
            # Phase 2: 批量准备数据
            logger.info("=" * 60)
            logger.info("Phase 2: 批量准备数据")
            batch_data = await self._prepare_batch_data(candidates)
            logger.info(f"数据准备完成：{len(batch_data['stock_data'])}只股票")
            
            # Phase 3: AI批量分析
            logger.info("=" * 60)
            logger.info("Phase 3: AI批量分析")
            ai_results = await self._batch_ai_analysis(
                candidates,
                batch_data,
                criteria,
                max_results,
                ai_config
            )
            
            # 计算耗时
            processing_time = (datetime.now() - start_time).total_seconds()
            
            # 添加统计信息
            ai_results['stats'] = {
                "total_input": len(stock_pool),
                "pre_filtered": len(candidates),
                "final_selected": len(ai_results.get('selected_stocks', []))
            }
            ai_results['processing_time'] = round(processing_time, 2)
            
            logger.info("=" * 60)
            logger.info(f"MCP筛选完成：最终{len(ai_results.get('selected_stocks', []))}只，耗时{processing_time:.2f}秒")
            
            return ai_results
            
        except Exception as e:
            logger.error(f"MCP筛选失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            
            return {
                "success": False,
                "message": f"筛选失败: {str(e)}",
                "selected_stocks": [],
                "stats": {
                    "total_input": len(stock_pool),
                    "pre_filtered": 0,
                    "final_selected": 0
                },
                "processing_time": (datetime.now() - start_time).total_seconds()
            }
    
    async def _prepare_batch_data(self, candidates: List[str]) -> Dict[str, Any]:
        """
        并行准备所有候选股票的数据
        """
        # 并行加载股票数据和技术指标
        stock_data_loader = get_stock_data_loader()
        technical_calculator = get_technical_calculator()
        
        stock_data, indicators = await asyncio.gather(
            stock_data_loader.load_batch_data(candidates, days=20),
            technical_calculator.calculate_batch_indicators(
                candidates,
                ['ma', 'volume_ratio', 'trend']
            )
        )
        
        return {
            "stock_data": stock_data,
            "indicators": indicators
        }
    
    async def _batch_ai_analysis(
        self,
        candidates: List[str],
        batch_data: Dict[str, Any],
        criteria: str,
        max_results: int,
        ai_config: Dict[str, str]
    ) -> Dict[str, Any]:
        """
        批量AI分析
        单次LLM调用分析所有候选股票
        """
        # 构建批量Prompt
        prompt = self._build_batch_prompt(
            candidates,
            batch_data,
            criteria,
            max_results
        )
        
        logger.info(f"Prompt总长度：{len(prompt)} 字符")
        
        # 调用LLM
        try:
            response = await self._call_llm(
                prompt,
                ai_config.get('endpoint'),
                ai_config.get('api_key'),
                ai_config.get('model', 'gpt-4')
            )
            
            logger.info(f"LLM响应长度：{len(response)} 字符")
            
            # 解析结果
            result = self._parse_ai_response(response)
            result['success'] = True
            
            return result
            
        except Exception as e:
            logger.error(f"AI分析失败: {e}")
            # 降级方案：基于规则返回
            logger.info("使用规则引擎降级方案")
            return self._fallback_selection(candidates, batch_data, max_results)
    
    def _build_batch_prompt(
        self,
        candidates: List[str],
        batch_data: Dict[str, Any],
        criteria: str,
        max_results: int
    ) -> str:
        """
        构建批量分析Prompt
        关键：数据压缩，减少Token使用
        """
        stock_data = batch_data['stock_data']
        indicators = batch_data['indicators']
        
        # 构建压缩的股票数据描述
        stock_lines = []
        for code in candidates:
            if code not in stock_data:
                continue
            
            data = stock_data[code]
            ind = indicators.get(code, {})
            
            # 压缩格式：一行一只股票
            line = (
                f"[{code}]{data.get('name', '')} "
                f"价{data.get('price', 0):.2f} "
                f"涨{data.get('change_pct', 0):.1f}% "
                f"{data.get('kline_summary', '')} "
                f"均线{ind.get('ma_position', '震荡')} "
                f"量比{ind.get('volume_ratio', 1.0):.1f} "
                f"{ind.get('trend', '')}"
            )
            stock_lines.append(line)
        
        # 构建完整Prompt - 强制JSON输出
        prompt = f"""从以下股票中筛选符合条件的标的，直接返回JSON格式。

筛选条件：{criteria}

候选股票（{len(stock_lines)}只）：
{chr(10).join(stock_lines)}

数据说明：价=收盘价，涨=涨跌幅，均线=多头/空头，量比=成交量倍数，趋势=上涨/下跌

要求：选出最符合条件的股票（最多{max_results}只），给出评分(0-100)和简短理由(不超过20字)。

立即返回JSON格式，不要任何解释：
{{
  "selected_stocks": [
    {{"code": "股票代码", "name": "股票名称", "score": 分数, "reason": "理由"}}
  ]
}}"""
        
        return prompt
    
    async def _call_llm(
        self,
        prompt: str,
        endpoint: str,
        api_key: str,
        model: str
    ) -> str:
        """
        调用LLM服务
        兼容多种API平台：OpenAI、阿里百炼、其他
        """
        # 检测是否是阿里百炼平台
        is_dashscope = 'dashscope.aliyuncs.com' in endpoint
        is_qwen = 'qwen' in model.lower()
        
        # 构建请求体
        request_body = {
            'model': model,
            'messages': [
                {
                    'role': 'system',
                    'content': '你是JSON数据生成器，只返回有效的JSON格式，不返回任何其他文字。'
                },
                {
                    'role': 'user',
                    'content': prompt
                }
            ]
        }
        
        # 温度和token设置（阿里百炼兼容）
        if is_dashscope or is_qwen:
            # 阿里百炼的参数
            request_body['temperature'] = 0.1
            request_body['top_p'] = 0.5  # 阿里百炼建议使用top_p
            request_body['max_tokens'] = 2000
            # 阿里百炼支持result_format
            request_body['result_format'] = 'message'  # 返回message格式
        else:
            # 标准OpenAI格式
            request_body['temperature'] = 0.1
            request_body['max_tokens'] = 2000
            
            # OpenAI的JSON mode
            if 'gpt-4' in model or 'gpt-3.5-turbo-1106' in model or 'gpt-4-turbo' in model:
                request_body['response_format'] = {'type': 'json_object'}
        
        # 构建请求头（阿里百炼兼容）
        headers = {
            'Content-Type': 'application/json',
        }
        
        # 阿里百炼使用X-DashScope-SSE，其他使用Authorization
        if is_dashscope:
            headers['Authorization'] = f'Bearer {api_key}'
            # 阿里百炼可选：headers['X-DashScope-SSE'] = 'disable'
        else:
            headers['Authorization'] = f'Bearer {api_key}'
        
        timeout = aiohttp.ClientTimeout(total=60)
        
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(
                endpoint,
                headers=headers,
                json=request_body
            ) as response:
                
                if response.status != 200:
                    error_text = await response.text()
                    logger.error(f"LLM API调用失败: {response.status}, {error_text}")
                    raise Exception(f"LLM API调用失败: HTTP {response.status}")
                
                json_response = await response.json()
                
                # 兼容多种响应格式
                content = None
                
                # 尝试OpenAI标准格式: choices[0].message.content
                if 'choices' in json_response:
                    choices = json_response.get('choices', [])
                    if choices and len(choices) > 0:
                        message = choices[0].get('message', {})
                        content = message.get('content', '')
                
                # 尝试阿里百炼格式: output.choices[0].message.content 或 output.text
                if not content and 'output' in json_response:
                    output = json_response.get('output', {})
                    # 格式1: output.text (某些模型)
                    if 'text' in output:
                        content = output['text']
                    # 格式2: output.choices[0].message.content
                    elif 'choices' in output:
                        choices = output.get('choices', [])
                        if choices and len(choices) > 0:
                            message = choices[0].get('message', {})
                            content = message.get('content', '')
                
                # 调试日志
                if not content:
                    logger.error(f"无法从响应中提取内容，响应结构: {json_response.keys()}")
                    logger.error(f"完整响应（前500字符）: {str(json_response)[:500]}")
                    raise Exception("LLM返回空内容")
                
                logger.info(f"LLM响应内容长度: {len(content)} 字符")
                return content
    
    def _parse_ai_response(self, response: str) -> Dict[str, Any]:
        """
        解析AI响应
        提取JSON部分
        """
        try:
            # 尝试直接解析
            result = json.loads(response)
            return result
        except json.JSONDecodeError:
            # 提取JSON部分
            try:
                json_start = response.find('{')
                json_end = response.rfind('}') + 1
                
                if json_start == -1 or json_end == 0:
                    raise ValueError("未找到JSON内容")
                
                json_str = response[json_start:json_end]
                result = json.loads(json_str)
                
                return result
            except Exception as e:
                logger.error(f"解析AI响应失败: {e}")
                logger.error(f"原始响应: {response[:500]}")
                raise Exception(f"无法解析AI响应: {str(e)}")
    
    def _fallback_selection(
        self,
        candidates: List[str],
        batch_data: Dict[str, Any],
        max_results: int
    ) -> Dict[str, Any]:
        """
        降级方案：基于规则选择
        当AI不可用时使用
        """
        logger.info("使用规则引擎降级方案进行筛选")
        
        stock_data = batch_data['stock_data']
        indicators = batch_data['indicators']
        
        scored = []
        
        for code in candidates:
            if code not in stock_data:
                continue
            
            data = stock_data[code]
            ind = indicators.get(code, {})
            
            # 基础分50
            score = 50.0
            
            # 涨跌幅加分
            change = data.get('change_pct', 0)
            if change > 5:
                score += 20
            elif change > 2:
                score += 15
            elif change > 0:
                score += 10
            elif change < -5:
                score -= 20
            elif change < -2:
                score -= 15
            
            # 量比加分
            vol_ratio = ind.get('volume_ratio', 1.0)
            if vol_ratio > 2.0:
                score += 15
            elif vol_ratio > 1.5:
                score += 10
            elif vol_ratio < 0.5:
                score -= 10
            
            # 趋势加分
            trend = ind.get('trend', '')
            if '强势上涨' in trend:
                score += 20
            elif '温和上涨' in trend:
                score += 10
            elif '温和下跌' in trend:
                score -= 10
            elif '强势下跌' in trend:
                score -= 20
            
            # 均线加分
            ma_pos = ind.get('ma_position', '')
            if ma_pos == '多头':
                score += 15
            elif ma_pos == '空头':
                score -= 15
            
            # 限制在0-100分
            score = max(0, min(100, score))
            
            # 生成理由
            reasons = []
            if change > 0:
                reasons.append(f"涨{change:.1f}%")
            if vol_ratio > 1.5:
                reasons.append("放量")
            if '上涨' in trend:
                reasons.append(trend)
            if ma_pos == '多头':
                reasons.append("多头排列")
            
            reason = "，".join(reasons) if reasons else "规则筛选"
            
            scored.append({
                "code": code,
                "name": data.get('name', ''),
                "score": int(score),
                "reason": reason
            })
        
        # 排序并返回前N个
        scored.sort(key=lambda x: x['score'], reverse=True)
        
        return {
            "success": True,
            "selected_stocks": scored[:max_results],
            "fallback": True,
            "message": "使用规则引擎（AI不可用）"
        }


# 创建全局实例
stock_filter_mcp_server = StockFilterMCPServer()

