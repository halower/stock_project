# -*- coding: utf-8 -*-
"""日志配置"""

import logging
import os
from logging.handlers import RotatingFileHandler, TimedRotatingFileHandler
from typing import Optional
from datetime import datetime

def setup_logging(level: Optional[int] = None) -> logging.Logger:
    """
    设置应用程序日志（带自动轮转和清理）
    
    Args:
        level: 日志级别，默认为INFO
    
    Returns:
        配置好的logger对象
    """
    if level is None:
        level = logging.INFO
    
    # 获取应用日志记录器
    logger = logging.getLogger("stock_app")
    
    # 如果已经配置过，直接返回（避免多进程重复配置）
    if logger.handlers:
        return logger
        
    # 确保日志目录存在
    log_dir = "logs"
    os.makedirs(log_dir, exist_ok=True)
    
    # 创建formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # 设置logger级别（不设置根logger，避免影响其他库）
    logger.setLevel(level)
    logger.propagate = False  # 不传播到根logger，避免重复日志
    
    # 1. 控制台输出（保留）
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(level)
    
    # 2. 文件输出 - 按大小轮转（主日志）
    file_handler = RotatingFileHandler(
        filename=os.path.join(log_dir, 'app.log'),
        maxBytes=50 * 1024 * 1024,  # 50MB
        backupCount=5,  # 保留5个备份文件
        encoding='utf-8'
    )
    file_handler.setFormatter(formatter)
    file_handler.setLevel(level)
    
    # 3. 错误日志 - 按天轮转
    error_handler = TimedRotatingFileHandler(
        filename=os.path.join(log_dir, 'error.log'),
        when='midnight',
        interval=1,
        backupCount=30,  # 保留30天
        encoding='utf-8'
    )
    error_handler.setFormatter(formatter)
    error_handler.setLevel(logging.ERROR)
    
    # 4. 系统维护日志 - 按周轮转
    system_handler = TimedRotatingFileHandler(
        filename=os.path.join(log_dir, 'system.log'),
        when='W0',  # 每周一轮转
        interval=1,
        backupCount=12,  # 保留12周
        encoding='utf-8'
    )
    system_handler.setFormatter(formatter)
    system_handler.addFilter(SystemLogFilter())
    
    # 添加所有handlers到应用logger（不是根logger）
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    logger.addHandler(error_handler)
    logger.addHandler(system_handler)
    
    # 记录日志系统启动信息（只记录一次）
    logger.info("日志系统启动 - 自动轮转和清理已启用")
    logger.info(f"📁 日志目录: {os.path.abspath(log_dir)}")
    logger.info("轮转策略: 主日志50MB轮转，错误日志按天轮转，系统日志按周轮转")
    logger.info("清理策略: 主日志保留5份，错误日志保留30天，系统日志保留12周")
    
    return logger

class SystemLogFilter(logging.Filter):
    """系统维护相关日志过滤器"""
    
    def filter(self, record):
        # 过滤系统维护相关的日志
        system_keywords = [
            '时间同步', '健康检查', '数据质量', '自动清理', 
            '系统检查', '定时任务', '调度器', '备份'
        ]
        
        message = record.getMessage()
        return any(keyword in message for keyword in system_keywords)

def cleanup_old_log_files():
    """手动清理过期日志文件"""
    try:
        log_dir = "logs"
        if not os.path.exists(log_dir):
            logger.info("日志目录不存在，跳过清理")
            return
        
        import glob
        from datetime import datetime, timedelta
        
        # 清理30天前的日志文件
        cutoff_date = datetime.now() - timedelta(days=30)
        
        # 获取所有日志文件
        log_files = glob.glob(os.path.join(log_dir, "*.log*"))
        deleted_count = 0
        total_size_freed = 0
        
        for log_file in log_files:
            try:
                # 检查文件修改时间
                file_mtime = datetime.fromtimestamp(os.path.getmtime(log_file))
                
                if file_mtime < cutoff_date:
                    file_size = os.path.getsize(log_file)
                    os.remove(log_file)
                    deleted_count += 1
                    total_size_freed += file_size
                    logger.debug(f"删除过期日志文件: {os.path.basename(log_file)}")
                    
            except Exception as e:
                logger.error(f"删除日志文件失败 {log_file}: {e}")
        
        if deleted_count > 0:
            size_mb = total_size_freed / (1024 * 1024)
            logger.info(f"日志清理完成: 删除 {deleted_count} 个文件，释放 {size_mb:.2f}MB 空间")
        else:
            logger.debug("日志清理: 无需清理的过期文件")
            
    except Exception as e:
        logger.error(f"日志清理失败: {e}")

def get_log_disk_usage():
    """获取日志目录磁盘使用情况"""
    try:
        log_dir = "logs"
        if not os.path.exists(log_dir):
            return {"total_size": 0, "file_count": 0}
        
        import glob
        
        log_files = glob.glob(os.path.join(log_dir, "*"))
        total_size = 0
        file_count = 0
        
        for log_file in log_files:
            if os.path.isfile(log_file):
                total_size += os.path.getsize(log_file)
                file_count += 1
        
        return {
            "total_size": total_size,
            "total_size_mb": round(total_size / (1024 * 1024), 2),
            "file_count": file_count,
            "log_dir": os.path.abspath(log_dir)
        }
        
    except Exception as e:
        logger.error(f"获取日志磁盘使用情况失败: {e}")
        return {"error": str(e)}

# 创建应用程序默认日志记录器
logger = setup_logging() 