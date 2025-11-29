# WebSocket实时推送 - 快速实施指南

## 🎯 核心改进

### 问题
- ❌ 每次加载信号列表都要查询价格（1-2秒）
- ❌ 需要手动刷新才能看到最新价格
- ❌ 服务器重复查询Redis（浪费资源）

### 解决方案
- ✅ 信号列表只加载一次（0.1-0.2秒）
- ✅ 价格通过WebSocket实时推送（秒级更新）
- ✅ 服务器主动推送，无需查询

---

## 📋 实施步骤

### 阶段1: 最小可行方案（MVP）

#### 后端（1天）

**1. 安装依赖**

```bash
# 已包含在FastAPI中，无需额外安装
```

**2. 创建WebSocket端点**

创建文件：`app/api/websocket.py`

```python
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict
import json
from datetime import datetime
from app.core.logging import logger

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
    
    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active_connections[client_id] = websocket
        logger.info(f"WebSocket连接: {client_id}, 总连接数: {len(self.active_connections)}")
    
    def disconnect(self, client_id: str):
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            logger.info(f"WebSocket断开: {client_id}, 剩余连接数: {len(self.active_connections)}")
    
    async def broadcast(self, message: dict):
        """广播消息到所有连接"""
        disconnected = []
        for client_id, websocket in self.active_connections.items():
            try:
                await websocket.send_json(message)
            except Exception as e:
                logger.error(f"发送失败: {client_id}, {e}")
                disconnected.append(client_id)
        
        for client_id in disconnected:
            self.disconnect(client_id)

manager = ConnectionManager()

@router.websocket("/ws/stock/prices")
async def websocket_endpoint(websocket: WebSocket):
    client_id = f"client_{id(websocket)}"
    
    try:
        await manager.connect(websocket, client_id)
        
        # 发送欢迎消息
        await websocket.send_json({
            "type": "connected",
            "message": "WebSocket连接成功"
        })
        
        # 保持连接
        while True:
            data = await websocket.receive_json()
            
            if data.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
    
    except WebSocketDisconnect:
        manager.disconnect(client_id)
    except Exception as e:
        logger.error(f"WebSocket错误: {e}")
        manager.disconnect(client_id)
```

**3. 注册路由**

修改：`app/main.py`

```python
# 添加导入
from app.api import websocket

# 注册路由
app.include_router(websocket.router, tags=["WebSocket"])
```

**4. 修改定时任务推送价格**

修改：`app/services/scheduler/stock_scheduler.py`

```python
@staticmethod
def job_realtime_update():
    """定时任务：实时更新所有股票数据"""
    if not is_trading_time():
        return
    
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # 1. 更新数据
            result = loop.run_until_complete(
                stock_atomic_service.realtime_update_all_stocks()
            )
            
            # 2. 获取价格更新
            updates = loop.run_until_complete(_get_price_updates())
            
            # 3. 推送到WebSocket
            if updates:
                from app.api.websocket import manager
                loop.run_until_complete(
                    manager.broadcast({
                        "type": "price_update",
                        "data": updates,
                        "timestamp": datetime.now().isoformat()
                    })
                )
                logger.info(f"已推送 {len(updates)} 个价格更新")
        
        finally:
            loop.close()
    
    except Exception as e:
        logger.error(f"实时更新失败: {e}")


async def _get_price_updates():
    """获取价格更新数据"""
    from app.services.signal.signal_manager import signal_manager
    from app.db.session import RedisCache
    
    redis_cache = RedisCache()
    signals = await signal_manager.get_buy_signals()
    
    updates = []
    for signal in signals:
        code = signal.get('code')
        ts_code = signal.get('ts_code')
        
        if not ts_code:
            continue
        
        # 从Redis获取最新价格
        cache_key = f"stock_trend:{ts_code}"
        cached_data = redis_cache.get_cache(cache_key)
        
        if not cached_data:
            continue
        
        kline_data = cached_data.get('data', []) if isinstance(cached_data, dict) else cached_data
        
        if not kline_data:
            continue
        
        latest = kline_data[-1]
        close_price = float(latest.get('close', 0))
        pre_close = float(latest.get('pre_close', 0))
        
        if close_price > 0 and pre_close > 0:
            change_pct = (close_price - pre_close) / pre_close * 100
            
            updates.append({
                "code": code,
                "name": signal.get('name'),
                "price": close_price,
                "change_percent": round(change_pct, 2),
                "volume": float(latest.get('vol', 0)) * 100
            })
    
    return updates
```

**5. 修改信号API（移除价格更新）**

修改：`app/api/signal_management.py`

```python
@router.get("/api/stocks/signal/buy")
async def get_buy_signals(strategy: Optional[str] = Query(None)):
    """获取买入信号（价格通过WebSocket推送）"""
    try:
        signals = await signal_manager.get_buy_signals(strategy=strategy)
        
        # ❌ 移除这行（不再更新价格）
        # await _update_signals_with_latest_price(signals)
        
        return {
            "code": 200,
            "message": "获取买入信号成功",
            "data": {
                "strategy": strategy,
                "signals": signals,
                "count": len(signals)
            }
        }
    except Exception as e:
        logger.error(f"获取买入信号失败: {str(e)}")
        return {"code": 500, "message": str(e)}
```

---

#### 前端（1天）

**1. 添加依赖**

修改：`pubspec.yaml`

