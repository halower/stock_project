# -*- coding: utf-8 -*-
"""PostgreSQL分区表管理"""

from sqlalchemy.sql import text
from app.core.logging import logger
from app.db.session import engine

def initialize_partition_tables():
    """创建PostgreSQL分区表"""
    with engine.connect() as conn:
        try:
            # 先检查父表是否存在
            result = conn.execute(text("SELECT to_regclass('public.stock_history')"))
            table_exists = result.scalar()
            
            if not table_exists:
                # 父表不存在,可能模型还没有创建,暂时跳过
                return
                
            # 检查是否已经创建了分区表
            result = conn.execute(text("SELECT COUNT(*) FROM pg_class WHERE relname = 'stock_history_main_index'"))
            if result.scalar() == 0:
                # 创建主要指数分区表(使用IN列表而不是子查询)
                conn.execute(text("""
                CREATE TABLE IF NOT EXISTS stock_history_main_index 
                PARTITION OF stock_history
                FOR VALUES IN ('399001', '000300', '000905', '000016')
                """))

                # 按代码范围创建分区(不使用子查询)
                # 0开头的股票(不包含已在main_index中的股票)
                conn.execute(text("""
                CREATE TABLE IF NOT EXISTS stock_history_0
                PARTITION OF stock_history
                FOR VALUES IN ('000002', '000003', '000004', '000005', '000006', '000007', '000008', '000009', '000010')
                """))
                
                # 为了简化代码,我们创建少量分区捕获主要股票
                # 000001单独创建一个分区
                conn.execute(text("""
                CREATE TABLE IF NOT EXISTS stock_history_000001
                PARTITION OF stock_history
                FOR VALUES IN ('000001')
                """))
                
                # 3开头的股票
                conn.execute(text("""
                CREATE TABLE IF NOT EXISTS stock_history_3
                PARTITION OF stock_history
                FOR VALUES IN ('300001', '300002', '300003', '300004', '300005', '300006', '300007', '300008', '300009', '300010')
                """))

                # 6开头的股票
                conn.execute(text("""
                CREATE TABLE IF NOT EXISTS stock_history_6
                PARTITION OF stock_history
                FOR VALUES IN ('600001', '600002', '600003', '600004', '600005', '600006', '600007', '600008', '600009', '600010')
                """))

                # 默认分区,捕获所有其他股票
                conn.execute(text("""
                CREATE TABLE IF NOT EXISTS stock_history_default
                PARTITION OF stock_history DEFAULT
                """))
                
                conn.commit()
                
            # 创建实际的分区(按提供的股票代码动态创建)
            # 这部分在添加股票数据后执行
                
        except Exception as e:
            # 记录错误但不中断应用启动
            logger.error(f"分区表初始化错误: {e}")
            conn.rollback()

def update_partition_tables(stock_codes):
    """根据实际股票代码更新分区表"""
    with engine.connect() as conn:
        try:
            # 按组处理股票代码
            # 首先分类股票代码
            codes_by_prefix = {}
            main_indices = ['000001', '399001', '000300', '000905', '000016']
            
            for code in stock_codes:
                if code in main_indices:
                    continue  # 跳过主要指数,它们已有专门分区
                
                prefix = code[0]
                if prefix not in codes_by_prefix:
                    codes_by_prefix[prefix] = []
                
                codes_by_prefix[prefix].append(code)
            
            # 为每组创建或更新分区
            for prefix, codes in codes_by_prefix.items():
                if len(codes) == 0:
                    continue
                    
                # 检查该前缀的分区是否存在
                result = conn.execute(text(f"SELECT COUNT(*) FROM pg_class WHERE relname = 'stock_history_{prefix}'"))
                if result.scalar() == 0:
                    # 创建新分区,每次最多包含500个代码(避免SQL过长)
                    for i in range(0, len(codes), 500):
                        batch = codes[i:i+500]
                        values = "'" + "', '".join(batch) + "'"
                        
                        # 创建分区
                        partition_name = f"stock_history_{prefix}{i//500}"
                        stmt = f"""
                        CREATE TABLE IF NOT EXISTS {partition_name}
                        PARTITION OF stock_history
                        FOR VALUES IN ({values})
                        """
                        conn.execute(text(stmt))
            
            conn.commit()
        except Exception as e:
            logger.error(f"更新分区表错误: {e}")
            conn.rollback() 