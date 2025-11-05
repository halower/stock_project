# PowerShell 部署脚本 - 在 Windows 服务器上执行

$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "🚀 开始部署 Stock Intelligence API" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 检查是否在正确的目录
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "❌ 错误: 找不到 docker-compose.yml 文件" -ForegroundColor Red
    Write-Host "请在项目根目录执行此脚本" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 步骤 1/5: 停止现有容器..." -ForegroundColor Yellow
docker-compose down

Write-Host ""
Write-Host "🔨 步骤 2/5: 重新构建镜像（无缓存）..." -ForegroundColor Yellow
docker-compose build --no-cache

Write-Host ""
Write-Host "🚀 步骤 3/5: 启动容器..." -ForegroundColor Yellow
docker-compose up -d

Write-Host ""
Write-Host "⏳ 步骤 4/5: 等待容器启动（10秒）..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host ""
Write-Host "🧪 步骤 5/5: 检查容器状态..." -ForegroundColor Yellow
docker-compose ps

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "📊 查看最近的日志:" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
docker logs --tail 50 stock_app_api

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "✅ 部署完成！" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📝 后续操作:" -ForegroundColor Yellow
Write-Host "  - 查看实时日志: docker logs -f stock_app_api"
Write-Host "  - 查看容器状态: docker-compose ps"
Write-Host "  - 访问 API 文档: http://your-server:8000/docs"
Write-Host "  - 测试导入: docker exec stock_app_api python /app/quick_check.py"
Write-Host ""
Write-Host "如果遇到问题，请查看完整日志:" -ForegroundColor Yellow
Write-Host "  docker logs stock_app_api"
Write-Host ""

