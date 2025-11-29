import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

/// WebSocket连接状态
enum WebSocketStatus {
  disconnected,  // 未连接
  connecting,    // 连接中
  connected,     // 已连接
  error,         // 错误
}

/// WebSocket服务
/// 
/// 负责管理WebSocket连接和消息处理
class WebSocketService with ChangeNotifier {
  // WebSocket通道
  WebSocketChannel? _channel;
  
  // 连接状态
  WebSocketStatus _status = WebSocketStatus.disconnected;
  
  // 客户端ID
  String? _clientId;
  
  // 心跳定时器
  Timer? _heartbeatTimer;
  
  // 重连定时器
  Timer? _reconnectTimer;
  
  // 重连次数
  int _reconnectAttempts = 0;
  
  // 最大重连次数
  static const int maxReconnectAttempts = 5;
  
  // 保存URL用于重连
  String? _url;
  
  // 消息回调
  final Map<String, Function(Map<String, dynamic>)> _messageHandlers = {};
  
  // Getters
  WebSocketStatus get status => _status;
  String? get clientId => _clientId;
  bool get isConnected => _status == WebSocketStatus.connected;
  
  /// 连接到WebSocket服务器
  Future<void> connect(String url) async {
    if (_status == WebSocketStatus.connected || 
        _status == WebSocketStatus.connecting) {
      debugPrint('[WebSocket] 已连接或正在连接中');
      return;
    }
    
    _url = url; // 保存URL用于重连
    _updateStatus(WebSocketStatus.connecting);
    
    try {
      debugPrint('[WebSocket] 正在连接到 $url');
      
      // 创建WebSocket连接
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      // 监听消息（添加错误处理）
      _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          debugPrint('[WebSocket] 连接错误: $error');
          _updateStatus(WebSocketStatus.disconnected);
          _channel = null;
        },
        onDone: () {
          debugPrint('[WebSocket] 连接已断开');
          _updateStatus(WebSocketStatus.disconnected);
          _heartbeatTimer?.cancel();
          _channel = null;
        },
        cancelOnError: true,  // 出错时取消监听
      );
      
