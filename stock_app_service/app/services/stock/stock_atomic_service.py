# -*- coding: utf-8 -*-
"""
股票数据原子服务
提供DDD风格的原子能力方法，便于维护和组织
"""

import asyncio
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import pandas as pd

from app.core.logging import logger
from app.core.config import settings
from app.core.etf_config import get_etf_list
from app.core.invalid_stock_codes import filter_valid_stocks
from app.db.session import RedisCache


class StockAtomicService:
    """股票数据原子服务类"""
    
    def __init__(self):
        self.redis_cache = RedisCache()
        self.stock_keys = {
            'stock_codes': 'stocks:codes:all',
            'stock_kline': 'stock_trend:{}',
        }
    
    # ==================== 1.1 获取有效股票代码列表方法 ====================
    
    async def get_valid_stock_codes(self, include_etf: bool = True) -> List[Dict[str, Any]]:
        """
        获取所有有效的股票和ETF代码列表（统一封装方法）
        
        功能：
        1. 获取A股股票代码（沪深北三市场）
        2. 获取ETF代码
        3. 自动过滤无效代码（北交所废弃代码、退市股票等）
        4. 统一汇总日志输出
        
        Args:
            include_etf: 是否包含ETF，默认True（将ETF作为特殊股票处理）
            
        Returns:
            有效股票列表，每个元素包含: ts_code, symbol, name, area, industry, market, list_date
        """
        logger.info("=" * 80)
        logger.info("开始获取所有有效股票和ETF代码...")
        logger.info("=" * 80)
        
        start_time = datetime.now()
        
        try:
            # 1. 获取A股股票列表
            logger.info("步骤1: 获取A股股票代码（沪深北三市场）...")
            stock_list = await self._fetch_a_stock_list()
            stock_count = len(stock_list)
            logger.info(f"✓ 获取到A股股票代码: {stock_count} 只")
            
            # 统计各市场股票数量
            sh_count = sum(1 for s in stock_list if s.get('ts_code', '').endswith('.SH'))
            sz_count = sum(1 for s in stock_list if s.get('ts_code', '').endswith('.SZ'))
            bj_count = sum(1 for s in stock_list if s.get('ts_code', '').endswith('.BJ'))
            logger.info(f"  - 上海市场(SH): {sh_count} 只")
            logger.info(f"  - 深圳市场(SZ): {sz_count} 只")
            logger.info(f"  - 北京市场(BJ): {bj_count} 只")
            
            # 2. 如果包含ETF，添加ETF列表
            etf_count = 0
            etf_sh_count = 0
            etf_sz_count = 0
            if include_etf:
                logger.info("步骤2: 获取ETF代码...")
                etf_list = get_etf_list()
                etf_count = len(etf_list)
                logger.info(f"✓ 获取到ETF代码: {etf_count} 只")
                
                # 统计ETF市场分布
                etf_sh_count = sum(1 for e in etf_list if e.get('ts_code', '').endswith('.SH'))
                etf_sz_count = sum(1 for e in etf_list if e.get('ts_code', '').endswith('.SZ'))
                logger.info(f"  - 上海ETF(SH): {etf_sh_count} 只")
                logger.info(f"  - 深圳ETF(SZ): {etf_sz_count} 只")
                
                stock_list.extend(etf_list)
            else:
                logger.info("步骤2: 跳过ETF代码获取")
            
            # 3. 合并所有代码
            logger.info("步骤3: 合并股票和ETF代码...")
            total_before_filter = len(stock_list)
            logger.info(f"✓ 合并后总代码数: {total_before_filter} 只")
            
            # 4. 过滤无效股票代码（包括北交所废弃代码）
            logger.info("步骤4: 过滤无效代码...")
            from app.core.invalid_stock_codes import filter_valid_stocks, get_invalid_codes_summary
            
            # 显示无效代码配置统计
            invalid_summary = get_invalid_codes_summary()
            logger.info(f"  - 无效代码配置:")
            logger.info(f"    · 北交所废弃代码: {invalid_summary['bj_codes']} 只")
            logger.info(f"    · 退市股票代码: {invalid_summary['delist_codes']} 只")
            logger.info(f"    · 暂停上市代码: {invalid_summary['suspend_codes']} 只")
            logger.info(f"    · 总计: {invalid_summary['total']} 只")
            
            valid_stock_list = filter_valid_stocks(stock_list)
            filtered_count = total_before_filter - len(valid_stock_list)
            
            if filtered_count > 0:
                logger.warning(f"✗ 实际过滤掉: {filtered_count} 只无效代码")
                # 统计被过滤的代码类型
                filtered_codes = [s for s in stock_list if s not in valid_stock_list]
                filtered_stocks = [s for s in filtered_codes if s.get('market') != 'ETF']
                filtered_etfs = [s for s in filtered_codes if s.get('market') == 'ETF']
                if filtered_stocks:
                    logger.warning(f"  - 被过滤的股票: {len(filtered_stocks)} 只")
                if filtered_etfs:
                    logger.warning(f"  - 被过滤的ETF: {len(filtered_etfs)} 只")
            else:
                logger.info(f"✓ 未发现需要过滤的无效代码")
            
            # 5. 统计最终结果
            final_stock_count = sum(1 for s in valid_stock_list if s.get('market') != 'ETF')
            final_etf_count = sum(1 for s in valid_stock_list if s.get('market') == 'ETF')
            
            logger.info("步骤5: 存储到Redis...")
            self.redis_cache.set_cache(
                self.stock_keys['stock_codes'],
                valid_stock_list,
                ttl=None  # 永久保存
            )
            logger.info(f"✓ 已存储到Redis (永久保存)")
            
            # 6. 输出统一汇总日志
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info("=" * 80)
            logger.info("📊 获取股票代码完成 - 汇总统计")
            logger.info("=" * 80)
            logger.info(f"总耗时: {elapsed:.2f} 秒")
            logger.info(f"")
            logger.info(f"【原始数据】")
            logger.info(f"  A股股票: {stock_count} 只 (SH:{sh_count}, SZ:{sz_count}, BJ:{bj_count})")
            if include_etf:
                logger.info(f"  ETF基金: {etf_count} 只 (SH:{etf_sh_count}, SZ:{etf_sz_count})")
            logger.info(f"  合计: {total_before_filter} 只")
            logger.info(f"")
            logger.info(f"【过滤结果】")
            logger.info(f"  无效代码配置: {invalid_summary['total']} 只")
            logger.info(f"  实际过滤: {filtered_count} 只")
            logger.info(f"")
            logger.info(f"【最终结果】")
            logger.info(f"  有效股票: {final_stock_count} 只")
            if include_etf:
                logger.info(f"  有效ETF: {final_etf_count} 只")
            logger.info(f"  总计: {len(valid_stock_list)} 只 ✓")
            logger.info("=" * 80)
            
            return valid_stock_list
            
        except Exception as e:
            logger.error("=" * 80)
            logger.error(f"✗ 获取有效股票代码失败: {e}")
            logger.error("=" * 80)
            import traceback
            logger.error(traceback.format_exc())
            return []
    
    async def _fetch_a_stock_list(self) -> List[Dict[str, Any]]:
        """
        从Tushare获取A股股票列表
        
        Returns:
            A股股票列表
        """
        try:
            import tushare as ts
            
            # 初始化Tushare
            ts.set_token(settings.TUSHARE_TOKEN)
            pro = ts.pro_api()
            
            # 获取股票列表
            df = pro.stock_basic(
                exchange='',
                list_status='L',  # L=上市 D=退市 P=暂停上市
                fields='ts_code,symbol,name,area,industry,market,list_date'
            )
            
            # 转换为字典列表
            stock_list = df.to_dict('records')
            
            return stock_list
            
        except Exception as e:
            logger.error(f"从Tushare获取A股列表失败: {e}")
            return []
    
    # ==================== 1.2 全量更新所有股票方法 ====================
    
    async def full_update_all_stocks(
        self,
        days: int = 180,
        batch_size: int = 50,
        max_concurrent: int = 10
    ) -> Dict[str, Any]:
        """
        全量更新所有股票的历史K线数据（包括ETF和股票）
        清空并重新获取所有股票的历史K线数据
        
        Args:
            days: 获取天数，默认180天
            batch_size: 每批处理的股票数量
            max_concurrent: 最大并发数
            
        Returns:
            更新结果统计
        """
        logger.info(f"开始全量更新所有股票K线数据，天数={days}天...")
        start_time = datetime.now()
        
        try:
            # 1. 获取有效股票列表
            stock_list = self.redis_cache.get_cache(self.stock_keys['stock_codes'])
            if not stock_list:
                logger.warning("股票代码列表为空，先获取股票代码")
                stock_list = await self.get_valid_stock_codes(include_etf=True)
            
            total_count = len(stock_list)
            logger.info(f"需要更新 {total_count} 只股票的K线数据")
            
            # 2. 清空所有K线数据
            await self._clear_all_kline_data(stock_list)
            
            # 3. 批量获取K线数据
            result = await self._batch_fetch_kline_data(
                stock_list,
                days=days,
                batch_size=batch_size,
                max_concurrent=max_concurrent
            )
            
            # 4. 失败补偿：对失败的股票重试一次
            if result['failed_count'] > 0 and result.get('failed_stocks'):
                logger.warning(f"检测到 {result['failed_count']} 只股票获取失败，开始补偿重试...")
                compensation_result = await self._compensate_failed_stocks(
                    result['failed_stocks'],
                    days=days,
                    max_concurrent=max_concurrent
                )
                
                # 更新统计
                result['success_count'] += compensation_result['success_count']
                result['failed_count'] = compensation_result['failed_count']
                result['compensation_attempted'] = compensation_result['total_count']
                result['compensation_success'] = compensation_result['success_count']
                
                logger.info(
                    f"补偿完成: 重试 {compensation_result['total_count']} 只, "
                    f"成功 {compensation_result['success_count']} 只, "
                    f"最终失败 {compensation_result['failed_count']} 只"
                )
            
            elapsed = (datetime.now() - start_time).total_seconds()
            result['elapsed_seconds'] = round(elapsed, 2)
            result['elapsed_minutes'] = round(elapsed / 60, 2)
            
            logger.info(
                f"全量更新完成: 总计={result['total_count']}, "
                f"成功={result['success_count']}, "
                f"失败={result['failed_count']}, "
                f"成功率={result['success_rate']:.2f}%, "
                f"耗时={result['elapsed_minutes']:.2f}分钟"
            )
            
            return result
            
        except Exception as e:
            logger.error(f"全量更新所有股票失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success_count': 0,
                'failed_count': 0,
                'total_count': 0,
                'error': str(e)
            }
    
    async def _clear_all_kline_data(self, stock_list: List[Dict[str, Any]]):
        """清空所有股票的K线数据"""
        logger.info("开始清空所有股票K线数据...")
        cleared_count = 0
        
        for stock in stock_list:
            ts_code = stock.get('ts_code')
            if ts_code:
                key = self.stock_keys['stock_kline'].format(ts_code)
                self.redis_cache.delete_cache(key)
                cleared_count += 1
        
        logger.info(f"清空K线数据完成，共清空 {cleared_count} 只股票")
    
    async def _batch_fetch_kline_data(
        self,
        stock_list: List[Dict[str, Any]],
        days: int = 180,
        batch_size: int = 50,
        max_concurrent: int = 10
    ) -> Dict[str, Any]:
        """批量获取K线数据"""
        total_count = len(stock_list)
        success_count = 0
        failed_count = 0
        failed_stocks = []  # 记录失败的股票
        
        # 分批处理
        for i in range(0, total_count, batch_size):
            batch = stock_list[i:i + batch_size]
            batch_num = i // batch_size + 1
            total_batches = (total_count + batch_size - 1) // batch_size
            
            logger.info(f"处理第 {batch_num}/{total_batches} 批，共 {len(batch)} 只股票")
            
            # 并发获取
            semaphore = asyncio.Semaphore(max_concurrent)
            tasks = [
                self._fetch_single_stock_kline(stock, days, semaphore)
                for stock in batch
            ]
            
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # 统计结果并记录失败的股票
            batch_success = 0
            batch_failed = 0
            for idx, result in enumerate(results):
                if isinstance(result, Exception):
                    failed_count += 1
                    batch_failed += 1
                    failed_stocks.append(batch[idx])
                elif result:
                    success_count += 1
                    batch_success += 1
                else:
                    failed_count += 1
                    batch_failed += 1
                    failed_stocks.append(batch[idx])
            
            # 输出批次汇总日志
            logger.info(f"第 {batch_num} 批完成: 成功 {batch_success}/{len(batch)}, 失败 {batch_failed}/{len(batch)}, 累计成功 {success_count}/{total_count}")
            
            # 避免频繁请求
            await asyncio.sleep(0.5)
        
        return {
            'total_count': total_count,
            'success_count': success_count,
            'failed_count': failed_count,
            'failed_stocks': failed_stocks,  # 返回失败的股票列表
            'success_rate': round(success_count / total_count * 100, 2) if total_count > 0 else 0
        }
    
    async def _fetch_single_stock_kline(
        self,
        stock: Dict[str, Any],
        days: int,
        semaphore: asyncio.Semaphore
    ) -> bool:
        """获取单只股票的K线数据"""
        async with semaphore:
            try:
                ts_code = stock.get('ts_code')
                if not ts_code:
                    return False
                
                # 使用线程池执行同步的Tushare调用
                import concurrent.futures
                loop = asyncio.get_event_loop()
                
                with concurrent.futures.ThreadPoolExecutor() as executor:
                    kline_data = await loop.run_in_executor(
                        executor,
                        self._sync_fetch_kline,
                        ts_code,
                        days
                    )
                
                if kline_data and len(kline_data) > 0:
                    # 缓存到Redis
                    key = self.stock_keys['stock_kline'].format(ts_code)
                    cache_data = {
                        'data': kline_data,
                        'updated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                        'data_count': len(kline_data),
                        'source': 'tushare',
                        'last_update_type': 'full_update'
                    }
                    self.redis_cache.set_cache(key, cache_data, ttl=86400 * 30)  # 30天
                    return True
                else:
                    # 不输出每条失败日志，由批次汇总统计
                    return False
                    
            except Exception as e:
                # 不输出每条失败日志，由批次汇总统计
                return False
    
    async def _compensate_failed_stocks(
        self,
        failed_stocks: List[Dict[str, Any]],
        days: int = 180,
        max_concurrent: int = 5
    ) -> Dict[str, Any]:
        """
        补偿失败的股票数据获取
        
        Args:
            failed_stocks: 失败的股票列表
            days: 获取天数
            max_concurrent: 最大并发数（补偿时使用较小的并发数）
            
        Returns:
            补偿结果统计
        """
        total_count = len(failed_stocks)
        success_count = 0
        failed_count = 0
        
        logger.info(f"开始补偿 {total_count} 只失败股票...")
        
        # 等待5秒，让API限制恢复
        await asyncio.sleep(5)
        
        # 并发重试
        semaphore = asyncio.Semaphore(max_concurrent)
        tasks = [
            self._fetch_single_stock_kline(stock, days, semaphore)
            for stock in failed_stocks
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # 统计结果
        for idx, result in enumerate(results):
            if isinstance(result, Exception):
                failed_count += 1
            elif result:
                success_count += 1
            else:
                failed_count += 1
                # 记录最终失败的股票代码
                ts_code = failed_stocks[idx].get('ts_code', 'unknown')
                logger.warning(f"补偿失败: {ts_code}")
        
        return {
            'total_count': total_count,
            'success_count': success_count,
            'failed_count': failed_count
        }
    
    def _sync_fetch_kline(self, ts_code: str, days: int) -> List[Dict[str, Any]]:
        """同步获取K线数据（在线程池中执行）"""
        try:
            # 使用统一数据服务
            from app.services.stock.unified_data_service import unified_data_service
            
            # 判断是否为ETF（代码以5或1开头的6位数字）
            code = ts_code.split('.')[0]
            is_etf = len(code) == 6 and code[0] in ['5', '1']
            
            kline_data = unified_data_service.fetch_historical_data(
                ts_code=ts_code,
                days=days,
                is_etf=is_etf
            )
            
            return kline_data
            
        except Exception as e:
            logger.error(f"同步获取K线数据失败 {ts_code}: {e}")
            return []
    
    # ==================== 1.3 实时更新所有股票数据方法 ====================
    
    async def realtime_update_all_stocks(self) -> Dict[str, Any]:
        """
        实时更新所有股票数据（包括ETF）
        1. 获取所有股票和ETF的实时数据
        2. 更新到历史K线数据（当日有则更新，无则新增）
        
        Returns:
            更新结果统计
        """
        logger.info("开始实时更新所有股票数据（包括ETF）...")
        start_time = datetime.now()
        
        try:
            # 1. 获取实时数据
            from app.services.stock.unified_data_service import unified_data_service
            
            realtime_result = await unified_data_service.async_fetch_all_realtime_data()
            
            if not realtime_result['success']:
                logger.error("获取实时数据失败")
                return {
                    'success': False,
                    'message': '获取实时数据失败',
                    'stock_count': 0,
                    'etf_count': 0,
                    'total_count': 0
                }
            
            logger.info(
                f"成功获取实时数据: "
                f"股票 {realtime_result['stock_count']} 只, "
                f"ETF {realtime_result['etf_count']} 只"
            )
            
            # 2. 批量更新K线数据
            update_result = await unified_data_service.async_batch_update_klines_with_realtime(
                stock_df=realtime_result['stock_data'],
                etf_df=realtime_result['etf_data']
            )
            
            elapsed = (datetime.now() - start_time).total_seconds()
            
            result = {
                'success': True,
                'message': '实时更新完成',
                'stock_count': realtime_result['stock_count'],
                'etf_count': realtime_result['etf_count'],
                'total_count': realtime_result['total_count'],
                'stock_updated': update_result['stock_updated'],
                'stock_failed': update_result['stock_failed'],
                'etf_updated': update_result['etf_updated'],
                'etf_failed': update_result['etf_failed'],
                'total_updated': update_result['total_updated'],
                'total_failed': update_result['total_failed'],
                'elapsed_seconds': round(elapsed, 2),
                'update_time': realtime_result['update_time']
            }
            
            logger.info(
                f"实时更新完成: "
                f"成功更新 {result['total_updated']} 只, "
                f"失败 {result['total_failed']} 只, "
                f"耗时 {elapsed:.2f}秒"
            )
            
            return result
            
        except Exception as e:
            logger.error(f"实时更新所有股票失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'message': f'实时更新失败: {str(e)}',
                'error': str(e)
            }
    
    # ==================== 1.4 策略信号计算方法 ====================
    
    async def calculate_strategy_signals(
        self,
        force_recalculate: bool = False
    ) -> Dict[str, Any]:
        """
        计算所有股票的策略信号
        
        Args:
            force_recalculate: 是否强制重新计算
            
        Returns:
            计算结果统计
        """
        logger.info(f"开始计算策略信号，强制重算={force_recalculate}")
        start_time = datetime.now()
        
        try:
            # 使用现有的signal_manager
            from app.services.signal.signal_manager import signal_manager
            
            # 初始化signal_manager
            await signal_manager.initialize()
            
            # 计算信号
            result = await signal_manager.calculate_buy_signals(
                force_recalculate=force_recalculate
            )
            
            elapsed = (datetime.now() - start_time).total_seconds()
            result['elapsed_seconds'] = round(elapsed, 2)
            
            logger.info(f"策略信号计算完成，耗时 {elapsed:.2f}秒")
            
            return result
            
        except Exception as e:
            logger.error(f"计算策略信号失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'error': str(e)
            }
    
    # ==================== 1.5 新闻爬取方法 ====================
    
    async def crawl_news(self, days: int = 1) -> Dict[str, Any]:
        """
        爬取财经新闻
        
        Args:
            days: 爬取天数
            
        Returns:
            爬取结果统计
        """
        start_time = datetime.now()
        
        try:
            # 使用现有的新闻服务
            from app.services.analysis.news_analysis_service import get_phoenix_finance_news
            
            # 爬取新闻
            news_list = get_phoenix_finance_news(days=days, skip_content=False, force_crawl=True)
            
            if not news_list or len(news_list) < 5:
                logger.warning(f"爬取到的新闻数据质量不佳，数量: {len(news_list)}")
                return {
                    'success': False,
                    'news_count': len(news_list),
                    'message': '新闻数据质量不佳'
                }
            
            # 格式化并缓存
            formatted_news = []
            for news in news_list:
                formatted_news.append({
                    'title': news['title'],
                    'url': news['url'],
                    'datetime': news['datetime'],
                    'source': news['source'],
                    'summary': news.get('content', '')[:150] + '...' if news.get('content') and len(news.get('content')) > 150 else news.get('content', '')
                })
            
            # 缓存到Redis
            cache_data = {
                'news': formatted_news,
                'count': len(formatted_news),
                'updated_at': start_time.strftime('%Y-%m-%d %H:%M:%S'),
                'data_source': 'phoenix_finance'
            }
            
            self.redis_cache.set_cache('news:latest', cache_data, ttl=7200)  # 2小时
            
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info(f"✓ 新闻爬取完成: {len(formatted_news)}条，耗时 {elapsed:.1f}秒")
            
            return {
                'success': True,
                'news_count': len(formatted_news),
                'elapsed_seconds': round(elapsed, 2)
            }
            
        except Exception as e:
            logger.error(f"爬取新闻失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'news_count': 0,
                'error': str(e)
            }
    
    # ==================== 1.6 图表文件清理方法 ====================
    
    async def cleanup_chart_files(self) -> Dict[str, Any]:
        """
        清理所有生成的图表HTML文件
        
        Returns:
            清理结果统计
        """
        logger.info("开始清理图表文件...")
        start_time = datetime.now()
        
        try:
            import os
            import glob
            from app.core.config import CHART_DIR
            
            if not os.path.exists(CHART_DIR):
                logger.info("图表目录不存在，跳过清理")
                return {
                    'success': True,
                    'deleted_count': 0,
                    'message': '图表目录不存在'
                }
            
            # 获取所有HTML文件
            html_files = glob.glob(os.path.join(CHART_DIR, '*.html'))
            
            if not html_files:
                logger.info("没有找到需要清理的图表文件")
                return {
                    'success': True,
                    'deleted_count': 0,
                    'message': '没有需要清理的文件'
                }
            
            # 删除所有HTML文件
            deleted_count = 0
            for file_path in html_files:
                try:
                    os.remove(file_path)
                    deleted_count += 1
                except Exception as e:
                    logger.error(f"删除文件失败 {file_path}: {e}")
            
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info(f"图表文件清理完成，共删除 {deleted_count} 个文件，耗时 {elapsed:.2f}秒")
            
            return {
                'success': True,
                'deleted_count': deleted_count,
                'elapsed_seconds': round(elapsed, 2)
            }
            
        except Exception as e:
            logger.error(f"清理图表文件失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'deleted_count': 0,
                'error': str(e)
            }


# 全局单例
stock_atomic_service = StockAtomicService()

