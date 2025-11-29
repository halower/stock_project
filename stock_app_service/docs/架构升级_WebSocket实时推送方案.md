# 架构升级 - WebSocket实时推送方案

**日期**: 2025-11-24  
**类型**: 架构优化  
**优先级**: 高

---

## 📊 当前架构问题分析

### 现有方案（HTTP轮询）

```
前端 → HTTP GET /api/stocks/signal/buy
      ↓
      获取信号列表
      ↓
      遍历每个信号，查询Redis获取最新价格
      ↓
      计算涨跌幅
      ↓
      返回完整数据
      ↓
前端显示（耗时：1-2秒）
```

### 性能瓶颈

1. **每次请求都要查询价格**
   - 100个信号 = 50次Redis查询
   - 即使价格没变化也要查询

2. **前端需要轮询**
   - 用户手动刷新或定时刷新
   - 浪费带宽和服务器资源

3. **延迟高**
   - 从价格更新到用户看到：1-20分钟
   - 取决于用户何时刷新

4. **用户体验差**
   - 加载慢（1-2秒）
   - 数据不够实时

---

## 🎯 目标架构（WebSocket推送）

### 核心思想

**关注点分离**：
- 信号计算：只负责计算买卖信号（慢，每5分钟）
- 价格更新：实时推送最新价格（快，每分钟）
- 前端显示：合并两者数据

### 新架构流程

```
┌─────────────────────────────────────────────────────────┐
│                    后端服务                              │
│                                                         │
│  ┌──────────────┐      ┌──────────────┐               │
│  │ 定时任务      │      │ WebSocket    │               │
│  │ (每5分钟)    │      │ 服务器       │               │
│  └──────┬───────┘      └──────┬───────┘               │
│         │                     │                        │
│         ↓                     ↓                        │
│  ┌──────────────┐      ┌──────────────┐               │
│  │ 信号计算      │      │ 价格更新     │               │
│  │ (策略运算)   │      │ (每分钟)     │               │
│  └──────┬───────┘      └──────┬───────┘               │
│         │                     │                        │
│         ↓                     ↓                        │
│  ┌─────────────────────────────────┐                  │
│  │         Redis缓存               │                  │
│  │  - 信号列表 (signals)          │                  │
│  │  - 价格数据 (prices)           │                  │
│  └─────────────┬───────────────────┘                  │
│                │                                       │
└────────────────┼───────────────────────────────────────┘
                 │
                 ↓ WebSocket推送
┌────────────────────────────────────────────────────────┐
│                    前端应用                             │
│                                                        │
│  ┌──────────────┐      ┌──────────────┐              │
│  │ 初始加载      │      │ WebSocket    │              │
│  │ (HTTP)       │      │ 客户端       │              │
│  └──────┬───────┘      └──────┬───────┘              │
│         │                     │                       │
│         ↓                     ↓                       │
│  ┌──────────────┐      ┌──────────────┐              │
│  │ 获取信号列表  │      │ 接收价格更新  │              │
│  │ (只加载一次)  │      │ (实时推送)    │              │
│  └──────┬───────┘      └──────┬───────┘              │
│         │                     │                       │
│         └──────────┬──────────┘                       │
│                    ↓                                  │
│            ┌──────────────┐                           │
│            │ 合并显示     │                           │
│            │ (本地更新)   │                           │
│            └──────────────┘                           │
└────────────────────────────────────────────────────────┘
```

---

## 🔧 技术方案

### 后端技术栈

#### 1. WebSocket框架选择

**推荐：FastAPI内置WebSocket**

```python
from fastapi import WebSocket, WebSocketDisconnect
from fastapi.websockets import WebSocketState
```

**优势**：
- ✅ 与现有FastAPI无缝集成
- ✅ 支持async/await
- ✅ 自动处理连接管理
- ✅ 无需额外依赖

#### 2. 连接管理器

