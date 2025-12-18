# -*- coding: utf-8 -*-
"""
股票AI分析服务
基于前端Flutter代码实现的后端版本，提供股票技术分析功能
"""
import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, AsyncGenerator
import aiohttp
import redis.asyncio as redis
from app.core.config import settings
from app.core.redis_client import get_redis_client

logger = logging.getLogger(__name__)

class StockAIAnalysisService:
    """股票AI分析服务"""
    
    def __init__(self):
        self.redis_client = None
        self.cache_prefix = "ai_analysis_cache_"
        self.cache_expire_hours = 24  # 缓存24小时
        
    async def initialize(self):
        """初始化服务"""
        try:
            self.redis_client = await get_redis_client()
            logger.info("股票AI分析服务初始化成功")
            return True
        except Exception as e:
            logger.error(f"股票AI分析服务初始化失败: {e}")
            return False
    
    async def close(self):
        """关闭服务"""
        if self.redis_client:
            try:
                await self.redis_client.close()
            except Exception:
                pass
            finally:
                self.redis_client = None
    
    def _get_cache_key(self, stock_code: str) -> str:
        """获取缓存键（当天有效）"""
        today = datetime.now().strftime('%Y-%m-%d')
        return f"{self.cache_prefix}{stock_code}_{today}"
    
    async def _get_cached_analysis(self, stock_code: str) -> Optional[str]:
        """检查缓存是否存在且有效（当天有效）"""
        try:
            # 每次都重新获取Redis客户端，确保在正确的事件循环中
            redis_client = await get_redis_client()
            cache_key = self._get_cache_key(stock_code)
            cached_data = await redis_client.get(cache_key)
            
            if cached_data:
                logger.debug(f"找到{stock_code}的缓存分析报告（当天有效）")
                return cached_data.decode('utf-8') if isinstance(cached_data, bytes) else cached_data
            
            logger.debug(f"{stock_code}没有当天的缓存分析报告")
            return None
        except Exception as e:
            logger.error(f"读取缓存失败: {e}")
            return None
    
    async def _save_analysis_to_cache(self, stock_code: str, analysis: str):
        """保存分析结果到缓存（当天结束时自动失效）"""
        try:
            # 每次都重新获取Redis客户端，确保在正确的事件循环中
            redis_client = await get_redis_client()
            cache_key = self._get_cache_key(stock_code)
            
            # 计算到当天结束的秒数
            now = datetime.now()
            end_of_day = datetime(now.year, now.month, now.day, 23, 59, 59)
            seconds_until_end_of_day = int((end_of_day - now).total_seconds())
            
            # 设置缓存，当天结束时自动过期
            if seconds_until_end_of_day > 0:
                await redis_client.setex(cache_key, seconds_until_end_of_day, analysis)
                logger.debug(f"已保存{stock_code}的分析报告到缓存（{seconds_until_end_of_day}秒后过期）")
            else:
                # 如果已经是当天最后时刻，设置短期缓存
                await redis_client.setex(cache_key, 3600, analysis)  # 1小时
                logger.debug(f"已保存{stock_code}的分析报告到缓存（1小时后过期）")
        except Exception as e:
            logger.error(f"保存缓存失败: {e}")
    
    async def clear_stock_cache(self, stock_code: str):
        """清除特定股票的缓存"""
        try:
            # 每次都重新获取Redis客户端，确保在正确的事件循环中
            redis_client = await get_redis_client()
            cache_key = self._get_cache_key(stock_code)
            await redis_client.delete(cache_key)
            logger.debug(f"已清除{stock_code}的缓存")
        except Exception as e:
            logger.error(f"清除缓存失败: {e}")
    
    async def clear_all_cache(self):
        """清除所有AI分析缓存"""
        try:
            # 每次都重新获取Redis客户端，确保在正确的事件循环中
            redis_client = await get_redis_client()
            pattern = f"{self.cache_prefix}*"
            keys = []
            async for key in redis_client.scan_iter(match=pattern):
                keys.append(key)
            
            if keys:
                await redis_client.delete(*keys)
                logger.info(f"已清除所有AI分析缓存，共{len(keys)}条")
            else:
                logger.info("没有找到需要清除的缓存")
        except Exception as e:
            logger.error(f"清除所有缓存失败: {e}")
    
    async def get_stock_analysis_stream(
        self,
        stock_code: str,
        ai_model_name: str,
        ai_endpoint: str,
        ai_api_key: str,
        force_refresh: bool = False,
        indicators: Optional[Dict[str, any]] = None
    ) -> AsyncGenerator[Dict[str, any], None]:
        """获取股票AI分析（流式响应，支持当天缓存）"""
        
        # 返回状态更新
        yield {
            'status': 'start',
            'message': f'开始分析 {stock_code}',
        }
        
        try:
            # 如果不是强制刷新，先检查缓存
            if not force_refresh:
                yield {
                    'status': 'checking_cache',
                    'message': '检查本地缓存...',
                }
                
                cached_analysis = await self._get_cached_analysis(stock_code)
                if cached_analysis:
                    yield {
                        'status': 'completed',
                        'message': '从缓存加载分析报告',
                        'analysis': cached_analysis,
                        'from_cache': True,
                    }
                    return
            else:
                # 强制刷新时清除缓存
                await self.clear_stock_cache(stock_code)
            
            # 请求股票历史数据
            yield {
                'status': 'fetching_data',
                'message': '正在获取历史数据...',
            }
            
            logger.debug(f"开始获取股票历史数据: {stock_code}")
            stock_data = await self._fetch_stock_history_data(stock_code)
            logger.debug(f"股票历史数据获取完成: {stock_code}")
            
            # 检查是否成功获取历史数据
            if not stock_data.get('data') or not isinstance(stock_data['data'], list) or len(stock_data['data']) == 0:
                logger.warning(f"历史数据验证失败: {stock_data.keys()}")
                yield {
                    'status': 'error',
                    'message': '无法获取足够的历史数据进行分析',
                }
                return
            
            logger.debug(f"历史数据验证成功，数据条数: {len(stock_data['data'])}")
            
            # 检查AI配置
            yield {
                'status': 'checking_ai_config',
                'message': '检查AI配置...',
            }
            
            # 直接使用传入的AI配置（必填参数）
            logger.debug(f"AI配置检查结果 - 端点: {ai_endpoint}, 模型: {ai_model_name}")
            
            if not ai_endpoint or not ai_api_key:
                yield {
                    'status': 'config_required',
                    'message': '需要提供有效的AI服务配置',
                    'is_admin': True,
                }
                return
            
            # 开始AI分析
            yield {
                'status': 'analyzing',
                'message': '正在进行AI分析...',
            }
            
            # 调用AI分析
            try:
                analysis_text = await self._generate_ai_analysis_report(
                    stock_code, stock_data,
                    ai_endpoint, ai_api_key, ai_model_name
                )
            except Exception as ai_error:
                logger.error(f"AI分析调用失败: {ai_error}")
                yield {
                    'status': 'error',
                    'message': f'AI分析服务调用失败: {str(ai_error)}',
                }
                return
            
            # 检查AI分析是否成功
            if not analysis_text:
                yield {
                    'status': 'error',
                    'message': 'AI分析服务返回空结果，请检查AI配置',
                }
                return
            
            # 保存到缓存
            await self._save_analysis_to_cache(stock_code, analysis_text)
            
            # 分析完成
            yield {
                'status': 'completed',
                'message': '分析完成',
                'analysis': analysis_text,
                'from_cache': False,
            }
            
        except Exception as e:
            logger.error(f"AI分析出错: {e}")
            yield {
                'status': 'error',
                'message': f'生成分析报告失败: {str(e)}',
            }
    
    def _convert_to_ts_code(self, stock_code: str) -> str:
        """将股票代码转换为ts_code格式"""
        # 如果已经是ts_code格式，直接返回
        if '.' in stock_code:
            return stock_code
        
        # 根据股票代码判断市场
        if stock_code.startswith(('60', '68', '90')):
            # 上海市场：60开头的主板，68开头的科创板，90开头的B股
            return f"{stock_code}.SH"
        elif stock_code.startswith(('00', '30', '20')):
            # 深圳市场：00开头的主板，30开头的创业板，20开头的B股
            return f"{stock_code}.SZ"
        elif stock_code.startswith(('43', '83', '87', '88', '92')):
            # 北交所：43、83、87、88开头是股票，92开头是指数
            return f"{stock_code}.BJ"
        else:
            # 默认深圳市场
            return f"{stock_code}.SZ"

    async def _fetch_stock_history_data(self, stock_code: str) -> Dict[str, any]:
        """获取股票历史数据"""
        try:
            # 每次都重新获取Redis客户端，确保在正确的事件循环中
            redis_client = await get_redis_client()
            
            # 首先尝试从股票基础信息中查找正确的ts_code（与图表API保持一致）
            logger.info(f"查找股票代码: {stock_code}")
            stocks_key = "stocks:codes:all"
            stocks_data = await redis_client.get(stocks_key)
            
            if not stocks_data:
                logger.error("Redis中没有stocks:codes:all数据")
                return {'data': []}
            
            stocks_list = json.loads(stocks_data)
            logger.info(f"stocks:codes:all中有{len(stocks_list)}只股票")
            
            # 查找匹配的股票（支持多种格式，与图表API保持一致）
            stock_info = None
            ts_code = None
            
            for stock in stocks_list:
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
                logger.error(f"在stocks:codes:all中未找到股票代码: {stock_code}")
                
                # 尝试查找相似的股票
                similar_stocks = []
                for stock in stocks_list[:20]:  # 检查前20个
                    ts_code_part = stock.get('ts_code', '').split('.')[0] if stock.get('ts_code') else ''
                    name = stock.get('name', '')
                    symbol = stock.get('symbol', '')
                    if (stock_code in ts_code_part or stock_code in name or stock_code in symbol or 
                        '康普顿' in name):
                        similar_stocks.append(f"{stock.get('ts_code')}-{name}")
                
                if similar_stocks:
                    logger.info(f"找到相似股票: {similar_stocks}")
                else:
                    logger.warning("没有找到相似的股票")
                
                return {'data': []}
            
            logger.info(f"找到股票信息: ts_code={ts_code}, name={stock_info.get('name')}, market={stock_info.get('market')}")
            
            # 从Redis获取股票走势数据（ETF也是一种特殊的股票，统一使用stock_trend）
            trend_key = f"stock_trend:{ts_code}"
            
            trend_data = await redis_client.get(trend_key)
            
            if trend_data:
                try:
                    data = json.loads(trend_data)
                    if isinstance(data, dict) and 'data' in data:
                        logger.info(f"从Redis获取到股票历史数据，含{len(data['data'])}条记录")
                        return data
                    elif isinstance(data, list):
                        # 旧格式：直接是K线数据列表
                        logger.info(f"从Redis获取到股票历史数据（旧格式），含{len(data)}条记录")
                        return {'data': data}
                    else:
                        logger.warning(f"Redis中的股票数据格式不正确: {ts_code}")
                except json.JSONDecodeError:
                    logger.warning(f"Redis中的股票数据JSON解析失败: {ts_code}")
            else:
                logger.error(f"Redis中未找到键: {trend_key}")
                
                # 列出一些现有的stock_trend键用于调试
                try:
                    keys = await redis_client.keys("stock_trend:*")
                    if keys:
                        sample_keys = keys[:10]  # 只显示前10个
                        logger.info(f"现有stock_trend键示例: {[key.decode() if isinstance(key, bytes) else key for key in sample_keys]}")
                    else:
                        logger.warning("Redis中没有任何stock_trend键")
                except Exception as e:
                    logger.warning(f"无法列出stock_trend键: {e}")
            
            # 如果仍然没有数据，返回空数据
            logger.error(f"未找到股票历史数据: {stock_code} (ts_code: {ts_code})")
            return {'data': []}
            
        except Exception as e:
            logger.error(f"获取股票历史数据出错: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {'data': []}
    
    async def _generate_ai_analysis_report(
        self,
        stock_code: str,
        stock_data: Dict[str, any],
        ai_endpoint: str,
        ai_api_key: str,
        ai_model: str,
        indicators: Optional[Dict[str, any]] = None
    ) -> str:
        """使用AI生成股票分析报告 - 支持多空辩论模式"""
        try:
            logger.info(f"开始通过AI分析股票: {stock_code}")
            logger.info(f"AI配置 - 端点: {ai_endpoint}, 模型: {ai_model}")
            
            # 构建含有历史数据和技术指标的提示词
            prompt = self._build_analysis_prompt_with_data(stock_code, stock_data, indicators)
            logger.info(f"构建的提示词长度: {len(prompt)}")
            
            # 调用AI服务
            response = await self._call_ai_service(prompt, ai_endpoint, ai_api_key, ai_model)
            
            if response:
                logger.info(f"AI分析完成，生成报告长度: {len(response)}")
                return response
            else:
                logger.warning("AI服务返回空结果")
                return ""
                
        except Exception as e:
            logger.error(f"AI分析生成失败: {e}")
            import traceback
            logger.error(f"详细错误信息: {traceback.format_exc()}")
            raise  # 重新抛出异常，而不是返回空字符串
    
    async def _call_ai_service(
        self,
        prompt: str,
        ai_endpoint: str,
        ai_api_key: str,
        ai_model: str
    ) -> str:
        """直接调用AI服务"""
        try:
            logger.info(f"调用AI服务: {ai_endpoint}")
            logger.info(f"使用模型: {ai_model}")
            
            # 从配置读取max_tokens，避免硬编码
            from app.core.config import AI_STOCK_ANALYSIS_MAX_TOKENS, AI_TEMPERATURE
            
            request_body = {
                'model': ai_model,
                'messages': [
                    {
                        'role': 'user',
                        'content': prompt,
                    }
                ],
                'stream': False,
                'max_tokens': AI_STOCK_ANALYSIS_MAX_TOKENS,  # 从环境变量读取
                'temperature': AI_TEMPERATURE,
            }
            
            headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {ai_api_key[:10]}...{ai_api_key[-4:]}',  # 日志中隐藏API密钥
            }
            
            logger.info(f"请求头: {headers}")
            logger.info(f"请求体: model={ai_model}, messages长度={len(request_body['messages'])}, prompt长度={len(prompt)}")
            
            # 打印完整的请求URL用于调试
            logger.info(f"=" * 80)
            logger.info(f"完整的API端点URL: {ai_endpoint}")
            logger.info(f"模型名称: {ai_model}")
            logger.info(f"API密钥前缀: {ai_api_key[:20]}...")
            logger.info(f"=" * 80)
            
            timeout = aiohttp.ClientTimeout(total=60)  # 60秒超时
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                # 实际请求时使用完整的API密钥
                actual_headers = {
                    'Content-Type': 'application/json',
                    'Authorization': f'Bearer {ai_api_key}',
                }
                
                logger.info(f"发送POST请求到: {ai_endpoint}")
                async with session.post(
                    ai_endpoint,
                    headers=actual_headers,
                    json=request_body
                ) as response:
                    
                    logger.info(f"收到响应，状态码: {response.status}")
                    
                    if response.status == 200:
                        json_response = await response.json()
                        logger.info(f"响应JSON结构: {json_response.keys() if isinstance(json_response, dict) else type(json_response)}")
                        
                        # 尝试从不同的响应结构中提取内容
                        content = None
                        if isinstance(json_response, dict):
                            # OpenAI标准格式
                            if 'choices' in json_response:
                                content = json_response.get('choices', [{}])[0].get('message', {}).get('content', '')
                            # 阿里百炼可能的格式
                            elif 'output' in json_response:
                                output = json_response.get('output', {})
                                if isinstance(output, dict):
                                    content = output.get('text', '') or output.get('content', '')
                                else:
                                    content = str(output)
                            # 直接包含text字段
                            elif 'text' in json_response:
                                content = json_response.get('text', '')
                            # 其他可能的格式
                            elif 'result' in json_response:
                                content = json_response.get('result', '')
                        
                        if content:
                            logger.info(f"成功获取AI响应，内容长度: {len(content)}")
                            return content
                        else:
                            logger.error(f"无法从响应中提取内容，响应结构: {json_response}")
                            raise Exception(f'AI响应格式不正确，无法提取内容')
                    else:
                        error_text = await response.text()
                        logger.error(f"=" * 80)
                        logger.error(f"AI API调用失败!")
                        logger.error(f"请求URL: {ai_endpoint}")
                        logger.error(f"模型: {ai_model}")
                        logger.error(f"响应状态码: HTTP {response.status}")
                        logger.error(f"错误响应: {error_text}")
                        logger.error(f"=" * 80)
                        
                        # 针对404错误给出特别提示
                        if response.status == 404:
                            logger.error(f"提示: HTTP 404表示API端点URL不存在，请检查配置的URL是否正确")
                            logger.error(f"阿里百炼正确的端点格式应该是: https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")
                        
                        raise Exception(f'AI API调用失败: HTTP {response.status} - {error_text[:200]}')
                        
        except aiohttp.ClientError as e:
            logger.error(f"调用AI服务网络错误: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            raise Exception(f'AI服务网络错误: {str(e)}')
        except Exception as e:
            logger.error(f"调用AI服务出错: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            raise e
    
    def _build_analysis_prompt_with_data(
        self,
        stock_code: str,
        stock_data: Dict[str, any],
        indicators: Optional[Dict[str, any]] = None
    ) -> str:
        """构建专业的A股日线技术分析提示词 - 多空辩论模式"""
        
        prompt_parts = []
        
        # 获取当前日期
        from datetime import datetime
        current_date = datetime.now().strftime('%Y年%m月%d日')
        
        prompt_parts.append(f"""
你是一位资深的A股技术分析专家团队，现在是{current_date}。请对股票 {stock_code} 进行专业的技术分析。

**🚨 极其重要的时间说明**：
1. **当前日期是 {current_date}（今天）**
2. **下面的K线数据表格是按时间倒序排列的：**
   - **第一行（标记★最新）= 最近的交易日（{current_date}或之前最近一个交易日）**
   - **最后一行（标记"最早"）= 20个交易日之前的数据**
   - **请务必分析第一行和前几行的数据，而不是最后几行！**
3. **短线分析重点**：
   - 散户最关心1-3天的短线机会
   - **请重点分析表格前3-5行（最近3-5个交易日）的价格和成交量**
   - **不要去分析20天前的旧数据！**
4. 请以多空双方辩论的形式展开分析

""")
        
        # 添加历史数据概要（如果有）
        if stock_data.get('data') and isinstance(stock_data['data'], list) and len(stock_data['data']) > 0:
            prompt_parts.append('## 日线数据\n\n')
            
            history = stock_data['data']
            data_points = len(history)
            
            # 添加日线K线数据
            prompt_parts.append(f'### 近期日K线数据（最近{min(data_points, 20)}个交易日）：\n\n')
            prompt_parts.append('⚠️ **重要**: 下表按时间倒序排列，**第一行是今天或最近交易日**，越往下越早！\n\n')
            prompt_parts.append('日期 | 开盘 | 收盘 | 最高 | 最低 | 成交量(万手) | 成交额(万元)\n')
            prompt_parts.append('---- | ---- | ---- | ---- | ---- | --------- | ----------\n')
            
            # 重要：确保数据从旧到新排序，然后取最近20条
            # 先排序确保时间顺序正确
            sorted_history = sorted(history, key=lambda x: x.get('trade_date') or x.get('date', ''))
            
            # 取最近的20个交易日数据（最新的20条）
            recent_data = sorted_history[-20:] if len(sorted_history) >= 20 else sorted_history
            
            # 反转顺序，让最新的日期在前面显示
            recent_data_reversed = list(reversed(recent_data))
            
            # 添加第一行数据时特别标注
            for idx, item in enumerate(recent_data_reversed):
                date = item.get('trade_date') or item.get('date', '')
                volume = (item.get('volume', 0) or item.get('vol', 0)) / 10000  # 转换为万手
                amount = (item.get('amount', 0)) / 10000 if item.get('amount') else 0  # 转换为万元
                
                # 第一行标注"最新"，最后一行标注"最早"
                date_label = date
                if idx == 0:
                    date_label = f"{date}★最新"
                elif idx == len(recent_data_reversed) - 1:
                    date_label = f"{date}(最早)"
                
                prompt_parts.append(
                    f"{date_label} | {item.get('open', 0)} | {item.get('close', 0)} | "
                    f"{item.get('high', 0)} | {item.get('low', 0)} | "
                    f"{volume:.2f} | {amount:.0f}\n"
                )
            
            # 计算技术指标基础数据 - 使用最新的5条数据
            if len(sorted_history) >= 5:
                latest_5 = sorted_history[-5:]  # 最新的5条
                prices = [float(item.get('close', 0)) for item in reversed(latest_5)]  # 反转让最新的在前
                volumes = [float(item.get('volume', 0) or item.get('vol', 0)) for item in reversed(latest_5)]
                
                if prices[0] > 0 and prices[1] > 0:
                    latest_price = prices[0]
                    price_change = latest_price - prices[1]
                    price_change_percent = (price_change / prices[1] * 100)
                    avg_volume = sum(volumes) / len(volumes) / 10000
                    
                    prompt_parts.append('\n### 基础数据：\n')
                    prompt_parts.append(f'- 最新收盘价：{latest_price}元\n')
                    prompt_parts.append(f'- 日涨跌幅：{price_change_percent:.2f}%\n')
                    prompt_parts.append(f'- 近5日平均成交量：{avg_volume:.0f}万手\n\n')
        
        # 添加客户端计算的技术指标
        if indicators:
            prompt_parts.append('## 技术指标数据（已计算）\n\n')
            
            # EMA均线
            if 'ema' in indicators:
                ema_data = indicators['ema']
                prompt_parts.append('### 均线系统：\n')
                prompt_parts.append(f"- EMA5: {ema_data.get('ema5')}\n")
                prompt_parts.append(f"- EMA10: {ema_data.get('ema10')}\n")
                prompt_parts.append(f"- EMA20: {ema_data.get('ema20')}\n")
                prompt_parts.append(f"- EMA60: {ema_data.get('ema60')}\n")
            
            # 趋势判断
            if 'trend' in indicators:
                prompt_parts.append(f"- 趋势状态: {indicators['trend']}\n\n")
            
            # RSI指标
            if 'rsi' in indicators:
                rsi_data = indicators['rsi']
                prompt_parts.append('### RSI指标：\n')
                prompt_parts.append(f"- RSI值: {rsi_data.get('value')}\n")
                prompt_parts.append(f"- RSI状态: {rsi_data.get('status')}\n\n")
            
            # MACD指标
            if 'macd' in indicators:
                macd_data = indicators['macd']
                prompt_parts.append('### MACD指标：\n')
                prompt_parts.append(f"- MACD: {macd_data.get('macd')}\n")
                prompt_parts.append(f"- Signal: {macd_data.get('signal')}\n")
                prompt_parts.append(f"- Histogram: {macd_data.get('histogram')}\n")
                prompt_parts.append(f"- MACD信号: {macd_data.get('status')}\n\n")
            
            # 布林带
            if 'boll' in indicators:
                boll_data = indicators['boll']
                prompt_parts.append('### 布林带：\n')
                prompt_parts.append(f"- 上轨: {boll_data.get('upper')}\n")
                prompt_parts.append(f"- 中轨: {boll_data.get('middle')}\n")
                prompt_parts.append(f"- 下轨: {boll_data.get('lower')}\n\n")
            
            # 支撑阻力
            if 'support_resistance' in indicators:
                sr = indicators['support_resistance']
                prompt_parts.append('### 支撑阻力位：\n')
                prompt_parts.append(f"- 支撑位: {sr.get('support')}\n")
                prompt_parts.append(f"- 阻力位: {sr.get('resistance')}\n\n")
        
        prompt_parts.append(f"""
## 分析要求 - 多空辩论模式

**🚨 再次强调时间重点**：
- 今天是 {current_date}
- 请分析**表格第一行（标记★最新）及前几行**的数据
- **这些是最近几天的数据，是短线分析的关键！**
- **不要分析表格底部（最早）的20天前旧数据！**

请以**多空双方辩论**的形式进行分析，这样更符合人性化思考过程。具体格式如下：

### 🐂 多方观点（看涨理由）

**技术面支持（基于最近几天数据）：**
1. 从均线系统看，[具体分析多头排列或金叉信号]
2. 从MACD指标看，[分析看涨信号]
3. 从RSI指标看，[分析超卖或上涨潜力]
4. 从成交量看，[分析**最近几天**的放量上涨信号]
5. 从布林带看，[分析突破上轨或支撑]

**价格形态支持（最近3-5天）：**
- [分析**最近交易日**支持上涨的K线形态]
- [分析突破阻力位的可能性]

**短线机会（未来1-3天）：**
- 建议入场点：[具体价位]
- 目标价位：[具体价位]（盈利空间：X%）
- 止损价位：[具体价位]（风险空间：Y%）
- **盈亏比：X:Y（必须≥2:1，否则不建议入场）**
- 预期涨幅：[百分比]

**🚨 盈亏比计算要求：**
- 盈利空间 = (目标价 - 入场价) / 入场价 × 100%
- 风险空间 = (入场价 - 止损价) / 入场价 × 100%
- 盈亏比 = 盈利空间 / 风险空间
- **必须确保盈亏比 ≥ 2:1，否则不值得冒险！**

---

### 🐻 空方观点（看跌理由）

**技术面压制（基于最近几天数据）：**
1. 从均线系统看，[具体分析空头排列或死叉信号]
2. 从MACD指标看，[分析看跌信号]
3. 从RSI指标看，[分析超买或回调压力]
4. 从成交量看，[分析**最近几天**的缩量下跌或背离]
5. 从布林带看，[分析跌破下轨或压力]

**价格形态压制（最近3-5天）：**
- [分析**最近交易日**支持下跌的K线形态]
- [分析跌破支撑位的风险]

**短线风险（未来1-3天）：**
- 关键支撑位：[具体价位]
- 建议止损点：[具体价位]（跌破支撑X%）
- 预期回调幅度：[百分比]

---

### ⚖️ 综合研判

**力量对比：**
- 多空力量对比：[X%看涨 vs Y%看跌]
- 主导力量：[多方/空方/均衡]

**短线操作建议（未来1-3天内）：**
1. **激进策略**：[具体操作建议]
2. **稳健策略**：[具体操作建议]
3. **观望策略**：[等待信号]

**关键价位（基于技术分析）：**
- 强支撑位：[价位1] → [价位2] → [价位3]
- 强阻力位：[价位1] → [价位2] → [价位3]

**推荐交易计划（必须满足盈亏比≥2:1）：**
- 建议入场价：[具体价位]
- 止损价：[具体价位]（风险：X%，通常3-8%）
- 目标价：[具体价位]（盈利：Y%，必须≥2X）
- **盈亏比：Y:X（必须≥2:1）**
- 仓位建议：[轻仓/半仓/重仓]

**风险提示：**
- [列出主要技术风险]
- [建议仓位控制]
- **如果盈亏比<2:1，建议观望等待更好机会**

---

## 输出要求：
1. **必须严格按照上述多空辩论格式输出**
2. **重点关注最近3-5天的走势和未来1-3天的机会**
3. **所有分析必须基于表格第一行及前几行（最新数据）**
4. 所有价位必须具体，不要模糊表述
5. 给出明确的多空力量对比百分比
6. 使用Markdown格式，使用表情符号🐂🐻⚖️增强可读性
7. 分析要客观，既要看到机会也要看到风险
8. **禁止分析20天前的旧数据，那些对短线交易没有意义！**
9. **🚨 最重要：止损价和目标价必须确保盈亏比≥2:1，否则不建议入场！**
10. **止损幅度通常控制在3-8%，目标盈利至少是止损的2倍**

请基于提供的**最新数据**和技术指标，以多空辩论的方式进行深度分析！
""")
        
        return ''.join(prompt_parts)


# 创建全局实例
stock_ai_analysis_service = StockAIAnalysisService() 