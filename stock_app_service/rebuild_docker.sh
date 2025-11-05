#!/bin/bash
# Docker镜像重建脚本 - 修复CSV加载问题

echo "================================================"
echo "🔧 Docker镜像重建脚本"
echo "================================================"
echo ""

# 检查是否在正确的目录
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ 错误：请在包含docker-compose.yml的目录中运行此脚本"
    echo "当前目录: $(pwd)"
    exit 1
fi

echo "📋 步骤1: 停止并删除旧容器..."
docker compose down
echo "✅ 旧容器已停止"
echo ""

echo "📋 步骤2: 删除旧镜像..."
# 获取镜像名称
IMAGE_NAME=$(docker compose config | grep "image:" | head -1 | awk '{print $2}')
if [ -z "$IMAGE_NAME" ]; then
    # 如果没有指定image，使用项目名_服务名
    IMAGE_NAME="stock_project_stock_backend"
fi

docker rmi $IMAGE_NAME 2>/dev/null && echo "✅ 旧镜像已删除" || echo "⚠️  未找到旧镜像或已删除"
echo ""

echo "📋 步骤3: 清理Python缓存..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find . -type f -name "*.pyc" -delete 2>/dev/null
echo "✅ Python缓存已清理"
echo ""

echo "📋 步骤4: 重新构建镜像（不使用缓存）..."
docker compose build --no-cache
if [ $? -ne 0 ]; then
    echo "❌ 镜像构建失败，请检查错误信息"
    exit 1
fi
echo "✅ 镜像构建成功"
echo ""

echo "📋 步骤5: 启动服务..."
docker compose up -d
if [ $? -ne 0 ]; then
    echo "❌ 服务启动失败"
    exit 1
fi
echo "✅ 服务已启动"
echo ""

echo "📋 步骤6: 等待服务初始化（10秒）..."
sleep 10
echo ""

echo "📋 步骤7: 验证部署..."
echo ""
echo "🔍 检查ETF加载方式..."
docker compose logs api 2>/dev/null | grep -i "从配置文件获取到.*ETF" | tail -1
docker compose logs api 2>/dev/null | grep -i "从 CSV 读取到.*ETF" | tail -1

echo ""
echo "🔍 检查容器状态..."
docker compose ps
echo ""

echo "================================================"
echo "✅ 重建完成！"
echo "================================================"
echo ""
echo "📝 后续步骤："
echo "1. 查看实时日志: docker compose logs -f api"
echo "2. 检查ETF数量: docker exec -it stock_app_redis redis-cli HLEN stock_list"
echo "3. 测试API: curl http://localhost:8000/api/stocks/status"
echo ""
echo "⚠️  如果仍显示 '从 CSV 读取'，请运行以下命令彻底清理："
echo "   docker compose down --rmi all --volumes"
echo "   docker system prune -a"
echo "   然后重新运行本脚本"
echo ""