```python
class ConnectionManager:
    """WebSocket连接管理器"""
    
    def __init__(self):
        # 活跃连接：{client_id: websocket}
        self.active_connections: Dict[str, WebSocket] = {}
        # 订阅关系：{client_id: [strategy1, strategy2]}
        self.subscriptions: Dict[str, List[str]] = {}
    
    async def connect(self, websocket: WebSocket, client_id: str):
        """接受新连接"""
        await websocket.accept()
        self.active_connections[client_id] = websocket
        self.subscriptions[client_id] = []
    
    def disconnect(self, client_id: str):
        """断开连接"""
        if client_id in self.active_connections:
            del self.active_connections[client_id]
        if client_id in self.subscriptions:
            del self.subscriptions[client_id]
    
    def subscribe(self, client_id: str, strategy: str):
        """订阅策略"""
        if client_id not in self.subscriptions:
            self.subscriptions[client_id] = []
        if strategy not in self.subscriptions[client_id]:
            self.subscriptions[client_id].append(strategy)
    
    async def broadcast_price_update(self, updates: List[Dict]):
        """广播价格更新"""
        message = {
            "type": "price_update",
            "data": updates,
            "timestamp": datetime.now().isoformat()
        }
        
        # 发送给所有连接的客户端
        disconnected = []
        for client_id, websocket in self.active_connections.items():
            try:
                if websocket.client_state == WebSocketState.CONNECTED:
                    await websocket.send_json(message)
                else:
                    disconnected.append(client_id)
            except Exception as e:
                logger.error(f"发送消息失败: {client_id}, {e}")
                disconnected.append(client_id)
        
        # 清理断开的连接
        for client_id in disconnected:
            self.disconnect(client_id)
```

#### 3. Redis发布/订阅

```python
class PriceUpdatePublisher:
    """价格更新发布器"""
    
    def __init__(self):
        self.redis_client = None
        self.pubsub = None
    
    async def publish_price_update(self, updates: List[Dict]):
        """发布价格更新到Redis"""
        message = {
            "type": "price_update",
            "data": updates,
            "timestamp": datetime.now().isoformat()
        }
        
        await self.redis_client.publish(
            "stock:price:updates",
            json.dumps(message)
        )
    
    async def subscribe_price_updates(self, callback):
        """订阅价格更新"""
        pubsub = self.redis_client.pubsub()
        await pubsub.subscribe("stock:price:updates")
        
        async for message in pubsub.listen():
            if message["type"] == "message":
                data = json.loads(message["data"])
                await callback(data)
```

---

## 📝 实现步骤

### 阶段1: 后端WebSocket服务（2-3天）

#### 1.1 创建WebSocket端点

**文件**: `app/api/websocket.py`

```python
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict, List
import json
from datetime import datetime
from app.core.logging import logger

router = APIRouter()

# 全局连接管理器
manager = ConnectionManager()

@router.websocket("/ws/stock/prices")
async def websocket_stock_prices(websocket: WebSocket):
    """
    WebSocket端点：实时股票价格推送
    
    消息格式：
    {
        "type": "subscribe",
        "strategy": "volume_wave"  // 订阅特定策略的信号
    }
    
    推送格式：
    {
        "type": "price_update",
        "data": [
            {
                "code": "600519",
                "price": 1850.5,
                "change_percent": 2.5,
                "volume": 12345678
            }
        ],
        "timestamp": "2025-11-24T10:30:00"
    }
    """
    client_id = f"client_{id(websocket)}"
    
    try:
        # 接受连接
        await manager.connect(websocket, client_id)
        logger.info(f"WebSocket客户端连接: {client_id}")
        
        # 发送欢迎消息
        await websocket.send_json({
            "type": "connected",
            "client_id": client_id,
            "message": "WebSocket连接成功"
        })
        
        # 监听客户端消息
        while True:
            data = await websocket.receive_json()
            
            if data.get("type") == "subscribe":
                strategy = data.get("strategy", "volume_wave")
                manager.subscribe(client_id, strategy)
                logger.info(f"客户端 {client_id} 订阅策略: {strategy}")
                
                # 发送确认
                await websocket.send_json({
                    "type": "subscribed",
                    "strategy": strategy
                })
            
            elif data.get("type") == "ping":
                # 心跳检测
                await websocket.send_json({
                    "type": "pong",
                    "timestamp": datetime.now().isoformat()
                })
    
    except WebSocketDisconnect:
        logger.info(f"WebSocket客户端断开: {client_id}")
        manager.disconnect(client_id)
    
    except Exception as e:
        logger.error(f"WebSocket错误: {client_id}, {e}")
        manager.disconnect(client_id)
```

