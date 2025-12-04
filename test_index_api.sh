#!/bin/bash

# 测试专业指数分析API

BASE_URL="http://localhost:8000"

echo "================================"
echo "测试专业指数分析API"
echo "================================"
echo ""

# 测试1: 获取三大核心指数列表
echo "📋 测试1: 获取三大核心指数列表"
echo "GET $BASE_URL/api/index/list"
echo ""
curl -s "$BASE_URL/api/index/list" | python3 -m json.tool
echo ""
echo "--------------------------------"
echo ""

# 测试2: 获取上证指数专业分析
echo "📊 测试2: 获取上证指数专业分析"
echo "GET $BASE_URL/api/index/analysis?index_code=000001.SH&days=180&theme=dark"
echo ""
curl -s "$BASE_URL/api/index/analysis?index_code=000001.SH&days=180&theme=dark" | python3 -m json.tool | head -50
echo "... (数据较多，仅显示前50行)"
echo ""
echo "--------------------------------"
echo ""

# 测试3: 获取深证成指专业分析
echo "📈 测试3: 获取深证成指专业分析"
echo "GET $BASE_URL/api/index/analysis?index_code=399001.SZ&days=180&theme=dark"
echo ""
curl -s "$BASE_URL/api/index/analysis?index_code=399001.SZ&days=180&theme=dark" | python3 -m json.tool | head -30
echo "... (数据较多，仅显示前30行)"
echo ""
echo "--------------------------------"
echo ""

# 测试4: 获取创业板指专业分析
echo "🚀 测试4: 获取创业板指专业分析"
echo "GET $BASE_URL/api/index/analysis?index_code=399006.SZ&days=180&theme=dark"
echo ""
curl -s "$BASE_URL/api/index/analysis?index_code=399006.SZ&days=180&theme=dark" | python3 -m json.tool | head -30
echo "... (数据较多，仅显示前30行)"
echo ""
echo "--------------------------------"
echo ""

# 测试5: 测试不支持的指数（应该返回错误）
echo "❌ 测试5: 测试不支持的指数（沪深300）"
echo "GET $BASE_URL/api/index/analysis?index_code=000300.SH&days=180&theme=dark"
echo ""
curl -s "$BASE_URL/api/index/analysis?index_code=000300.SH&days=180&theme=dark" | python3 -m json.tool
echo ""
echo "--------------------------------"
echo ""

echo "✅ 测试完成！"
echo ""
echo "提示："
echo "1. 确保后端服务已启动: python -m uvicorn app.main:app --reload"
echo "2. 检查Tushare Token配置是否正确"
echo "3. 确保Redis服务正常运行"

