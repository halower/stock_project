/// K线回放服务
/// 管理K线数据的回放逻辑
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class KLineReplayService {
  // API服务实例
  final ApiService _apiService = ApiService();
  
  // 完整的K线数据
  List<Map<String, dynamic>> _fullData = [];
  
  // 当前显示的索引
  int _currentIndex = 0;
  
  // 回放状态
  bool _isPlaying = false;
  bool _isReplayActive = false;
  bool _isReplayFinished = false;
  
  // 播放速度（毫秒）
  int _playSpeed = 1000; // 默认1秒一根K线
  
  // 数据流控制器
  final StreamController<List<Map<String, dynamic>>> _visibleDataController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  
  final StreamController<int> _currentIndexController =
      StreamController<int>.broadcast();
  
  // Getters
  bool get isPlaying => _isPlaying;
  bool get isReplayActive => _isReplayActive;
  bool get isReplayFinished => _isReplayFinished;
  int get playSpeed => _playSpeed;
  int get currentIndex => _currentIndex;
  int get totalCandles => _fullData.length;
  
  /// 获取当前K线数据
  Map<String, dynamic>? get currentCandle {
    if (_currentIndex >= 0 && _currentIndex < _fullData.length) {
      return _fullData[_currentIndex];
    }
    return null;
  }
  
  /// 获取播放速度（倍速）
  double get playbackSpeed => 1000 / _playSpeed;
  
  // Streams
  Stream<List<Map<String, dynamic>>> get visibleDataStream =>
      _visibleDataController.stream;
  Stream<int> get currentIndexStream => _currentIndexController.stream;
  
  /// 加载股票数据
  Future<void> loadStock(String stockCode) async {
    try {
      // 从API获取历史数据
      final response = await _apiService.getStockHistory(stockCode);
      
      // 检查响应数据
      if (response['data'] == null) {
        throw Exception('没有找到股票数据');
      }
      
      // 提取历史数据列表
      final List<dynamic> historyList = response['data'] as List<dynamic>;
      
      if (historyList.isEmpty) {
        throw Exception('股票历史数据为空');
      }
      
      // 转换为Map列表并确保数据按时间排序（从旧到新）
      _fullData = historyList.map((item) => item as Map<String, dynamic>).toList();
      _fullData.sort((a, b) {
        final dateA = a['date'] ?? a['trade_date'] ?? '';
        final dateB = b['date'] ?? b['trade_date'] ?? '';
        return dateA.toString().compareTo(dateB.toString());
      });
      
      // 初始化回放
      _currentIndex = 30; // 从第30根K线开始，确保有足够的历史数据
      _isReplayActive = true;
      _isReplayFinished = false;
      _isPlaying = false;
      
      // 发送初始数据
      _updateVisibleData();
      
      // 检查流控制器是否已关闭
      if (!_currentIndexController.isClosed) {
        _currentIndexController.add(_currentIndex);
      }
      
      debugPrint('K线回放数据加载完成: 共${_fullData.length}根K线');
    } catch (e) {
      debugPrint('加载K线数据失败: $e');
      rethrow;
    }
  }
  
  /// 播放
  void play() {
    if (!_isReplayActive || _isReplayFinished) return;
    _isPlaying = true;
  }
  
  /// 暂停
  void pause() {
    _isPlaying = false;
  }
  
  /// 开始回放
  void startReplay() {
    play();
  }
  
  /// 切换播放/暂停
  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }
  
  /// 设置播放速度
  void setPlaybackSpeed(double speed) {
    _playSpeed = (1000 / speed).round();
  }
  
  /// 下一根K线
  void nextCandle() {
    if (!_isReplayActive || _isReplayFinished) return;
    
    if (_currentIndex < _fullData.length - 1) {
      _currentIndex++;
      _updateVisibleData();
      
      // 检查流控制器是否已关闭
      if (!_currentIndexController.isClosed) {
        _currentIndexController.add(_currentIndex);
      }
    } else {
      // 回放结束
      _isReplayFinished = true;
      _isPlaying = false;
      debugPrint('K线回放完成');
    }
  }
  
  /// 上一根K线
  void previousCandle() {
    if (!_isReplayActive) return;
    
    if (_currentIndex > 30) {
      _currentIndex--;
      _isReplayFinished = false; // 如果回退，取消完成状态
      _updateVisibleData();
      
      // 检查流控制器是否已关闭
      if (!_currentIndexController.isClosed) {
        _currentIndexController.add(_currentIndex);
      }
    }
  }
  
  /// 跳转到指定位置
  void seekTo(int index) {
    if (!_isReplayActive) return;
    
    if (index >= 30 && index < _fullData.length) {
      _currentIndex = index;
      _isReplayFinished = index >= _fullData.length - 1;
      _updateVisibleData();
      
      // 检查流控制器是否已关闭
      if (!_currentIndexController.isClosed) {
        _currentIndexController.add(_currentIndex);
      }
    }
  }
  
  /// 设置播放速度
  void setPlaySpeed(int milliseconds) {
    _playSpeed = milliseconds;
  }
  
  /// 重置回放
  void reset() {
    if (!_isReplayActive) return;
    
    _currentIndex = 30;
    _isPlaying = false;
    _isReplayFinished = false;
    _updateVisibleData();
    
    // 检查流控制器是否已关闭
    if (!_currentIndexController.isClosed) {
      _currentIndexController.add(_currentIndex);
    }
  }
  
  /// 更新可见数据
  void _updateVisibleData() {
    if (_fullData.isEmpty) return;
    
    // 检查流控制器是否已关闭
    if (_visibleDataController.isClosed) {
      debugPrint('⚠️ 流控制器已关闭，停止发送数据');
      return;
    }
    
    // 传递从开始到当前位置的所有数据，让图表组件自己决定如何显示和计算指标
    // 这样可以确保技术指标有足够的历史数据进行计算
    final visibleData = _fullData.sublist(0, _currentIndex + 1);
    _visibleDataController.add(visibleData);
  }
  
  /// 获取当前价格
  double getCurrentPrice() {
    if (_currentIndex < 0 || _currentIndex >= _fullData.length) {
      return 0.0;
    }
    
    final currentCandle = _fullData[_currentIndex];
    return (currentCandle['close'] as num?)?.toDouble() ?? 0.0;
  }
  
  /// 获取未来N根K线（用于判断决策是否正确）
  List<Map<String, dynamic>> getFutureCandles(int count) {
    if (_currentIndex + count >= _fullData.length) {
      return _fullData.sublist(_currentIndex + 1);
    }
    return _fullData.sublist(_currentIndex + 1, _currentIndex + 1 + count);
  }
  
  /// 获取当前K线数据
  Map<String, dynamic>? getCurrentCandle() {
    if (_currentIndex < 0 || _currentIndex >= _fullData.length) {
      return null;
    }
    return _fullData[_currentIndex];
  }
  
  /// 获取历史数据（当前位置之前的N根K线）
  List<Map<String, dynamic>> getHistoricalCandles(int count) {
    final startIndex = (_currentIndex - count).clamp(0, _currentIndex);
    return _fullData.sublist(startIndex, _currentIndex + 1);
  }
  
  /// 清理资源
  void dispose() {
    // 停止播放
    _isPlaying = false;
    _isReplayActive = false;
    _isReplayFinished = false;
    
    // 清空数据
    _fullData.clear();
    _currentIndex = 0;
    
    // 关闭流控制器
    _visibleDataController.close();
    _currentIndexController.close();
    
    debugPrint('K线回放服务已清理');
  }
}

