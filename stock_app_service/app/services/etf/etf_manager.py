# -*- coding: utf-8 -*-
"""
ETF 数据管理器
负责 ETF 数据的读取、转换和管理
确保 ETF 数据格式与股票数据格式完全一致
"""

import os
import pandas as pd
import tushare as ts
from typing import List, Dict, Any
from datetime import datetime

from app.core.logging import logger
from app.core.config import settings


class ETFManager:
    """ETF 数据管理器"""
    
    # ETF 文件路径
    ETF_EXCEL_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'etf', 'ETF列表.xlsx')
    ETF_CSV_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'etf', 'ETF列表.csv')
    
    def __init__(self):
        """初始化 ETF 管理器"""
        self.tushare_token = settings.TUSHARE_TOKEN
        if self.tushare_token:
            ts.set_token(self.tushare_token)
            self.pro = ts.pro_api()
        else:
            self.pro = None
            logger.warning("未配置 Tushare Token，ETF 数据获取可能失败")
    
    def load_etf_list_from_csv(self) -> List[Dict[str, Any]]:
        """
        从 CSV 文件加载 ETF 列表（推荐方式）
        
        Returns:
            ETF 列表，格式与股票数据完全一致
        """
        try:
            if not os.path.exists(self.ETF_CSV_PATH):
                logger.warning(f"ETF CSV 文件不存在: {self.ETF_CSV_PATH}")
                return []
            
            # 读取 CSV 文件
            df = pd.read_csv(self.ETF_CSV_PATH)
            logger.info(f"从 CSV 读取到 {len(df)} 条 ETF 记录")
            
            etf_list = []
            for _, row in df.iterrows():
                # CSV 已经是标准格式
                etf_data = {
                    'ts_code': str(row.get('ts_code', '')),
                    'symbol': str(row.get('symbol', '')),
                    'name': str(row.get('name', '')),
                    'area': str(row.get('area', '')),
                    'industry': str(row.get('industry', 'ETF')),
                    'market': str(row.get('market', 'ETF')),
                    'list_date': str(row.get('list_date', '')),
                }
                
                # 跳过无效数据
                if not etf_data['ts_code'] or etf_data['ts_code'] == 'nan':
                    continue
                
                etf_list.append(etf_data)
            
            logger.info(f"✅ 成功从 CSV 加载 {len(etf_list)} 个 ETF")
            return etf_list
            
        except Exception as e:
            logger.error(f"从 CSV 加载 ETF 列表失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return []
    
    def load_etf_list_from_excel(self) -> List[Dict[str, Any]]:
        """
        从 Excel 文件加载 ETF 列表
        
        Returns:
            ETF 列表，格式与股票数据完全一致
        """
        try:
            if not os.path.exists(self.ETF_EXCEL_PATH):
                logger.error(f"ETF Excel 文件不存在: {self.ETF_EXCEL_PATH}")
                return []
            
            # 尝试读取 Excel 文件
            try:
                df = pd.read_excel(self.ETF_EXCEL_PATH, engine='openpyxl')
            except ImportError:
                logger.warning("openpyxl 未安装，尝试使用其他引擎读取 Excel")
                try:
                    df = pd.read_excel(self.ETF_EXCEL_PATH)
                except Exception as e:
                    logger.error(f"读取 Excel 失败: {e}")
                    logger.info("提示：请安装 openpyxl: pip install openpyxl")
                    return []
            
            logger.info(f"从 Excel 读取到 {len(df)} 条 ETF 记录")
            
            etf_list = []
            for _, row in df.iterrows():
                # 获取 ETF 代码和名称
                # 假设 Excel 列名为 '代码' 和 '名称'，如果不同需要调整
                code = str(row.get('代码', row.get('code', ''))).strip()
                name = str(row.get('名称', row.get('name', ''))).strip()
                
                if not code:
                    continue
                
                # 转换为 ts_code 格式
                # ETF 代码通常是 6 位数字
                if len(code) == 6 and code.isdigit():
                    # 判断市场：51开头的是上交所，15开头的是深交所
                    if code.startswith('51') or code.startswith('50'):
                        ts_code = f"{code}.SH"
                        market = 'SH'
                    elif code.startswith('15') or code.startswith('16'):
                        ts_code = f"{code}.SZ"
                        market = 'SZ'
                    else:
                        # 默认判断：6开头上交所，其他深交所
                        if code.startswith('6'):
                            ts_code = f"{code}.SH"
                            market = 'SH'
                        else:
                            ts_code = f"{code}.SZ"
                            market = 'SZ'
                else:
                    # 如果已经是 ts_code 格式
                    ts_code = code
                    if '.SH' in code:
                        market = 'SH'
                        code = code.replace('.SH', '')
                    elif '.SZ' in code:
                        market = 'SZ'
                        code = code.replace('.SZ', '')
                    else:
                        market = 'SH'  # 默认
                
                # 构造与股票完全一致的数据格式
                etf_data = {
                    'ts_code': ts_code,
                    'symbol': code,
                    'name': name,
                    'area': '',  # ETF 无地域属性
                    'industry': 'ETF',  # 标识为 ETF
                    'market': 'ETF',  # 虚拟的 ETF 板块（用于分类和过滤）
                    'list_date': '',  # 可以后续从 Tushare 获取
                }
                
                etf_list.append(etf_data)
            
            logger.info(f"✅ 成功加载 {len(etf_list)} 个 ETF")
            return etf_list
            
        except Exception as e:
            logger.error(f"从 Excel 加载 ETF 列表失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return []
    
    def enrich_etf_info_from_tushare(self, etf_list: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        从 Tushare 获取 ETF 详细信息，补充上市日期等字段
        
        Args:
            etf_list: ETF 列表
            
        Returns:
            补充信息后的 ETF 列表
        """
        if not self.pro:
            logger.warning("未配置 Tushare API，跳过 ETF 信息补充")
            return etf_list
        
        try:
            # 获取所有 ETF 基本信息
            df = self.pro.fund_basic(market='E')  # E 表示 ETF
            
            if df.empty:
                logger.warning("Tushare 未返回 ETF 数据")
                return etf_list
            
            # 创建代码到信息的映射
            etf_info_map = {}
            for _, row in df.iterrows():
                ts_code = row['ts_code']
                etf_info_map[ts_code] = {
                    'list_date': row.get('list_date', ''),
                    'fund_type': row.get('fund_type', ''),
                    'issue_date': row.get('issue_date', ''),
                }
            
            # 补充信息
            enriched_list = []
            for etf in etf_list:
                ts_code = etf['ts_code']
                if ts_code in etf_info_map:
                    info = etf_info_map[ts_code]
                    etf['list_date'] = info.get('list_date', '')
                    logger.debug(f"补充 ETF 信息: {ts_code} - {etf['name']}")
                
                enriched_list.append(etf)
            
            logger.info(f"✅ 从 Tushare 补充了 {len([e for e in enriched_list if e.get('list_date')])} 个 ETF 的详细信息")
            return enriched_list
            
        except Exception as e:
            logger.warning(f"从 Tushare 获取 ETF 信息失败: {e}")
            return etf_list
    
    def load_etf_list_from_tushare(self, filter_lof: bool = True) -> List[Dict[str, Any]]:
        """
        从 Tushare 直接获取 ETF 列表（备用方案）
        
        Args:
            filter_lof: 是否过滤掉 LOF 基金，默认 True
        
        Returns:
            ETF 列表，格式与股票数据完全一致
        """
        if not self.pro:
            logger.error("未配置 Tushare API，无法获取 ETF 列表")
            return []
        
        try:
            # 获取所有 ETF 基本信息
            df = self.pro.fund_basic(market='E')  # E 表示 ETF
            
            if df.empty:
                logger.warning("Tushare 未返回 ETF 数据")
                return []
            
            etf_list = []
            filtered_count = 0
            
            for _, row in df.iterrows():
                ts_code = row['ts_code']
                symbol = ts_code.split('.')[0]
                name = row.get('name', '')
                
                # 过滤 LOF
                if filter_lof and ('LOF' in name or 'lof' in name.lower()):
                    filtered_count += 1
                    continue
                
                # 判断市场
                if '.SH' in ts_code:
                    market_code = 'SH'
                elif '.SZ' in ts_code:
                    market_code = 'SZ'
                else:
                    market_code = 'SH'  # 默认
                
                # 判断 T+0 还是 T+1
                # T+0交易：跨境、债券、黄金、货币、QDII、港股/美股相关ETF
                # T+1交易：A股市场ETF（大部分）
                # 注意：建议直接使用 CSV 中预设的 industry 字段，更准确
                t0_keywords = [
                    # 跨境/海外
                    '跨境', 'QDII', '海外', '全球', '国际',
                    # 港股
                    '港股', '恒生', '香港',
                    # 美股
                    '美股', '纳', '标普', '道琼',  # '纳' 涵盖纳指、纳斯达克
                    # 其他海外市场
                    '日经', '欧洲', '德国', '英国', '法国', '新兴', '亚太',
                    # 商品
                    '债', '黄金', '货币', '白银', '原油'
                ]
                is_t0 = any(keyword in name for keyword in t0_keywords)
                industry = 'T+0交易' if is_t0 else 'T+1交易'
                
                # 构造与股票完全一致的数据格式
                etf_data = {
                    'ts_code': ts_code,
                    'symbol': symbol,
                    'name': name,
                    'area': '',  # ETF 无地域属性
                    'industry': industry,  # T+0交易 或 T+1交易
                    'market': 'ETF',  # 虚拟的 ETF 板块（用于分类和过滤）
                    'list_date': row.get('list_date', ''),
                }
                
                etf_list.append(etf_data)
            
            if filter_lof:
                logger.info(f"✅ 从 Tushare 获取 {len(etf_list)} 个纯 ETF（已过滤 {filtered_count} 个 LOF）")
            else:
                logger.info(f"✅ 从 Tushare 获取 {len(etf_list)} 个 ETF")
            
            return etf_list
            
        except Exception as e:
            logger.error(f"从 Tushare 获取 ETF 列表失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return []
    
    def get_etf_list(self, enrich: bool = False, use_csv: bool = True) -> List[Dict[str, Any]]:
        """
        获取 ETF 列表（主入口）
        
        Args:
            enrich: 是否从 Tushare 补充详细信息（已弃用）
            use_csv: 是否使用配置文件（推荐，默认 True）
            
        Returns:
            ETF 列表，格式与股票数据完全一致
        """
        # 优先从配置文件加载（最可靠）
        try:
            from app.etf.etf_config import get_etf_list as get_config_etf_list
            etf_list = get_config_etf_list()
            if etf_list:
                logger.info(f"📊 从配置文件加载 ETF 列表: {len(etf_list)} 个 ETF")
                return etf_list
        except Exception as e:
            logger.warning(f"从配置文件加载 ETF 列表失败: {e}")
        
        # 备用方案1：从 CSV 加载
        if use_csv:
            etf_list = self.load_etf_list_from_csv()
            if etf_list:
                logger.info(f"📊 从 CSV 文件加载 ETF 列表: {len(etf_list)} 个 ETF")
                return etf_list
        
        # 备用方案2：从 Tushare 获取（不推荐，会获取所有 ETF）
        logger.warning("⚠️ 配置文件和 CSV 都加载失败，将从 Tushare 获取所有 ETF（不推荐）")
        etf_list = self.load_etf_list_from_tushare(filter_lof=True)
        
        if not etf_list:
            logger.error("❌ 无法获取 ETF 列表")
            return []
        
        logger.info(f"📊 ETF 列表准备完成: {len(etf_list)} 个 ETF")
        return etf_list
    
    def validate_data_format(self, data: Dict[str, Any]) -> bool:
        """
        验证数据格式是否符合股票数据标准
        
        Args:
            data: 待验证的数据
            
        Returns:
            是否符合标准格式
        """
        required_fields = ['ts_code', 'symbol', 'name', 'area', 'industry', 'market']
        
        for field in required_fields:
            if field not in data:
                logger.error(f"数据格式错误：缺少字段 {field}")
                return False
        
        return True


# 全局 ETF 管理器实例
etf_manager = ETFManager()