#### 1.2 集成到定时任务

**文件**: `app/services/scheduler/stock_scheduler.py`

```python
# 在实时更新任务完成后，推送价格更新
@staticmethod
def job_realtime_update():
    """定时任务：实时更新所有股票数据"""
    if not is_trading_time():
        logger.debug("非交易时间，跳过实时数据更新")
        return
    
    try:
        logger.info("========== 开始实时数据更新 ==========")
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # 1. 更新数据
            result = loop.run_until_complete(
                stock_atomic_service.realtime_update_all_stocks()
            )
            
            # 2. 获取更新的价格数据
            updated_prices = loop.run_until_complete(
                get_updated_prices_for_signals()
            )
            
            # 3. 推送到WebSocket客户端
            if updated_prices:
                loop.run_until_complete(
                    manager.broadcast_price_update(updated_prices)
                )
                logger.info(f"已推送 {len(updated_prices)} 个价格更新")
            
        finally:
            loop.close()
            
    except Exception as e:
        logger.error(f"实时数据更新失败: {e}")


async def get_updated_prices_for_signals() -> List[Dict]:
    """获取信号列表的最新价格"""
    from app.services.signal.signal_manager import signal_manager
    
    # 获取所有信号
    signals = await signal_manager.get_buy_signals()
    
    # 提取价格信息
    updates = []
    for signal in signals:
        updates.append({
            "code": signal.get("code"),
            "name": signal.get("name"),
            "price": signal.get("price"),
            "change_percent": signal.get("change_percent"),
            "volume": signal.get("volume"),
            "strategy": signal.get("strategy")
        })
    
    return updates
```

#### 1.3 修改信号API

**文件**: `app/api/signal_management.py`

```python
@router.get("/api/stocks/signal/buy")
async def get_buy_signals(
    strategy: Optional[str] = Query(None)
):
    """
    获取买入信号（不再更新价格）
    
    价格更新通过WebSocket实时推送
    """
    try:
        # 只获取信号，不更新价格
        signals = await signal_manager.get_buy_signals(strategy=strategy)
        
        # 移除价格更新逻辑
        # await _update_signals_with_latest_price(signals)  # ❌ 删除
        
        return {
            "code": 200,
            "message": "获取买入信号成功",
            "data": {
                "strategy": strategy,
                "signals": signals,
                "count": len(signals),
                "note": "价格通过WebSocket实时推送"
            }
        }
        
    except Exception as e:
        logger.error(f"获取买入信号失败: {str(e)}")
        return {
            "code": 500,
            "message": f"获取买入信号失败: {str(e)}"
        }
```

---

### 阶段2: 前端WebSocket客户端（2-3天）

#### 2.1 创建WebSocket服务

