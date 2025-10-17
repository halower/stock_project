# -*- coding: utf-8 -*-
"""数据库初始化"""

import os
import logging
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session

from app.db.base_class import Base
from app.db.session import engine

logger = logging.getLogger("stock_app")

def init_db(db: Session = None) -> None:
    """初始化数据库，创建必要的表"""
    reset_tables = os.environ.get("RESET_TABLES", "false").lower() == "true"
    
    if reset_tables:
        logger.warning("重置表标志已设置，将删除并重新创建所有表")
        try:
            Base.metadata.drop_all(bind=engine)
            logger.info("所有表已成功删除")
        except Exception as e:
            logger.error(f"删除表时出错: {str(e)}")
    
    try:
        # 创建所有表
        # Import all the models here to ensure they are registered with Base
        from app.models.stock import StockInfo, StockHistory, StockSignal
        
        logger.info("开始创建数据库表...")
        Base.metadata.create_all(bind=engine)
        logger.info("数据库表创建完成")
    except Exception as e:
        logger.error(f"创建表时出错: {str(e)}")

    logger.info("数据库初始化完成") 