```yaml
dependencies:
  web_socket_channel: ^2.4.0
```

运行：
```bash
flutter pub get
```

**2. 创建WebSocket服务**

创建文件：`lib/services/websocket_service.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();
  
  WebSocketChannel? _channel;
  bool _isConnected = false;
  
  // 价格更新回调
  Function(List<Map<String, dynamic>>)? onPriceUpdate;
  
  Future<void> connect() async {
    if (_isConnected) return;
    
    try {
      final wsUrl = 'ws://localhost:8000/ws/stock/prices';
      debugPrint('连接WebSocket: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket错误: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('WebSocket关闭');
          _isConnected = false;
        },
      );
      
      _isConnected = true;
      debugPrint('WebSocket连接成功');
      
    } catch (e) {
      debugPrint('WebSocket连接失败: $e');
      _isConnected = false;
    }
  }
  
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      
      if (type == 'connected') {
        debugPrint('WebSocket连接确认');
      } else if (type == 'price_update') {
        final updates = List<Map<String, dynamic>>.from(data['data']);
        debugPrint('收到价格更新: ${updates.length}个');
        
        if (onPriceUpdate != null) {
          onPriceUpdate!(updates);
        }
      }
    } catch (e) {
      debugPrint('处理消息失败: $e');
    }
  }
  
  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
  }
}
```

**3. 集成到Provider**

修改：`lib/services/providers/api_provider.dart`

```dart
class ApiProvider with ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  
  // 在构造函数中初始化
  ApiProvider() {
    _wsService.onPriceUpdate = _handlePriceUpdate;
  }
  
  void _handlePriceUpdate(List<Map<String, dynamic>> updates) {
    // 创建价格映射
    final priceMap = <String, Map<String, dynamic>>{};
    for (var update in updates) {
      priceMap[update['code']] = update;
    }
    
    // 更新信号列表
    for (int i = 0; i < _scanResults.length; i++) {
      final signal = _scanResults[i];
      final update = priceMap[signal.code];
      
      if (update != null) {
        // 创建新的StockIndicator（带更新的价格）
        final updatedSignal = StockIndicator(
          market: signal.market,
          code: signal.code,
          name: signal.name,
          signal: signal.signal,
          signalReason: signal.signalReason,
          price: update['price']?.toDouble(),
          changePercent: update['change_percent']?.toDouble(),
          volume: update['volume']?.toInt(),
          volumeRatio: signal.volumeRatio,
          details: signal.details,
          strategy: signal.strategy,
        );
        
        _scanResults[i] = updatedSignal;
      }
    }
    
    // 通知UI更新
    notifyListeners();
  }
  
  Future<void> scanStocksByIndicator({String? market, String? strategy}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // 1. 快速获取信号列表
      final results = await _apiService.getBuySignalStocks(strategy: strategy ?? _selectedStrategy);
      _scanResults = results.map((item) => StockIndicator.fromJson(item)).toList();
      
      // 2. 连接WebSocket
      _wsService.connect();
      
      _error = '';
      _isLoading = false;
      notifyListeners();
      
    } catch (e) {
      _error = '获取信号失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }
}
```

---

### 测试

**1. 启动后端**
```bash
cd stock_app_service
docker-compose up
```

**2. 测试WebSocket连接**
```bash
# 使用wscat测试
npm install -g wscat
wscat -c ws://localhost:8000/ws/stock/prices
```

**3. 启动前端**
```bash
cd stock_app_client
flutter run
```

**4. 观察日志**
- 后端：查看WebSocket连接日志
- 前端：查看价格更新日志

---

## 📊 预期效果

### 性能对比

| 操作 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 加载信号列表 | 1-2秒 | 0.1-0.2秒 | **10倍** |
| 价格更新 | 手动刷新 | 自动推送 | **实时** |
| 服务器负载 | 高 | 低 | **90%减少** |

### 用户体验

- ✅ 打开页面立即显示信号（无需等待）
- ✅ 价格自动跳动更新（无需刷新）
- ✅ 响应速度更快
- ✅ 更专业的交易体验

---

## 🔍 调试技巧

### 后端调试

```python
# 在websocket.py中添加日志
logger.info(f"当前连接数: {len(manager.active_connections)}")
logger.info(f"推送数据: {updates}")
```

### 前端调试

```dart
// 在websocket_service.dart中添加日志
debugPrint('WebSocket状态: $_isConnected');
debugPrint('收到更新: ${updates.length}个');
```

### 网络调试

Chrome DevTools → Network → WS → 查看WebSocket消息

---

## ⚠️ 注意事项

1. **WebSocket URL配置**
   - 开发环境：`ws://localhost:8000`
   - 生产环境：`wss://your-domain.com`（需要SSL）

2. **连接管理**
   - 页面切换时不要断开连接
   - 应用退出时才断开

3. **错误处理**
   - 网络断开自动重连
   - 消息解析失败不影响其他功能

4. **性能优化**
   - 只推送变化的数据
   - 批量更新UI（避免频繁刷新）

---

## 🚀 下一步优化

1. **断线重连**：指数退避策略
2. **心跳检测**：30秒ping/pong
3. **消息压缩**：大数据量时使用gzip
4. **增量更新**：只推送变化的字段
5. **订阅管理**：支持订阅特定股票

---

**预计工期**: 2天（后端1天 + 前端1天）  
**难度**: 中等  
**收益**: 极高（10倍性能提升 + 实时体验）