**文件**: `lib/services/websocket_service.dart`

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
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnected = false;
  String? _currentStrategy;
  
  // 价格更新回调
  Function(List<Map<String, dynamic>>)? onPriceUpdate;
  
  /// 连接WebSocket
  Future<void> connect(String strategy) async {
    if (_isConnected && _currentStrategy == strategy) {
      debugPrint('WebSocket已连接，策略相同，无需重连');
      return;
    }
    
    try {
      _currentStrategy = strategy;
      
      // 构建WebSocket URL
      final wsUrl = 'ws://localhost:8000/ws/stock/prices';
      debugPrint('连接WebSocket: $wsUrl');
      
      // 创建连接
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
      
      // 监听消息
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket错误: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket连接关闭');
          _handleDisconnect();
        },
      );
      
      _isConnected = true;
      
      // 等待连接确认
      await Future.delayed(Duration(milliseconds: 500));
      
      // 订阅策略
      await subscribe(strategy);
      
      // 启动心跳
      _startHeartbeat();
      
      debugPrint('WebSocket连接成功');
      
    } catch (e) {
      debugPrint('WebSocket连接失败: $e');
      _handleDisconnect();
    }
  }
  
  /// 订阅策略
  Future<void> subscribe(String strategy) async {
    if (!_isConnected || _channel == null) {
      debugPrint('WebSocket未连接，无法订阅');
      return;
    }
    
    final message = {
      'type': 'subscribe',
      'strategy': strategy,
    };
    
    _channel!.sink.add(jsonEncode(message));
    debugPrint('已订阅策略: $strategy');
  }
  
  /// 处理接收到的消息
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      
      if (type == 'connected') {
        debugPrint('WebSocket连接确认: ${data['client_id']}');
      } else if (type == 'subscribed') {
        debugPrint('策略订阅确认: ${data['strategy']}');
      } else if (type == 'price_update') {
        // 价格更新
        final updates = List<Map<String, dynamic>>.from(data['data']);
        debugPrint('收到价格更新: ${updates.length}个');
        
        // 触发回调
        if (onPriceUpdate != null) {
          onPriceUpdate!(updates);
        }
      } else if (type == 'pong') {
        // 心跳响应
        debugPrint('收到心跳响应');
      }
      
    } catch (e) {
      debugPrint('处理WebSocket消息失败: $e');
    }
  }
  
  /// 启动心跳
  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        final message = {'type': 'ping'};
        _channel!.sink.add(jsonEncode(message));
      }
    });
  }
  
  /// 处理断开连接
  void _handleDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    
    // 尝试重连
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 5), () {
      if (_currentStrategy != null) {
        debugPrint('尝试重新连接WebSocket...');
        connect(_currentStrategy!);
      }
    });
  }
  
  /// 断开连接
  void disconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController?.close();
    debugPrint('WebSocket已断开');
  }
}
```

#### 2.2 集成到Provider

**文件**: `lib/services/providers/api_provider.dart`

```dart
class ApiProvider with ChangeNotifier {
  // ... 现有代码 ...
  
  final WebSocketService _wsService = WebSocketService();
  
  /// 初始化WebSocket连接
  void initWebSocket(String strategy) {
    // 设置价格更新回调
    _wsService.onPriceUpdate = _handlePriceUpdate;
    
    // 连接WebSocket
    _wsService.connect(strategy);
  }
  
  /// 处理价格更新
  void _handlePriceUpdate(List<Map<String, dynamic>> updates) {
    // 创建价格映射表
    final priceMap = <String, Map<String, dynamic>>{};
    for (var update in updates) {
      final code = update['code'];
      if (code != null) {
        priceMap[code] = update;
      }
    }
    
    // 更新本地信号列表的价格
    bool hasChanges = false;
    for (var signal in _scanResults) {
      final update = priceMap[signal.code];
      if (update != null) {
        // 更新价格（需要修改StockIndicator为可变）
        // 或者创建新的StockIndicator对象
        hasChanges = true;
      }
    }
    
    // 通知UI更新
    if (hasChanges) {
      notifyListeners();
    }
  }
  
