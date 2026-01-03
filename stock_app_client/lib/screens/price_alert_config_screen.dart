import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/price_alert.dart';
import '../models/watchlist_item.dart';
import '../services/price_alert_service.dart';

class PriceAlertConfigScreen extends StatefulWidget {
  final WatchlistItem stock;

  const PriceAlertConfigScreen({
    super.key,
    required this.stock,
  });

  @override
  State<PriceAlertConfigScreen> createState() => _PriceAlertConfigScreenState();
}

class _PriceAlertConfigScreenState extends State<PriceAlertConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PriceAlert> _alerts = [];
  List<PriceAlert> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final alerts = await PriceAlertService.getAlertsForStock(widget.stock.code);
      final history = await PriceAlertService.getHistory();
      final stockHistory = history.where((h) => h.stockCode == widget.stock.code).toList();
      
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _history = stockHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('价格预警', style: TextStyle(fontSize: 18)),
            Text(
              '${widget.stock.name}(${widget.stock.code})',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '活跃预警 (${_alerts.length})'),
            Tab(text: '历史记录 (${_history.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAlertsTab(),
                _buildHistoryTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAlertDialog,
        icon: Icon(Icons.add_alert),
        label: Text('添加预警'),
      ),
    );
  }

  Widget _buildAlertsTab() {
    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无预警', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('点击右下角按钮添加预警', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        return _buildAlertCard(alert);
      },
    );
  }

  Widget _buildAlertCard(PriceAlert alert) {
    final currentPrice = widget.stock.currentPrice ?? 0;
    final priceDiff = alert.calculatePriceDifferencePercent(currentPrice);
    final isAbove = priceDiff > 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  alert.alertType.icon,
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.alertType.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '目标价: ¥${alert.targetPrice.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: alert.isEnabled,
                  onChanged: (value) => _toggleAlert(alert, value),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (currentPrice > 0) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('当前价格'),
                        Text(
                          '¥${currentPrice.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('距离目标'),
                        Text(
                          '${isAbove ? "+" : ""}${priceDiff.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAbove ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
            ],
            if (alert.note != null && alert.note!.isNotEmpty) ...[
              Text(
                '备注: ${alert.note}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '创建于 ${DateFormat('MM-dd HH:mm').format(alert.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditAlertDialog(alert),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    SizedBox(width: 16),
                    IconButton(
                      icon: Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteAlert(alert),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无历史记录', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final alert = _history[index];
        return _buildHistoryCard(alert);
      },
    );
  }

  Widget _buildHistoryCard(PriceAlert alert) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(alert.alertType.icon, style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.alertType.displayName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '已触发',
                    style: TextStyle(fontSize: 12, color: Colors.green[800]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('目标价'),
                Text(
                  '¥${alert.targetPrice.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('触发价'),
                Text(
                  '¥${alert.triggeredPrice?.toStringAsFixed(2) ?? "-"}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '触发时间: ${alert.triggeredAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(alert.triggeredAt!) : "-"}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _reEnableAlert(alert),
              icon: Icon(Icons.refresh, size: 16),
              label: Text('重新启用'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAlertDialog() {
    showDialog(
      context: context,
      builder: (context) => _AlertFormDialog(
        stock: widget.stock,
        onSaved: () {
          _loadData();
        },
      ),
    );
  }

  void _showEditAlertDialog(PriceAlert alert) {
    showDialog(
      context: context,
      builder: (context) => _AlertFormDialog(
        stock: widget.stock,
        alert: alert,
        onSaved: () {
          _loadData();
        },
      ),
    );
  }

  Future<void> _toggleAlert(PriceAlert alert, bool value) async {
    try {
      await PriceAlertService.toggleAlert(alert.id, value);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? '预警已启用' : '预警已禁用')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  Future<void> _deleteAlert(PriceAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除这个预警吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PriceAlertService.deleteAlert(alert.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('预警已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _reEnableAlert(PriceAlert alert) async {
    try {
      await PriceAlertService.reEnableAlert(alert.id);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('预警已重新启用')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }
}

class _AlertFormDialog extends StatefulWidget {
  final WatchlistItem stock;
  final PriceAlert? alert;
  final VoidCallback onSaved;

  const _AlertFormDialog({
    required this.stock,
    this.alert,
    required this.onSaved,
  });

  @override
  State<_AlertFormDialog> createState() => _AlertFormDialogState();
}

class _AlertFormDialogState extends State<_AlertFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late AlertType _selectedType;
  late TextEditingController _priceController;
  late TextEditingController _noteController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.alert?.alertType ?? AlertType.targetPrice;
    _priceController = TextEditingController(
      text: widget.alert?.targetPrice.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(
      text: widget.alert?.note ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPrice = widget.stock.currentPrice ?? 0;

    return AlertDialog(
      title: Text(widget.alert == null ? '添加预警' : '编辑预警'),
      contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9, // 设置宽度为屏幕宽度的90%
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (currentPrice > 0) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('当前价格'),
                      Text(
                        '¥${currentPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
              Text('预警类型', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...AlertType.values.map((type) {
                return RadioListTile<AlertType>(
                  title: Row(
                    children: [
                      Text(type.icon, style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(type.displayName),
                    ],
                  ),
                  value: type,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() => _selectedType = value!);
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: '目标价格',
                  prefixText: '¥',
                  border: OutlineInputBorder(),
                  suffixIcon: currentPrice > 0
                      ? PopupMenuButton<double>(
                          icon: Icon(Icons.auto_fix_high),
                          tooltip: '快速设置',
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: currentPrice * 1.05,
                              child: Text('+5% (¥${(currentPrice * 1.05).toStringAsFixed(2)})'),
                            ),
                            PopupMenuItem(
                              value: currentPrice * 1.10,
                              child: Text('+10% (¥${(currentPrice * 1.10).toStringAsFixed(2)})'),
                            ),
                            PopupMenuItem(
                              value: currentPrice * 0.95,
                              child: Text('-5% (¥${(currentPrice * 0.95).toStringAsFixed(2)})'),
                            ),
                            PopupMenuItem(
                              value: currentPrice * 0.90,
                              child: Text('-10% (¥${(currentPrice * 0.90).toStringAsFixed(2)})'),
                            ),
                          ],
                          onSelected: (value) {
                            _priceController.text = value.toStringAsFixed(2);
                          },
                        )
                      : null,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入目标价格';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return '请输入有效的价格';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                  hintText: '添加备注信息...',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAlert,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('保存'),
        ),
      ],
    );
  }

  Future<void> _saveAlert() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final price = double.parse(_priceController.text);
      
      if (widget.alert == null) {
        // 添加新预警
        final alert = PriceAlert(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          stockCode: widget.stock.code,
          stockName: widget.stock.name,
          alertType: _selectedType,
          targetPrice: price,
          createdAt: DateTime.now(),
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
        await PriceAlertService.addAlert(alert);
      } else {
        // 更新现有预警
        final updatedAlert = widget.alert!.copyWith(
          alertType: _selectedType,
          targetPrice: price,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
        await PriceAlertService.updateAlert(updatedAlert);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.alert == null ? '预警已添加' : '预警已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}

