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
            cache_key = self._get_cache_key(stock_code)
            cached_data = await self.redis_client.get(cache_key)
            
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
            cache_key = self._get_cache_key(stock_code)
            
            # 计算到当天结束的秒数
            now = datetime.now()
            end_of_day = datetime(now.year, now.month, now.day, 23, 59, 59)
            seconds_until_end_of_day = int((end_of_day - now).total_seconds())
            
            # 设置缓存，当天结束时自动过期
            if seconds_until_end_of_day > 0:
                await self.redis_client.setex(cache_key, seconds_until_end_of_day, analysis)
                logger.debug(f"已保存{stock_code}的分析报告到缓存（{seconds_until_end_of_day}秒后过期）")
            else:
                # 如果已经是当天最后时刻，设置短期缓存
                await self.redis_client.setex(cache_key, 3600, analysis)  # 1小时
                logger.debug(f"已保存{stock_code}的分析报告到缓存（1小时后过期）")
        except Exception as e:
            logger.error(f"保存缓存失败: {e}")
    
    async def clear_stock_cache(self, stock_code: str):
        """清除特定股票的缓存"""
        try:
            cache_key = self._get_cache_key(stock_code)
            await self.redis_client.delete(cache_key)
            logger.debug(f"已清除{stock_code}的缓存")
        except Exception as e:
            logger.error(f"清除缓存失败: {e}")
    
    async def clear_all_cache(self):
        """清除所有AI分析缓存"""
        try:
            pattern = f"{self.cache_prefix}*"
            keys = []
            async for key in self.redis_client.scan_iter(match=pattern):
                keys.append(key)
            
            if keys:
                await self.redis_client.delete(*keys)
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
        force_refresh: bool = False
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
            analysis_text = await self._generate_ai_analysis_report(
                stock_code, stock_data,
                ai_endpoint, ai_api_key, ai_model_name
            )
            
            # 检查AI分析是否成功
            if not analysis_text:
                yield {
                    'status': 'error',
                    'message': 'AI分析服务暂时不可用，请检查AI配置或稍后重试',
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
        elif stock_code.startswith(('43', '83', '87', '88')):
            # 北交所：43、83、87、88开头
            return f"{stock_code}.BJ"
        else:
            # 默认深圳市场
            return f"{stock_code}.SZ"

    async def _fetch_stock_history_data(self, stock_code: str) -> Dict[str, any]:
        """获取股票历史数据"""
        try:
            # 首先尝试从股票基础信息中查找正确的ts_code（与图表API保持一致）
            logger.info(f"查找股票代码: {stock_code}")
            stocks_key = "stocks:codes:all"
            stocks_data = await self.redis_client.get(stocks_key)
            
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
            
            logger.info(f"找到股票信息: ts_code={ts_code}, name={stock_info.get('name')}")
            
            # 从Redis获取股票走势数据
            trend_key = f"stock_trend:{ts_code}"
            trend_data = await self.redis_client.get(trend_key)
            
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
                    keys = await self.redis_client.keys("stock_trend:*")
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
        ai_model: str
    ) -> str:
        """使用AI生成股票分析报告"""
        try:
            logger.debug(f"开始通过AI分析股票: {stock_code}")
            
            # 构建含有历史数据的提示词
            prompt = self._build_analysis_prompt_with_data(stock_code, stock_data)
            
            # 调用AI服务
            response = await self._call_ai_service(prompt, ai_endpoint, ai_api_key, ai_model)
            
            if response:
                logger.debug(f"AI分析完成，生成报告长度: {len(response)}")
                return response
            else:
                logger.warning("AI服务返回空结果")
                return ""
                
        except Exception as e:
            logger.error(f"AI分析生成失败: {e}")
            return ""
    
    async def _call_ai_service(
        self,
        prompt: str,
        ai_endpoint: str,
        ai_api_key: str,
        ai_model: str
    ) -> str:
        """直接调用AI服务"""
        try:
            logger.debug(f"调用AI服务: {ai_endpoint}")
            
            request_body = {
                'model': ai_model,
                'messages': [
                    {
                        'role': 'user',
                        'content': prompt,
                    }
                ],
                'stream': False,
                'max_tokens': 2048,
                'temperature': 0.7,
            }
            
            headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {ai_api_key}',
            }
            
            timeout = aiohttp.ClientTimeout(total=60)  # 60秒超时
            
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(
                    ai_endpoint,
                    headers=headers,
                    json=request_body
                ) as response:
                    
                    if response.status == 200:
                        json_response = await response.json()
                        content = json_response.get('choices', [{}])[0].get('message', {}).get('content', '')
                        logger.debug(f"成功获取AI响应，内容长度: {len(content)}")
                        return content
                    else:
                        error_text = await response.text()
                        logger.error(f"AI API调用失败: {response.status}")
                        logger.error(f"错误响应: {error_text}")
                        raise Exception(f'AI API调用失败: HTTP {response.status}')
                        
        except Exception as e:
            logger.error(f"调用AI服务出错: {e}")
            raise e
    
    def _build_analysis_prompt_with_data(
        self,
        stock_code: str,
        stock_data: Dict[str, any]
    ) -> str:
        """构建专业的A股日线技术分析提示词"""
        
        prompt_parts = []
        
        prompt_parts.append(f"""
你是一位资深的A股技术分析师，请对股票 {stock_code} 进行专业的日线技术分析。

""")
        
        # 添加历史数据概要（如果有）
        if stock_data.get('data') and isinstance(stock_data['data'], list) and len(stock_data['data']) > 0:
            prompt_parts.append('## 日线数据\n\n')
            
            history = stock_data['data']
            data_points = len(history)
            
            # 添加日线K线数据
            prompt_parts.append(f'### 近期日K线数据（最近{min(data_points, 20)}个交易日）：\n\n')
            prompt_parts.append('日期 | 开盘 | 收盘 | 最高 | 最低 | 成交量(万手) | 成交额(万元)\n')
            prompt_parts.append('---- | ---- | ---- | ---- | ---- | --------- | ----------\n')
            
            # 选取最近的20个交易日数据
            recent_data = history[:20]  # 取前20条
            for item in recent_data:
                date = item.get('trade_date') or item.get('date', '')
                volume = (item.get('volume', 0) or item.get('vol', 0)) / 10000  # 转换为万手
                amount = (item.get('amount', 0)) / 10000 if item.get('amount') else 0  # 转换为万元
                
                prompt_parts.append(
                    f"{date} | {item.get('open', 0)} | {item.get('close', 0)} | "
                    f"{item.get('high', 0)} | {item.get('low', 0)} | "
                    f"{volume:.2f} | {amount:.0f}\n"
                )
            
            # 计算技术指标基础数据
            if data_points >= 5:
                prices = [float(item.get('close', 0)) for item in history[:5]]
                volumes = [float(item.get('volume', 0) or item.get('vol', 0)) for item in history[:5]]
                
                if prices[0] > 0 and prices[1] > 0:
                    latest_price = prices[0]
                    price_change = latest_price - prices[1]
                    price_change_percent = (price_change / prices[1] * 100)
                    avg_volume = sum(volumes) / len(volumes) / 10000
                    
                    prompt_parts.append('\n### 基础数据：\n')
                    prompt_parts.append(f'- 最新收盘价：{latest_price}元\n')
                    prompt_parts.append(f'- 日涨跌幅：{price_change_percent:.2f}%\n')
                    prompt_parts.append(f'- 近5日平均成交量：{avg_volume:.0f}万手\n\n')
        
        prompt_parts.append("""
## 请进行以下专业技术分析：

### 1. 价格走势分析
- **趋势判断**：分析日线级别的主要趋势（上升/下降/横盘整理）
- **波浪结构**：识别当前所处的波浪位置和形态特征
- **价格形态**：识别重要的K线组合形态（如头肩顶底、双顶双底、三角形等）
- **缺口分析**：是否存在跳空缺口，缺口性质和回补概率

### 2. 支撑阻力分析
- **关键支撑位**：计算并标注重要的支撑价位（至少3个层级）
- **关键阻力位**：计算并标注重要的阻力价位（至少3个层级）
- **心理价位**：分析整数关口等心理价位的技术意义
- **前期高低点**：标注历史重要高低点位的支撑阻力作用

### 3. 均线系统分析
- **短期均线**：MA5、MA10的走势和交叉情况
- **中期均线**：MA20、MA30的支撑阻力作用
- **长期均线**：MA60、MA120的趋势指导意义
- **均线排列**：多头/空头排列状态和变化趋势

### 4. 技术指标分析
- **MACD指标**：DIF、DEA数值，柱状线变化，金叉死叉信号
- **RSI指标**：当前数值，超买超卖判断，背离情况
- **KDJ指标**：K、D、J三线数值和交叉状态
- **BOLL指标**：布林带开口状态，价格位置，压力支撑

### 5. 成交量分析
- **量价关系**：分析价涨量增、价跌量缩等经典量价配合
- **成交量形态**：识别放量突破、缩量整理等形态
- **换手率分析**：评估市场活跃度和资金参与程度
- **量能背离**：价格与成交量的背离信号

### 6. 市场结构分析
- **级别划分**：日线级别的买卖点识别
- **结构破坏**：重要结构位的突破确认
- **回调预期**：正常回调的空间和时间预期
- **风险控制点**：关键的止损位设定建议

### 7. 操作策略建议
- **短线策略**：1-3日的交易机会和风险点
- **中线策略**：1-4周的持仓建议和目标位
- **仓位管理**：建议的仓位配置和加减仓时机
- **风险提示**：主要技术风险点和应对策略

## 输出要求：
1. 使用专业的技术分析术语，体现分析师水准
2. 提供具体的价位数据，不要模糊表述
3. 给出明确的操作建议和风险控制措施
4. 分析要客观中性，避免过度主观判断
5. 使用Markdown格式，结构清晰，重点突出
6. 每个技术指标都要给出具体数值和信号判断

请基于提供的日线数据进行深度技术分析，给出专业、实用的分析报告。
""")
        
        return ''.join(prompt_parts)


# 创建全局实例
stock_ai_analysis_service = StockAIAnalysisService() 