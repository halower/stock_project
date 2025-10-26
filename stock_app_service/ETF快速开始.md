# ETF实时行情 - 快速开始指南

## 🚀 5分钟快速上手

### 步骤1: 查看ETF列表
```bash
# 查看精选的51只ETF
cat app/etf/ETF列表.csv | head -20
```

**输出示例**：
```
ts_code,symbol,name,area,industry,market,list_date
510050.SH,510050,上证50ETF,,T+1交易,ETF,20050223
512100.SH,512100,中证1000ETF,,T+1交易,ETF,20161104
159949.SZ,159949,创业板50ETF,,T+1交易,ETF,20160722
512480.SH,512480,半导体ETF,,T+1交易,ETF,20190612
515030.SH,515030,新能源车ETF,,T+1交易,ETF,20200304
...
```

### 步骤2: 初始化历史数据（首次使用）
```bash
curl -X POST "http://101.200.47.169:8000/api/etf/init" \
  -H "Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"
```

**响应**：
```json
{
  "success": true,
  "message": "ETF历史数据初始化任务已触发",
  "task_type": "init_etf"
}
```

**预计耗时**: 5-10分钟（51只ETF，每只约1年历史数据）

### 步骤3: 手动更新实时数据
```bash
curl -X POST "http://101.200.47.169:8000/api/etf/update" \
  -H "Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"
```

**响应**：
```json
{
  "success": true,
  "message": "ETF实时数据更新任务已触发",
  "task_type": "update_etf"
}
```

### 步骤4: 查看更新日志
```bash
tail -f logs/app.log | grep ETF
```

**日志示例**：
```
2025-10-26 14:30:00 - INFO - 🎯 开始更新ETF实时数据...
2025-10-26 14:30:00 - INFO - 📋 读取ETF列表: 51 只
2025-10-26 14:30:03 - INFO - ✅ 成功从 eastmoney 获取 51 只ETF实时数据
2025-10-26 14:30:04 - INFO - 🎉 ETF实时数据更新完成: 51只，K线更新: 51只，耗时 4.12秒
```

## 📊 常用API

### 1. 获取ETF配置
```bash
curl "http://101.200.47.169:8000/api/etf/config"
```

### 2. 修改更新频率（改为30分钟）
```bash
# 注意：这个修改的是运行时配置，重启后会恢复默认值
# 要永久修改，请编辑 docker-compose.yml 中的 ETF_UPDATE_INTERVAL
curl -X PUT "http://101.200.47.169:8000/api/etf/config" \
  -H "Content-Type: application/json" \
  -d '{
    "default_provider": "eastmoney"
  }'
```

### 3. 查看统计信息
```bash
curl "http://101.200.47.169:8000/api/etf/stats"
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "eastmoney": {
      "success": 24,
      "fail": 0,
      "last_success_time": "2025-10-26 15:30:00"
    },
    "sina": {
      "success": 1,
      "fail": 0,
      "last_success_time": "2025-10-26 10:00:00"
    },
    "total_requests": 25,
    "auto_switches": 1
  }
}
```

### 4. 测试数据源
```bash
# 测试东方财富
curl "http://101.200.47.169:8000/api/etf/test/eastmoney"

# 测试新浪财经
curl "http://101.200.47.169:8000/api/etf/test/sina"
```

## ⚙️ 配置说明

### 修改更新频率

编辑 `docker-compose.yml`：
```yaml
environment:
  # ETF实时行情配置
  - ETF_REALTIME_PROVIDER=eastmoney  # 数据源
  - ETF_UPDATE_INTERVAL=60           # 改为30分钟
  - ETF_AUTO_SWITCH=true             # 自动切换
```

重启服务：
```bash
docker-compose restart api
```

### 切换数据源

**临时切换**（运行时）：
```bash
curl -X PUT "http://101.200.47.169:8000/api/etf/config" \
  -H "Content-Type: application/json" \
  -d '{"default_provider": "sina"}'
```

**永久切换**（配置文件）：
```yaml
# docker-compose.yml
- ETF_REALTIME_PROVIDER=sina  # 改为新浪
```

## 🔍 数据查询

### 查看Redis中的ETF数据

#### 1. 连接Redis
```bash
docker exec -it stock_app_redis redis-cli
```

#### 2. 查看ETF代码列表
```bash
GET etf:codes:all
```

#### 3. 查看实时数据
```bash
GET etf:realtime
```

#### 4. 查看某只ETF的K线
```bash
# 上证50ETF
GET etf_trend:510050.SH

# 创业板50ETF
GET etf_trend:159949.SZ
```

## 📈 自动更新机制

### 定时任务
服务启动后会自动启动定时任务：

```
ETF实时更新: 每60分钟（交易时间内）
├─ 9:30-11:30  上午交易时段
├─ 13:00-15:00 下午交易时段
└─ 15:00-15:30 收盘后数据窗口
```

