#!/bin/bash
# 部署脚本 - 在服务器上执行

set -e  # 遇到错误立即退出

echo "=================================================="
echo "🚀 开始部署 Stock Intelligence API"
echo "=================================================="

# 检查是否在正确的目录
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ 错误: 找不到 docker-compose.yml 文件"
    echo "请在项目根目录执行此脚本"
    exit 1
fi

echo ""
echo "📋 步骤 1/5: 停止现有容器..."
docker-compose down

echo ""
echo "🔨 步骤 2/5: 重新构建镜像（无缓存）..."
docker-compose build --no-cache

echo ""
echo "🚀 步骤 3/5: 启动容器..."
docker-compose up -d

echo ""
echo "⏳ 步骤 4/5: 等待容器启动（10秒）..."
sleep 10

echo ""
echo "🧪 步骤 5/5: 检查容器状态..."
docker-compose ps

echo ""
echo "=================================================="
echo "📊 查看最近的日志:"
echo "=================================================="
docker logs --tail 50 stock_app_api

echo ""
echo "=================================================="
echo "✅ 部署完成！"
echo "=================================================="
echo ""
echo "📝 后续操作:"
echo "  - 查看实时日志: docker logs -f stock_app_api"
echo "  - 查看容器状态: docker-compose ps"
echo "  - 访问 API 文档: http://your-server:8000/docs"
echo "  - 测试导入: docker exec stock_app_api python /app/quick_check.py"
echo ""
echo "如果遇到问题，请查看完整日志:"
echo "  docker logs stock_app_api"
echo ""

