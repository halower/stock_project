#!/bin/bash

echo "=========================================="
echo "完全重建容器并测试修复"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 步骤1: 停止并删除容器
echo -e "${YELLOW}步骤1: 停止并删除现有容器...${NC}"
if docker compose version &> /dev/null; then
    docker compose down
elif command -v docker-compose &> /dev/null; then
    docker-compose down
else
    echo -e "${RED}错误: Docker Compose不可用${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 容器已停止并删除${NC}"
echo ""

# 步骤2: 重新构建并启动
echo -e "${YELLOW}步骤2: 重新构建并启动容器...${NC}"
if docker compose version &> /dev/null; then
    docker compose up -d --build
elif command -v docker-compose &> /dev/null; then
    docker-compose up -d --build
fi
echo -e "${GREEN}✅ 容器重建完成${NC}"
echo ""

# 步骤3: 等待服务启动
echo -e "${YELLOW}步骤3: 等待服务启动（20秒）...${NC}"
for i in {20..1}; do
    printf "\r等待: %2d秒" $i
    sleep 1
done
echo ""
echo -e "${GREEN}✅ 等待完成${NC}"
echo ""

# 步骤4: 检查容器状态
echo -e "${YELLOW}步骤4: 检查容器状态...${NC}"
if docker compose version &> /dev/null; then
    docker compose ps
elif command -v docker-compose &> /dev/null; then
    docker-compose ps
fi
echo ""

# 步骤5: 测试服务
echo -e "${YELLOW}步骤5: 测试服务响应...${NC}"
response=$(curl -s http://localhost:8000/ping 2>&1)
if [[ $response == *"pong"* ]]; then
    echo -e "${GREEN}✅ 服务运行正常${NC}"
else
    echo -e "${RED}❌ 服务未响应${NC}"
    echo "响应: $response"
    exit 1
fi
echo ""

# 步骤6: 测试图表生成
echo -e "${YELLOW}步骤6: 测试图表生成...${NC}"
API_TOKEN="eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"

echo "测试端点: /api/chart/688027"
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -H "X-API-Token: ${API_TOKEN}" \
    "http://localhost:8000/api/chart/688027?strategy=volume_wave")

http_code=$(echo "$response" | grep "HTTP_CODE" | cut -d':' -f2)
body=$(echo "$response" | sed '/HTTP_CODE/d')

echo "HTTP状态码: $http_code"

if [[ $http_code == "200" ]] || [[ $http_code == "302" ]]; then
    echo -e "${GREEN}✅ 图表生成成功！${NC}"
    echo "响应预览:"
    echo "$body" | head -c 200
elif [[ $body == *"attached to a different loop"* ]]; then
    echo -e "${RED}❌ 仍然存在事件循环错误！${NC}"
    echo ""
    echo "详细响应:"
    echo "$body"
    echo ""
    echo "查看日志:"
    if docker compose version &> /dev/null; then
        docker compose logs api --tail=50
    elif command -v docker-compose &> /dev/null; then
        docker-compose logs api --tail=50
    fi
else
    echo -e "${YELLOW}⚠️ 返回其他错误${NC}"
    echo "详细响应:"
    echo "$body"
fi
echo ""

# 步骤7: 查看日志确认使用同步Redis
echo -e "${YELLOW}步骤7: 检查日志（确认使用同步Redis）...${NC}"
echo ""
if docker compose version &> /dev/null; then
    docker compose logs api --tail=30 | grep -E "同步Redis|图表|ERROR"
elif command -v docker-compose &> /dev/null; then
    docker-compose logs api --tail=30 | grep -E "同步Redis|图表|ERROR"
fi
echo ""

echo "=========================================="
echo "测试完成"
echo "=========================================="
echo ""
echo "如果仍有问题，请查看完整日志:"
echo "  docker compose logs api > full_log.txt"

