# WebSocket快速启动指南

**5分钟快速测试WebSocket功能**

---

## 🚀 快速启动

### 1. 启动后端服务

```bash
cd /Users/hsb/Downloads/stock_project/stock_app_service

# 启动服务
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

等待看到：
```
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

---

### 2. 测试WebSocket连接

#### 方法1：使用Python测试脚本（推荐）

```bash
# 安装依赖
pip3 install websockets

# 运行测试
cd /Users/hsb/Downloads/stock_project
python3 test_websocket.py
```

**预期输出**：
```
[10:30:00] ✅ WebSocket连接成功
[10:30:00] 📨 收到连接确认:
{
  "type": "connected",
  "client_id": "client_xxx",
  "message": "WebSocket连接成功"
}

[10:30:01] 📤 发送订阅消息
[10:30:01] 📨 收到订阅确认:
{
  "type": "subscribed",
  "subscription_type": "strategy",
  "target": "volume_wave",
  "message": "订阅成功"
}

[10:30:02] 💓 发送心跳...
[10:30:02] 📨 收到心跳响应
```

#### 方法2：使用wscat（命令行工具）

```bash
# 安装wscat
npm install -g wscat

# 连接WebSocket
wscat -c ws://localhost:8000/ws/stock/prices

# 连接成功后，会收到连接确认消息
# 然后输入以下命令订阅策略：
{"type":"subscribe","subscription_type":"strategy","target":"volume_wave"}

# 发送心跳：
{"type":"ping"}
```

#### 方法3：使用浏览器（Chrome DevTools）

1. 打开Chrome浏览器
2. 按F12打开开发者工具
3. 切换到Console标签
4. 粘贴以下代码：

```javascript
// 连接WebSocket
const ws = new WebSocket('ws://localhost:8000/ws/stock/prices');

// 监听消息
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('收到消息:', data);
};

// 连接成功后订阅策略
ws.onopen = () => {
  console.log('✅ WebSocket连接成功');
  
  // 订阅策略
  ws.send(JSON.stringify({
    type: 'subscribe',
    subscription_type: 'strategy',
    target: 'volume_wave'
  }));
};

// 监听错误
ws.onerror = (error) => {
  console.error('❌ WebSocket错误:', error);
};
```

---

### 3. 查看统计信息

```bash
# 获取WebSocket统计
curl http://localhost:8000/api/websocket/stats | jq

# 获取客户端列表
curl http://localhost:8000/api/websocket/clients | jq
```

**预期输出**：
```json
{
  "code": 200,
  "message": "获取统计信息成功",
  "data": {
    "connections": {
      "total_connections": 1,
      "active_connections": 1,
      "total_subscriptions": 0,
      "messages_sent": 2,
      "messages_received": 1
    },
    "subscriptions": {
      "total_subscriptions": 1,
      "total_clients": 1,
      "total_targets": 1,
      "strategy_targets": 1,
      "stock_targets": 0,
      "market_targets": 0
    }
  }
}
```

---

### 4. 手动触发价格推送

```bash
# 手动推送价格更新
curl -X POST "http://localhost:8000/api/websocket/push/prices?strategy=volume_wave"
```

**如果有客户端订阅，客户端会立即收到价格更新消息**：
```json
{
  "type": "price_update",
  "data": [
    {
      "code": "600519",
      "name": "贵州茅台",
      "price": 1850.5,
      "change": 25.3,
      "change_percent": 2.5,
      "volume": 12345678,
      "timestamp": "2025-11-24T10:30:00"
    }
  ],
  "count": 1,
  "timestamp": "2025-11-24T10:30:00"
}
```

---

### 5. 测试自动推送（交易时间）

在交易时间（9:30-15:00），定时任务会每分钟自动推送价格更新。

**查看日志**：
```bash
# 查看实时日志
docker logs -f stock_app_api | grep -E "WebSocket|价格更新"

# 或者如果是本地运行
tail -f logs/app.log | grep -E "WebSocket|价格更新"
```

**预期日志**：
```
[INFO] 实时数据更新完成，耗时 1.23秒
[INFO] 推送策略 volume_wave 价格更新: 50个股票, 3/3个客户端
[INFO] 价格更新已推送到 3 个WebSocket客户端
```

---

## 🧪 完整测试流程

### 测试场景1：单客户端连接

```bash
# 终端1：启动服务
cd stock_app_service
uvicorn app.main:app --reload

# 终端2：运行测试
cd /Users/hsb/Downloads/stock_project
python3 test_websocket.py
```

### 测试场景2：多客户端连接

```bash
# 终端1：启动服务
cd stock_app_service
uvicorn app.main:app --reload

# 终端2：客户端1
wscat -c ws://localhost:8000/ws/stock/prices

# 终端3：客户端2
wscat -c ws://localhost:8000/ws/stock/prices

# 终端4：客户端3
wscat -c ws://localhost:8000/ws/stock/prices

# 终端5：手动触发推送
curl -X POST "http://localhost:8000/api/websocket/push/prices?strategy=volume_wave"

# 观察：所有客户端都会收到价格更新
```