  /// 获取信号列表（不再等待价格更新）
  Future<void> scanStocksByIndicator({String? market, String? strategy}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final String strategyParam = strategy ?? _selectedStrategy;
      
      // 1. 快速获取信号列表（无价格更新）
      final results = await _apiService.getBuySignalStocks(strategy: strategyParam);
      _scanResults = results.map((item) => StockIndicator.fromJson(item)).toList();
      
      // 2. 初始化WebSocket连接（异步，不阻塞）
      initWebSocket(strategyParam);
      
      _error = '';
      _isLoading = false;
      notifyListeners();
      
    } catch (e) {
      _error = '获取指标扫描结果失败: $e';
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

## 📊 性能对比

### 当前方案 vs WebSocket方案

| 指标 | 当前方案 | WebSocket方案 | 提升 |
|------|---------|--------------|------|
| **首次加载** | 1-2秒 | **0.1-0.2秒** | **10倍** |
| **价格更新延迟** | 手动刷新 | **实时（1秒内）** | **实时** |
| **服务器负载** | 每次请求50次Redis查询 | **0次（推送）** | **100%减少** |
| **带宽消耗** | 每次完整数据 | **仅变化数据** | **90%减少** |
| **用户体验** | 需要手动刷新 | **自动更新** | **极大提升** |

### 具体数据

**场景：100个信号，用户停留5分钟**

| 操作 | 当前方案 | WebSocket方案 |
|------|---------|--------------|
| 初始加载 | 1.5秒 | 0.15秒 |
| 刷新次数 | 5次（手动） | 5次（自动） |
| Redis查询 | 250次 | 0次 |
| 数据传输 | 500KB × 5 = 2.5MB | 50KB + 10KB × 5 = 100KB |
| 总耗时 | 7.5秒 | 0.15秒 |

---

## 🎯 实施计划

### 第1周：后端开发

- [ ] Day 1-2: 实现WebSocket端点和连接管理器
- [ ] Day 3: 集成Redis发布/订阅
- [ ] Day 4: 修改定时任务，添加推送逻辑
- [ ] Day 5: 测试和优化

### 第2周：前端开发

- [ ] Day 1-2: 实现WebSocket服务
- [ ] Day 3: 集成到Provider
- [ ] Day 4: UI适配和测试
- [ ] Day 5: 性能优化和bug修复

### 第3周：测试和上线

- [ ] Day 1-2: 集成测试
- [ ] Day 3: 压力测试
- [ ] Day 4: 灰度发布
- [ ] Day 5: 全量上线

---

## 🔒 技术细节

### 1. 断线重连

```dart
// 指数退避重连策略
int _reconnectAttempts = 0;
void _reconnect() {
  final delay = min(30, pow(2, _reconnectAttempts).toInt());
  Timer(Duration(seconds: delay), () {
    connect(_currentStrategy!);
    _reconnectAttempts++;
  });
}
```

### 2. 消息去重

```python
# 使用时间戳和序列号防止重复推送
last_push_time = {}

def should_push(code: str, price: float) -> bool:
    key = f"{code}:{price}"
    now = time.time()
    
    if key in last_push_time:
        if now - last_push_time[key] < 1:  # 1秒内不重复推送
            return False
    
    last_push_time[key] = now
    return True
```

### 3. 增量更新

```python
# 只推送变化的数据
def get_price_changes(old_prices, new_prices):
    changes = []
    for code, new_price in new_prices.items():
        old_price = old_prices.get(code)
        if old_price != new_price:
            changes.append({
                "code": code,
                "price": new_price,
                "change": new_price - old_price if old_price else 0
            })
    return changes
```

---

## 📈 预期收益

### 性能提升

- ✅ 首次加载速度：**10倍提升**
- ✅ 价格更新延迟：**从分钟级到秒级**
- ✅ 服务器负载：**减少90%**
- ✅ 带宽消耗：**减少90%**

### 用户体验

- ✅ 无需手动刷新
- ✅ 价格实时跳动
- ✅ 响应速度更快
- ✅ 更专业的交易体验

### 技术优势

- ✅ 架构更清晰（关注点分离）
- ✅ 扩展性更好（支持更多实时功能）
- ✅ 维护性更好（逻辑解耦）

---

## 🚀 后续扩展

基于WebSocket基础设施，可以轻松实现：

1. **实时K线推送**
2. **实时成交量推送**
3. **实时新闻推送**
4. **多人协作功能**
5. **实时聊天功能**

---

**状态**: 📋 设计完成，待实施
**优先级**: ⭐⭐⭐⭐⭐ 高
**预计工期**: 2-3周

