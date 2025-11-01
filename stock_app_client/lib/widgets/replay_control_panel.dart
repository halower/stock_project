/// 回放控制面板组件
/// 提供播放、暂停、速度控制等功能
import 'package:flutter/material.dart';
import '../services/kline_replay_service.dart';

class ReplayControlPanel extends StatefulWidget {
  final KLineReplayService replayService;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(int) onSpeedChange;
  final VoidCallback onReset;
  final Function(int)? onSeek; // 新增：进度跳转回调
  
  const ReplayControlPanel({
    super.key,
    required this.replayService,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onSpeedChange,
    required this.onReset,
    this.onSeek,
  });
  
  @override
  State<ReplayControlPanel> createState() => _ReplayControlPanelState();
}

class _ReplayControlPanelState extends State<ReplayControlPanel> {
  // 播放速度选项（毫秒）
  final List<Map<String, dynamic>> _speedOptions = [
    {'label': '0.3x', 'value': 3333},
    {'label': '0.5x', 'value': 2000},
    {'label': '1x', 'value': 1000},
    {'label': '2x', 'value': 500},
    {'label': '4x', 'value': 250},
  ];
  
  int _selectedSpeedIndex = 2; // 默认1x速度（现在是索引2）
  
  @override
  Widget build(BuildContext context) {
    if (!widget.replayService.isReplayActive) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          StreamBuilder<int>(
            stream: widget.replayService.currentIndexStream,
            builder: (context, snapshot) {
              final current = snapshot.data ?? 30;
              final total = widget.replayService.totalCandles;
              
              // 确保Slider的值在有效范围内
              final minValue = 30.0;
              final maxValue = total > 30 ? total.toDouble() - 1 : 31.0;
              final sliderValue = current.toDouble().clamp(minValue, maxValue);
              
              return Row(
                children: [
                  Text(
                    '$current',
                    style: const TextStyle(fontSize: 12, height: 1.2),
                  ),
                  Expanded(
                    child: total > 30 ? Slider(
                      value: sliderValue,
                      min: minValue,
                      max: maxValue,
                      onChanged: (value) {
                        widget.replayService.seekTo(value.toInt());
                        // 通知父组件更新UI
                        if (widget.onSeek != null) {
                          widget.onSeek!(value.toInt());
                        }
                      },
                    ) : const SizedBox.shrink(),
                  ),
                  Text(
                    '$total',
                    style: const TextStyle(fontSize: 12, height: 1.2),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 重置按钮
              _buildControlButton(
                icon: Icons.replay,
                label: '重置',
                onPressed: widget.onReset,
              ),
              
              // 上一根
              _buildControlButton(
                icon: Icons.skip_previous,
                label: '上一根',
                onPressed: widget.onPrevious,
              ),
              
              // 播放/暂停
              _buildControlButton(
                icon: widget.replayService.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                label: widget.replayService.isPlaying ? '暂停' : '播放',
                onPressed: widget.onPlayPause,
                isPrimary: true,
              ),
              
              // 下一根
              _buildControlButton(
                icon: Icons.skip_next,
                label: '下一根',
                onPressed: widget.onNext,
              ),
              
              // 速度选择
              _buildSpeedSelector(),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 构建控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          iconSize: isPrimary ? 36 : 28,
          color: isPrimary ? Theme.of(context).primaryColor : null,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: isPrimary
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            height: 1.2,
            color: isPrimary ? Theme.of(context).primaryColor : Colors.grey,
          ),
        ),
      ],
    );
  }
  
  /// 构建速度选择器
  Widget _buildSpeedSelector() {
    return PopupMenuButton<int>(
      initialValue: _selectedSpeedIndex,
      onSelected: (index) {
        setState(() {
          _selectedSpeedIndex = index;
        });
        widget.onSpeedChange(_speedOptions[index]['value'] as int);
      },
      itemBuilder: (context) => _speedOptions.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        return PopupMenuItem<int>(
          value: index,
          child: Row(
            children: [
              if (_selectedSpeedIndex == index)
                const Icon(Icons.check, size: 16),
              if (_selectedSpeedIndex == index)
                const SizedBox(width: 8),
              Text(option['label'] as String),
            ],
          ),
        );
      }).toList(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.speed, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            _speedOptions[_selectedSpeedIndex]['label'] as String,
            style: const TextStyle(
              fontSize: 10,
              height: 1.2,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

