#!/usr/bin/env python3
"""
PICC股票分析系统启动脚本 - 简化版
使用APScheduler替代Celery，减少复杂性
"""

import sys
import os
import argparse
import time
import threading
import subprocess
from datetime import datetime

# 添加项目根目录到Python路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def check_redis_connection():
    """检查Redis连接"""
    try:
        from app.db.session import RedisCache
        redis_cache = RedisCache()
        redis_cache.get_redis_client().ping()
        print("Redis连接正常")
        return True
    except Exception as e:
        print(f"Redis连接失败: {str(e)}")
        print("请确保Redis服务正在运行")
        return False

def check_dependencies():
    """检查必要的依赖"""
    required_packages = [
        ('fastapi', 'fastapi'),
        ('uvicorn', 'uvicorn'),
        ('redis', 'redis'),
        ('apscheduler', 'apscheduler'),
        ('requests', 'requests'),
        ('bs4', 'beautifulsoup4')  # beautifulsoup4的import名称是bs4
    ]
    
    missing_packages = []
    for import_name, package_name in required_packages:
        try:
            __import__(import_name)
            print(f"{package_name} 已安装")
        except ImportError:
            missing_packages.append(package_name)
            print(f"{package_name} 未安装")
    
    if missing_packages:
        print(f"\n缺少依赖包: {', '.join(missing_packages)}")
        print("请运行: pip install " + " ".join(missing_packages))
        return False
    else:
        print("\n所有依赖包检查通过")
        return True

def start_fastapi_server(port=8001, trigger_news=False):
    """启动FastAPI服务"""
    print(f"启动FastAPI服务 (端口: {port})...")
    
    # 设置环境变量
    os.environ['PYTHONPATH'] = os.path.dirname(os.path.abspath(__file__))
    
    if trigger_news:
        print("启动时将立即触发新闻爬取...")
    
    try:
        import uvicorn
        
        # 获取CPU核心数，用于设置工作进程数
        import multiprocessing
        workers_count = min(multiprocessing.cpu_count() + 1, 8)  # 工作进程数，最多8个
        
        print(f"启动 {workers_count} 个工作进程以支持并发请求...")
        
        uvicorn.run(
            "app.main:app",
            host="0.0.0.0",
            port=port,
            reload=False,
            log_level="info",
            access_log=True,
            workers=workers_count  # 使用多个工作进程
        )
    except Exception as e:
        print(f"启动FastAPI服务失败: {str(e)}")
        return False

def trigger_initial_news_crawl():
    """触发首次新闻爬取"""
    try:
        import requests
        import time
        
        # 等待服务启动
        print("⏳ 等待服务启动...")
        time.sleep(3)
        
        # 触发新闻爬取
        print("触发首次新闻爬取...")
        response = requests.post("/api/news/scheduler/trigger")
        
        if response.status_code == 200:
            print("首次新闻爬取触发成功")
        else:
            print(f"触发新闻爬取失败: {response.status_code}")
    
    except Exception as e:
        print(f"触发首次新闻爬取异常: {str(e)}")

def print_banner():
    """打印启动横幅"""
    print("""
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║  智能股票分析系统 - 简化版                        ║
    ║                                                              ║
    ║  特性：                                                    ║
    ║  • APScheduler轻量级调度器                                    ║
    ║  • 启动时自动执行新闻爬取                                      ║
    ║  • 每2小时自动更新财经新闻                                     ║
    ╚══════════════════════════════════════════════════════════════╝
    """)

def print_service_info(port=8001):
    """打印服务信息"""
    print(f"""
    🌐 服务地址:
    • API服务: http://localhost:{port}
    • 交互式文档: http://localhost:{port}/docs-cn (推荐)
    • Swagger UI: http://localhost:{port}/docs
    • ReDoc文档: http://localhost:{port}/redoc
    
    核心接口:
    • 最新新闻: GET /api/news/latest
    • 调度器状态: GET /api/news/scheduler/status
    • 手动触发: POST /api/news/scheduler/trigger
    • 消息面分析: POST /api/news/analysis
    
    使用说明:
    1. 访问交互式文档进行API测试
    2. 使用 /api/auth/login 获取令牌
    3. 新闻数据会在启动时自动爬取一次
    4. 之后每2小时自动更新
    """)

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="PICC股票分析系统启动脚本")
    parser.add_argument("--port", type=int, default=8001, help="API服务端口 (默认: 8001)")
    parser.add_argument("--trigger-news", action="store_true", help="启动后立即触发新闻爬取")
    parser.add_argument("--skip-checks", action="store_true", help="跳过依赖检查")
    
    args = parser.parse_args()
    
    print_banner()
    
    # 检查依赖
    if not args.skip_checks:
        if not check_dependencies():
            sys.exit(1)
        
        if not check_redis_connection():
            sys.exit(1)
    
    # 打印服务信息
    print_service_info(args.port)
    
    # 如果需要触发新闻爬取，在后台线程中执行
    if args.trigger_news:
        threading.Thread(target=trigger_initial_news_crawl, daemon=True).start()
    
    # 启动FastAPI服务
    print(f"正在启动服务...")
    print(f"⏰ 启动时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("新闻调度器将在应用启动时自动运行")
    print("=" * 60)
    
    try:
        start_fastapi_server(port=args.port, trigger_news=args.trigger_news)
    except KeyboardInterrupt:
        print("\n收到中断信号，正在关闭服务...")
        print("感谢使用PICC股票分析系统！")
    except Exception as e:
        print(f"启动失败: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()

# 简化后的启动说明：
# 
# 一键启动:
# python run.py
# 
# 自定义端口:
# python run.py --port 8002
# 
# 启动后立即触发新闻爬取:
# python run.py --trigger-news
# 
# 跳过检查快速启动:
# python run.py --skip-checks
# 
# 服务地址:
# http://localhost:8001/docs-cn (交互式文档)
# http://localhost:8001/api/news/latest (最新新闻)
# http://localhost:8001/api/news/scheduler/status (调度器状态) 