### 查看调度器状态
```bash
curl "http://101.200.47.169:8000/api/stocks/scheduler/status" \
  -H "Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"
```

**查找ETF任务**：
```json
{
  "jobs": [
    {
      "id": "etf_realtime_update",
      "name": "ETF实时数据更新（非阻塞）",
      "next_run": "2025-10-26 15:30:00"
    }
  ]
}
```

## 🛠️ 故障排查

### 问题1: K线更新为0

**症状**：
```
ETF实时数据更新完成: 51只，K线更新: 0只
```

**原因**: 没有初始化历史数据

**解决**:
```bash
curl -X POST "http://101.200.47.169:8000/api/etf/init" \
  -H "Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"
```

### 问题2: 数据源失败

**症状**：
```
ETF实时数据更新失败: 所有数据源均失败
```

**诊断步骤**：

1. 测试各数据源：
```bash
curl "http://101.200.47.169:8000/api/etf/test/eastmoney"
curl "http://101.200.47.169:8000/api/etf/test/sina"
```

2. 查看统计信息：
```bash
curl "http://101.200.47.169:8000/api/etf/stats"
```

3. 切换到备用源：
```bash
curl -X PUT "http://101.200.47.169:8000/api/etf/config" \
  -H "Content-Type: application/json" \
  -d '{"default_provider": "sina"}'
```

### 问题3: 更新太慢

**优化建议**：

1. 增加请求间隔（防止被限流）：
```bash
curl -X PUT "http://101.200.47.169:8000/api/etf/config" \
  -H "Content-Type: application/json" \
  -d '{"min_request_interval": 5.0}'
```

2. 减少重试次数：
```bash
curl -X PUT "http://101.200.47.169:8000/api/etf/config" \
  -H "Content-Type: application/json" \
  -d '{"retry_times": 1}'
```

## 📊 ETF列表说明

### 分类统计
```
总数: 51只（从1220只精选）
├─ 宽基指数: 10只（上证50、沪深300、中证500等）
├─ 科技: 7只（半导体、AI、5G、软件等）
├─ 新能源: 4只（光伏、新能源车、锂电池）
├─ 高端制造: 4只（军工、机器人、航空航天）
├─ 消费: 4只（白酒、食品、家电）
├─ 金融: 3只（证券、银行）
├─ 港股: 4只（恒生、港股科技、港股红利）
├─ 周期: 5只（有色、钢铁、煤炭、化工）
├─ 能源: 2只（油气、电力）
├─ 医药: 2只（医药综合、医疗器械）
├─ 策略: 3只（红利、红利低波、ESG）
└─ 主题: 3只（央企、国企、一带一路）
```

### 核心推荐（宽基指数）
```
510050  上证50ETF      - 大盘蓝筹
159912  深300ETF       - 沪深300
159922  中证500ETF     - 中盘成长
512100  中证1000ETF    - 小盘成长
159949  创业板50ETF    - 科创龙头
```

### 热门主题
```
512480  半导体ETF      - 芯片产业
512930  AI人工智能ETF  - 人工智能
515790  光伏ETF        - 光伏产业
515030  新能源车ETF    - 新能源汽车
512690  酒ETF          - 白酒
```

## 🎯 下一步

### 1. 查看完整文档
```bash
cat ETF实时行情功能说明.md
```

### 2. 查看ETF精选说明
```bash
cat app/etf/ETF精选说明.md
```

### 3. 监控服务运行
```bash
# 查看日志
tail -f logs/app.log | grep -E "ETF|etf"

# 查看统计
watch -n 60 'curl -s "http://101.200.47.169:8000/api/etf/stats" | jq'
```

### 4. 集成到客户端
- ETF列表显示
- 实时价格更新
- K线图表展示
- 策略信号（待开发）

## 💡 使用建议

### 1. 更新频率
```
推荐: 60分钟（默认）
理由:
├─ ETF波动相对平缓，无需频繁更新
├─ 避免过度请求被封IP
└─ 节省服务器资源
```

### 2. 数据源选择
```
推荐: auto（自动选择）
理由:
├─ 优先使用东方财富（数据全面）
├─ 失败时自动切换到新浪（稳定性好）
└─ 无需人工干预
```

### 3. 监控重点
```
定期检查:
├─ 统计信息（成功率、失败次数）
├─ 更新日志（是否正常更新）
├─ K线数据（是否完整）
└─ 自动切换次数（是否频繁）
```

## 📞 获取帮助

### 相关文档
- `ETF实时行情功能说明.md` - 完整功能说明
- `ETF精选说明.md` - ETF筛选标准
- `防封策略说明.md` - 防封策略详解

### API文档
访问: http://101.200.47.169:8000/docs

搜索: "ETF" 查看所有ETF相关接口

---

**版本**: v1.0.0  
**更新时间**: 2025-10-26  
**适用场景**: 首次使用、快速上手