### 测试场景3：断线重连

```bash
# 1. 连接WebSocket
wscat -c ws://localhost:8000/ws/stock/prices

# 2. 订阅策略
{"type":"subscribe","subscription_type":"strategy","target":"volume_wave"}

# 3. 停止服务器（Ctrl+C）
# 观察：客户端会收到断开连接的通知

# 4. 重启服务器
uvicorn app.main:app --reload

# 5. 重新连接
# 观察：客户端需要手动重连（或使用自动重连的客户端）
```

---

## 📊 性能基准测试

### 对比测试：旧API vs WebSocket

#### 旧API（同步获取+价格更新）
```bash
time curl "http://localhost:8000/api/signals/buy?strategy=volume_wave"
```
**预期耗时**: 2-3秒

#### 新API（仅获取信号）
```bash
time curl "http://localhost:8000/api/signals/buy?strategy=volume_wave"
```
**预期耗时**: 0.1-0.2秒（**10-15倍提升**）

#### WebSocket价格推送
```bash
# 连接WebSocket并订阅
# 等待价格推送
```
**推送延迟**: < 1秒（实时）

---

## 🔍 故障排查

### 问题1：无法连接WebSocket

**症状**：
```
[WebSocket] 连接失败: Connection refused
```

**解决方案**：
1. 检查服务是否启动：`curl http://localhost:8000/api/health`
2. 检查端口是否正确：`lsof -i :8000`
3. 检查防火墙设置

### 问题2：连接成功但收不到价格更新

**症状**：
```
[WebSocket] 连接成功
[WebSocket] 订阅成功
⏰ 60秒内未收到价格更新
```

**解决方案**：
1. 检查是否有信号：`curl http://localhost:8000/api/signals/buy?strategy=volume_wave`
2. 手动触发推送：`curl -X POST "http://localhost:8000/api/websocket/push/prices?strategy=volume_wave"`
3. 检查Redis缓存：确保有K线数据

### 问题3：客户端频繁断开

**症状**：
```
[WebSocket] 连接已断开
[WebSocket] 尝试重连...
```

**解决方案**：
1. 检查网络稳定性
2. 增加心跳频率
3. 检查服务器日志是否有错误

---

## 📝 API文档

### WebSocket端点

**URL**: `ws://localhost:8000/ws/stock/prices`

**协议**: WebSocket

**消息格式**: JSON

### 客户端消息

#### 订阅策略
```json
{
  "type": "subscribe",
  "subscription_type": "strategy",
  "target": "volume_wave"
}
```

#### 取消订阅
```json
{
  "type": "unsubscribe",
  "subscription_type": "strategy",
  "target": "volume_wave"
}
```

#### 心跳
```json
{
  "type": "ping"
}
```

### 服务器消息

#### 连接确认
```json
{
  "type": "connected",
  "client_id": "client_xxx",
  "message": "WebSocket连接成功",
  "timestamp": "2025-11-24T10:30:00"
}
```

#### 订阅确认
```json
{
  "type": "subscribed",
  "subscription_type": "strategy",
  "target": "volume_wave",
  "message": "订阅成功",
  "timestamp": "2025-11-24T10:30:00"
}
```

#### 价格更新
```json
{
  "type": "price_update",
  "data": [
    {
      "code": "600519",
      "name": "贵州茅台",
      "price": 1850.5,
      "change": 25.3,
      "change_percent": 2.5,
      "volume": 12345678,
      "timestamp": "2025-11-24T10:30:00"
    }
  ],
  "count": 1,
  "timestamp": "2025-11-24T10:30:00"
}
```

#### 心跳响应
```json
{
  "type": "pong",
  "timestamp": "2025-11-24T10:30:00"
}
```

#### 错误消息
```json
{
  "type": "error",
  "error": "错误描述",
  "details": "详细信息",
  "timestamp": "2025-11-24T10:30:00"
}
```

---

## 🎯 下一步

### 1. 集成到Flutter客户端
参考：`FRONTEND_WEBSOCKET_GUIDE.md`

### 2. 生产环境部署
- 配置WSS（WebSocket Secure）
- 配置Nginx反向代理
- 配置SSL证书

### 3. 监控和告警
- 监控WebSocket连接数
- 监控消息推送延迟
- 配置异常告警

---

## ✅ 检查清单

- [ ] 后端服务启动成功
- [ ] WebSocket连接测试通过
- [ ] 订阅功能测试通过
- [ ] 心跳功能测试通过
- [ ] 价格推送测试通过
- [ ] 多客户端测试通过
- [ ] 统计接口测试通过
- [ ] 日志输出正常
- [ ] 性能符合预期

---

**测试完成时间**: 5-10分钟  
**测试难度**: ⭐⭐☆☆☆（简单）  
**文档完整度**: ⭐⭐⭐⭐⭐

