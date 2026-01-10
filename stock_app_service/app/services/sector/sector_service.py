# -*- coding: utf-8 -*-
"""
板块分析服务 - 提供行业板块数据分析功能

主要功能：
1. 板块列表获取 - 同花顺行业分类
2. 板块成分股管理
3. 板块强度计算 - 基于成分股涨跌幅
4. 概念热度排名
5. 板块资金流向分析
"""

import tushare as ts
import pandas as pd
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from app.core.logging import logger
from app.core.config import settings
from app.db.session import RedisCache
import json


class SectorService:
    """板块分析服务类"""
    
    def __init__(self):
        """初始化板块服务"""
        try:
            self.pro = ts.pro_api(settings.TUSHARE_TOKEN)
            self.redis_cache = RedisCache()
            logger.info("板块分析服务初始化成功")
        except Exception as e:
            logger.error(f"板块分析服务初始化失败: {e}")
            raise
    
    async def get_sector_list(self, exchange: str = 'A') -> Dict[str, Any]:
        """
        获取板块列表（使用stock_basic接口按行业分类）
        
        注意：由于ths_index需要更高积分，改用stock_basic的industry字段
        
        Args:
            exchange: 交易所代码（暂时忽略，返回所有行业）
            
        Returns:
            {
                'success': bool,
                'data': List[Dict],  # 板块列表
                'count': int,
                'timestamp': str
            }
        """
        try:
            cache_key = f"sector:list:industry"
            
            # 尝试从缓存获取
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                logger.info(f"从缓存获取行业板块列表")
                return {
                    'success': True,
                    'data': cached_data,
                    'count': len(cached_data),
                    'timestamp': datetime.now().isoformat(),
                    'from_cache': True
                }
            
            logger.info(f"从Tushare获取股票基本信息，按行业分类")
            
            # 使用stock_basic接口获取所有股票（2000积分可用）
            df = self.pro.stock_basic(
                exchange='',
                list_status='L',
                fields='ts_code,symbol,name,area,industry,market'
            )
            
            if df.empty:
                return {
                    'success': False,
                    'error': '未获取到股票数据',
                    'data': [],
                    'count': 0
                }
            
            # 按行业分组统计
            industry_groups = df.groupby('industry').agg({
                'ts_code': 'count',
                'name': 'first'
            }).reset_index()
            
            # 转换数据格式
            sectors = []
            for _, row in industry_groups.iterrows():
                industry = row['industry']
                if pd.isna(industry) or industry == '' or industry == '其他':
                    continue
                    
                sector = {
                    'ts_code': f"IND_{industry}",  # 自定义行业代码
                    'name': industry,
                    'count': int(row['ts_code']),  # 成分股数量
                    'exchange': 'A',
                    'list_date': '',
                    'type': 'I'  # I=行业
                }
                sectors.append(sector)
            
            # 按成分股数量排序
            sectors.sort(key=lambda x: x['count'], reverse=True)
            
            # 缓存数据（24小时）
            self.redis_cache.set_cache(cache_key, sectors, ttl=86400)
            
            logger.info(f"成功获取 {len(sectors)} 个行业板块")
            
            return {
                'success': True,
                'data': sectors,
                'count': len(sectors),
                'timestamp': datetime.now().isoformat(),
                'from_cache': False
            }
            
        except Exception as e:
            logger.error(f"获取板块列表失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'data': [],
                'count': 0
            }
    
    async def get_sector_members(self, sector_code: str) -> Dict[str, Any]:
        """
        获取板块成分股（基于行业分类）
        
        Args:
            sector_code: 板块代码（如：IND_电子）
            
        Returns:
            {
                'success': bool,
                'sector_code': str,
                'data': List[Dict],  # 成分股列表
                'count': int
            }
        """
        try:
            cache_key = f"sector:members:{sector_code}"
            
            # 尝试从缓存获取
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                # 检查缓存数据是否包含价格字段（如果没有则是旧缓存，需要刷新）
                if isinstance(cached_data, list) and len(cached_data) > 0:
                    first_item = cached_data[0]
                    logger.info(f"📊 缓存数据检查: {sector_code}, 第一条数据keys: {list(first_item.keys()) if isinstance(first_item, dict) else 'NOT_DICT'}")
                    
                    has_price = isinstance(first_item, dict) and 'price' in first_item and 'change_pct' in first_item
                    if has_price:
                        logger.info(f"✅ 从缓存获取板块成分股(含价格): {sector_code}, price={first_item.get('price')}")
                        return {
                            'success': True,
                            'sector_code': sector_code,
                            'data': cached_data,
                            'count': len(cached_data),
                            'from_cache': True
                        }
                    else:
                        # 旧缓存数据没有价格字段，删除并重新获取
                        logger.warning(f"⚠️ 板块 {sector_code} 缓存数据格式过旧(无price字段)，清除并重新获取")
                        self.redis_cache.delete_cache(cache_key)
                else:
                    logger.warning(f"⚠️ 板块 {sector_code} 缓存数据格式异常，清除: type={type(cached_data)}")
                    self.redis_cache.delete_cache(cache_key)
            
            # 从sector_code中提取行业名称（格式：IND_行业名）
            if sector_code.startswith('IND_'):
                industry_name = sector_code[4:]
            else:
                industry_name = sector_code
            
            logger.info(f"从Tushare获取行业成分股: {industry_name}")
            
            # 使用stock_basic接口筛选该行业的股票
            df = self.pro.stock_basic(
                exchange='',
                list_status='L',
                fields='ts_code,symbol,name,area,industry,market'
            )
            
            # 筛选该行业的股票
            industry_stocks = df[df['industry'] == industry_name]
            
            if industry_stocks.empty:
                return {
                    'success': False,
                    'error': '未获取到成分股数据',
                    'sector_code': sector_code,
                    'data': [],
                    'count': 0
                }
            
            # 转换数据格式并获取最新K线数据（价格和涨跌幅）
            members = []
            for _, row in industry_stocks.iterrows():
                ts_code = row['ts_code']
                
                # 获取该股票的最新K线数据
                price = 0
                change_pct = 0
                change_amount = 0
                
                try:
                    # 从Redis获取K线数据
                    kline_key = f"stock_trend:{ts_code}"
                    kline_data = self.redis_cache.get_cache(kline_key)
                    
                    if kline_data:
                        # 解析K线数据
                        if isinstance(kline_data, dict):
                            data_list = kline_data.get('data', [])
                        elif isinstance(kline_data, list):
                            data_list = kline_data
                        else:
                            data_list = []
                        
                        # 获取最后一条K线（最新交易日数据）
                        if data_list and len(data_list) > 0:
                            latest_kline = data_list[-1]
                            price = float(latest_kline.get('close', 0))
                            change_pct = float(latest_kline.get('pct_chg', 0))
                            # 计算涨跌额（如果没有提供）
                            if 'change' in latest_kline:
                                change_amount = float(latest_kline.get('change', 0))
                            elif price > 0 and change_pct != 0:
                                # 根据涨跌幅计算涨跌额
                                change_amount = price * change_pct / (100 + change_pct)
                except Exception as e:
                    logger.debug(f"获取 {ts_code} 的K线数据失败: {e}")
                    # 继续处理，使用默认值0
                
                member = {
                    'ts_code': ts_code,
                    'stock_code': row['symbol'],
                    'name': row['name'],
                    'weight': 0,  # 行业分类没有权重
                    'price': round(price, 2),
                    'change_pct': round(change_pct, 2),
                    'change_amount': round(change_amount, 2),
                    'in_date': '',
                    'out_date': ''
                }
                members.append(member)
            
            # 按涨跌幅排序（从高到低）
            members.sort(key=lambda x: x.get('change_pct', 0), reverse=True)
            
            # 缓存数据（5分钟，因为包含实时价格）
            self.redis_cache.set_cache(cache_key, members, ttl=300)
            
            logger.info(f"成功获取行业 {industry_name} 的 {len(members)} 只成分股（含价格数据）")
            
            return {
                'success': True,
                'sector_code': sector_code,
                'data': members,
                'count': len(members),
                'from_cache': False
            }
            
        except Exception as e:
            logger.error(f"获取板块成分股失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'sector_code': sector_code,
                'data': [],
                'count': 0
            }
    
    async def calculate_sector_strength(self, sector_code: str) -> Dict[str, Any]:
        """
        计算板块强度
        
        基于成分股的涨跌幅、成交量等指标计算板块整体强度
        
        Args:
            sector_code: 板块代码
            
        Returns:
            {
                'success': bool,
                'sector_code': str,
                'avg_change_pct': float,  # 平均涨跌幅
                'up_count': int,  # 上涨股票数
                'down_count': int,  # 下跌股票数
                'limit_up_count': int,  # 涨停数
                'limit_down_count': int,  # 跌停数
                'avg_turnover_rate': float,  # 平均换手率
                'total_amount': float,  # 总成交额
                'leading_stock': Dict,  # 领涨股
                'timestamp': str
            }
        """
        try:
            cache_key = f"sector:strength:{sector_code}"
            
            # 尝试从缓存获取（5分钟缓存）
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                logger.info(f"从缓存获取板块强度: {sector_code}")
                return cached_data
            
            # 获取成分股列表
            members_result = await self.get_sector_members(sector_code)
            if not members_result['success'] or not members_result['data']:
                return {
                    'success': False,
                    'error': '无法获取成分股数据',
                    'sector_code': sector_code
                }
            
            members = members_result['data']
            stock_codes = [m['ts_code'] for m in members if m['ts_code']]
            
            if not stock_codes:
                return {
                    'success': False,
                    'error': '成分股列表为空',
                    'sector_code': sector_code
                }
            
            # 获取今日行情数据
            today = datetime.now().strftime('%Y%m%d')
            
            # 批量获取股票的最新数据
            stock_data_list = []
            for ts_code in stock_codes[:50]:  # 限制最多50只，避免API调用过多
                try:
                    # 从Redis缓存获取K线数据
                    kline_key = f"stock_trend:{ts_code}"
                    kline_data = self.redis_cache.get_cache(kline_key)
                    
                    if kline_data:
                        # 处理不同格式的缓存数据
                        if isinstance(kline_data, list) and len(kline_data) > 0:
                            latest = kline_data[-1]
                        elif isinstance(kline_data, dict) and 'data' in kline_data:
                            latest = kline_data['data'][-1] if kline_data['data'] else None
                        else:
                            continue
                        
                        if latest:
                            close = float(latest.get('close', 0))
                            pre_close = float(latest.get('pre_close', 0))
                            
                            if pre_close > 0:
                                change_pct = ((close - pre_close) / pre_close) * 100
                                
                                stock_data_list.append({
                                    'ts_code': ts_code,
                                    'close': close,
                                    'pre_close': pre_close,
                                    'change_pct': change_pct,
                                    'turnover_rate': float(latest.get('turnover_rate', 0)) if latest.get('turnover_rate') else 0,
                                    'amount': float(latest.get('amount', 0)) if latest.get('amount') else 0,
                                    'vol': float(latest.get('vol', 0)) if latest.get('vol') else 0
                                })
                except Exception as e:
                    logger.warning(f"获取股票 {ts_code} 数据失败: {e}")
                    continue
            
            if not stock_data_list:
                return {
                    'success': False,
                    'error': '无法获取成分股行情数据',
                    'sector_code': sector_code
                }
            
            # 计算板块指标
            avg_change_pct = sum(s['change_pct'] for s in stock_data_list) / len(stock_data_list)
            up_count = sum(1 for s in stock_data_list if s['change_pct'] > 0)
            down_count = sum(1 for s in stock_data_list if s['change_pct'] < 0)
            limit_up_count = sum(1 for s in stock_data_list if s['change_pct'] >= 9.9)
            limit_down_count = sum(1 for s in stock_data_list if s['change_pct'] <= -9.9)
            avg_turnover_rate = sum(s['turnover_rate'] for s in stock_data_list) / len(stock_data_list)
            total_amount = sum(s['amount'] for s in stock_data_list)
            
            # 找出领涨股
            leading_stock = max(stock_data_list, key=lambda x: x['change_pct'])
            
            # 获取领涨股名称
            leading_stock_name = ''
            for member in members:
                if member['ts_code'] == leading_stock['ts_code']:
                    leading_stock_name = member['name']
                    break
            
            result = {
                'success': True,
                'sector_code': sector_code,
                'avg_change_pct': round(avg_change_pct, 2),
                'up_count': up_count,
                'down_count': down_count,
                'limit_up_count': limit_up_count,
                'limit_down_count': limit_down_count,
                'avg_turnover_rate': round(avg_turnover_rate, 2),
                'total_amount': round(total_amount, 2),
                'leading_stock': {
                    'ts_code': leading_stock['ts_code'],
                    'name': leading_stock_name,
                    'change_pct': round(leading_stock['change_pct'], 2)
                },
                'sample_count': len(stock_data_list),
                'total_count': len(stock_codes),
                'timestamp': datetime.now().isoformat()
            }
            
            # 缓存5分钟
            self.redis_cache.set_cache(cache_key, result, ttl=300)
            
            logger.info(f"成功计算板块 {sector_code} 强度，平均涨幅: {avg_change_pct:.2f}%")
            
            return result
            
        except Exception as e:
            logger.error(f"计算板块强度失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'sector_code': sector_code
            }
    
    async def get_sector_ranking(self, rank_type: str = 'change', limit: int = 50) -> Dict[str, Any]:
        """
        获取板块排名
        
        Args:
            rank_type: 排名类型 (change=涨跌幅, amount=成交额, turnover=换手率)
            limit: 返回数量限制
            
        Returns:
            {
                'success': bool,
                'rank_type': str,
                'data': List[Dict],  # 排名列表
                'count': int,
                'timestamp': str
            }
        """
        try:
            cache_key = f"sector:ranking:{rank_type}:{limit}"
            
            # 尝试从缓存获取（5分钟）
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                logger.info(f"从缓存获取板块排名: {rank_type}")
                return cached_data
            
            # 获取所有板块列表
            sectors_result = await self.get_sector_list(exchange='A')
            if not sectors_result['success']:
                return {
                    'success': False,
                    'error': '无法获取板块列表',
                    'data': [],
                    'count': 0
                }
            
            sectors = sectors_result['data']
            
            # 计算每个板块的强度（限制数量避免API调用过多）
            sector_strengths = []
            for sector in sectors[:100]:  # 最多处理100个板块
                strength = await self.calculate_sector_strength(sector['ts_code'])
                if strength['success']:
                    sector_strengths.append({
                        'ts_code': sector['ts_code'],
                        'name': sector['name'],
                        'type': sector.get('type', ''),
                        'stock_count': sector.get('count', 0),
                        'avg_change_pct': strength['avg_change_pct'],
                        'up_count': strength['up_count'],
                        'down_count': strength['down_count'],
                        'limit_up_count': strength['limit_up_count'],
                        'avg_turnover_rate': strength['avg_turnover_rate'],
                        'total_amount': strength['total_amount'],
                        'leading_stock': strength['leading_stock']
                    })
            
            # 根据排名类型排序
            if rank_type == 'change':
                sector_strengths.sort(key=lambda x: x['avg_change_pct'], reverse=True)
            elif rank_type == 'amount':
                sector_strengths.sort(key=lambda x: x['total_amount'], reverse=True)
            elif rank_type == 'turnover':
                sector_strengths.sort(key=lambda x: x['avg_turnover_rate'], reverse=True)
            
            # 限制返回数量
            sector_strengths = sector_strengths[:limit]
            
            result = {
                'success': True,
                'rank_type': rank_type,
                'data': sector_strengths,
                'count': len(sector_strengths),
                'timestamp': datetime.now().isoformat()
            }
            
            # 缓存5分钟
            self.redis_cache.set_cache(cache_key, result, ttl=300)
            
            logger.info(f"成功获取板块排名，类型: {rank_type}，数量: {len(sector_strengths)}")
            
            return result
            
        except Exception as e:
            logger.error(f"获取板块排名失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'rank_type': rank_type,
                'data': [],
                'count': 0
            }
    
    async def get_hot_concepts(self, limit: int = 20) -> Dict[str, Any]:
        """
        获取热门行业（改名为热门概念以保持接口兼容）
        
        基于涨停股数量、平均涨幅等指标筛选热门行业
        
        Args:
            limit: 返回数量限制
            
        Returns:
            {
                'success': bool,
                'data': List[Dict],  # 热门行业列表
                'count': int,
                'timestamp': str
            }
        """
        try:
            cache_key = f"sector:hot_industries:{limit}"
            
            # 尝试从缓存获取（5分钟）
            cached_data = self.redis_cache.get_cache(cache_key)
            if cached_data:
                logger.info("从缓存获取热门行业")
                return cached_data
            
            # 获取行业板块列表
            sectors_result = await self.get_sector_list(exchange='A')
            if not sectors_result['success']:
                return {
                    'success': False,
                    'error': '无法获取行业板块列表',
                    'data': [],
                    'count': 0
                }
            
            industries = sectors_result['data']
            
            # 计算每个行业的热度
            hot_industries = []
            for industry in industries[:50]:  # 限制处理数量
                strength = await self.calculate_sector_strength(industry['ts_code'])
                if strength['success']:
                    # 计算热度分数：涨停数*10 + 平均涨幅*2 + 上涨比例*5
                    up_ratio = strength['up_count'] / max(strength['sample_count'], 1) * 100
                    heat_score = (
                        strength['limit_up_count'] * 10 +
                        strength['avg_change_pct'] * 2 +
                        up_ratio * 5
                    )
                    
                    hot_industries.append({
                        'ts_code': industry['ts_code'],
                        'name': industry['name'],
                        'stock_count': industry.get('count', 0),
                        'avg_change_pct': strength['avg_change_pct'],
                        'up_count': strength['up_count'],
                        'limit_up_count': strength['limit_up_count'],
                        'up_ratio': round(up_ratio, 2),
                        'heat_score': round(heat_score, 2),
                        'leading_stock': strength['leading_stock']
                    })
            
            # 按热度分数排序
            hot_industries.sort(key=lambda x: x['heat_score'], reverse=True)
            hot_industries = hot_industries[:limit]
            
            result = {
                'success': True,
                'data': hot_industries,
                'count': len(hot_industries),
                'timestamp': datetime.now().isoformat()
            }
            
            # 缓存5分钟
            self.redis_cache.set_cache(cache_key, result, ttl=300)
            
            logger.info(f"成功获取 {len(hot_industries)} 个热门行业")
            
            return result
            
        except Exception as e:
            logger.error(f"获取热门行业失败: {e}")
            return {
                'success': False,
                'error': str(e),
                'data': [],
                'count': 0
            }