      debugPrint('[WebSocket] 连接成功，等待确认消息...');
      
    } catch (e) {
      debugPrint('[WebSocket] 连接失败: $e');
      _updateStatus(WebSocketStatus.disconnected);
      _channel = null;
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    debugPrint('[WebSocket] 主动断开连接');
    
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    
    await _channel?.sink.close();
    _channel = null;
    
    _updateStatus(WebSocketStatus.disconnected);
    _reconnectAttempts = 0;
  }
  
  /// 订阅策略
  void subscribeStrategy(String strategy) {
    if (!isConnected) {
      debugPrint('[WebSocket] 未连接，无法订阅');
      return;
    }
    
    final message = {
      'type': 'subscribe',
      'subscription_type': 'strategy',
      'target': strategy,
    };
    
    _sendMessage(message);
    debugPrint('[WebSocket] 订阅策略: $strategy');
  }
  
  /// 取消订阅策略
  void unsubscribeStrategy(String strategy) {
    if (!isConnected) return;
    
    final message = {
      'type': 'unsubscribe',
      'subscription_type': 'strategy',
      'target': strategy,
    };
    
    _sendMessage(message);
    debugPrint('[WebSocket] 取消订阅策略: $strategy');
  }
  
  /// 订阅单个股票
  void subscribeStock(String stockCode) {
    if (!isConnected) {
      debugPrint('[WebSocket] 未连接，无法订阅股票');
      return;
    }
    
    final message = {
      'type': 'subscribe',
      'subscription_type': 'stock',
      'target': stockCode,
    };
    
    _sendMessage(message);
    debugPrint('[WebSocket] 订阅股票: $stockCode');
  }
  
  /// 取消订阅股票
  void unsubscribeStock(String stockCode) {
    if (!isConnected) return;
    
    final message = {
      'type': 'unsubscribe',
      'subscription_type': 'stock',
      'target': stockCode,
    };
    
    _sendMessage(message);
    debugPrint('[WebSocket] 取消订阅股票: $stockCode');
  }
  
  /// 注册消息处理器
  void registerHandler(String messageType, Function(Map<String, dynamic>) handler) {
    _messageHandlers[messageType] = handler;
  }
  
  /// 移除消息处理器
  void unregisterHandler(String messageType) {
    _messageHandlers.remove(messageType);
  }
  
  // ==================== 私有方法 ====================
  
  /// 处理接收到的消息
  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      final messageType = message['type'] as String?;
      
      debugPrint('[WebSocket] 收到消息: $messageType');
      
      // 处理不同类型的消息
      switch (messageType) {
        case 'connected':
          _onConnected(message);
          break;
        case 'price_update':
          _onPriceUpdate(message);
          break;
        case 'pong':
          debugPrint('[WebSocket] 心跳响应');
          break;
        case 'subscribed':
          debugPrint('[WebSocket] 订阅确认: ${message['target']}');
          break;
        case 'error':
          debugPrint('[WebSocket] 错误消息: ${message['error']}');
          break;
        default:
          debugPrint('[WebSocket] 未知消息类型: $messageType');
      }
      
      // 调用注册的处理器
      final handler = _messageHandlers[messageType];
      if (handler != null) {
        handler(message);
      }
      
    } catch (e) {
      debugPrint('[WebSocket] 解析消息失败: $e');
    }
  }
  
  /// 处理连接成功
  void _onConnected(Map<String, dynamic> message) {
    _clientId = message['client_id'];
    _updateStatus(WebSocketStatus.connected);
    _reconnectAttempts = 0;
    
    debugPrint('[WebSocket] 连接确认，客户端ID: $_clientId');
    
    // 启动心跳
    _startHeartbeat();
  }
  
  /// 处理价格更新
  void _onPriceUpdate(Map<String, dynamic> message) {
    final count = message['count'] as int?;
    final data = message['data'];
    
    debugPrint('[WebSocket] 收到价格更新: $count 个股票');
    debugPrint('[WebSocket] 数据类型: ${data?.runtimeType}');
    if (data is List && data.isNotEmpty) {
      debugPrint('[WebSocket] 第一个更新: ${data[0]}');
    }
    
    // 这里会触发注册的处理器
  }
  
  /// 处理错误
  void _onError(error) {
    debugPrint('[WebSocket] 连接错误: $error');
    _updateStatus(WebSocketStatus.error);
    // 不自动重连，避免无限循环
    // _scheduleReconnect();
  }
  
  /// 处理断开连接
  void _onDisconnected() {
    debugPrint('[WebSocket] 连接已断开');
    _updateStatus(WebSocketStatus.disconnected);
    _heartbeatTimer?.cancel();
    // 不自动重连，避免无限循环
    // _scheduleReconnect();
  }
  
  /// 发送消息
  void _sendMessage(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[WebSocket] 发送消息失败: $e');
    }
  }
  
  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    
    // 每30秒发送一次心跳
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (isConnected) {
        _sendMessage({'type': 'ping'});
        debugPrint('[WebSocket] 发送心跳');
      }
    });
  }
  
  /// 计划重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('[WebSocket] 达到最大重连次数，停止重连');
      return;
    }
    
    if (_url == null) {
      debugPrint('[WebSocket] URL为空，无法重连');
      return;
    }
    
    _reconnectTimer?.cancel();
    
    // 指数退避：2秒、4秒、8秒...
    final delay = Duration(seconds: 2 << _reconnectAttempts);
    _reconnectAttempts++;
    
    debugPrint('[WebSocket] ${delay.inSeconds}秒后尝试重连（第$_reconnectAttempts次）');
    
    _reconnectTimer = Timer(delay, () {
      connect(_url!);
    });
  }
  
  /// 更新状态
  void _updateStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

