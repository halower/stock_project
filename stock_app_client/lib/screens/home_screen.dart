import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stock_app/services/watchlist_service.dart';
import 'dart:async';
import '../services/providers/trade_provider.dart';
import '../services/providers/strategy_provider.dart';
import '../services/providers/stock_provider.dart';
import '../services/auth_service.dart';
import 'trade_record_screen.dart';
import 'stock_scanner_screen.dart';
import 'strategy_screen.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'news_analysis_screen.dart';
import 'feedback_screen.dart';
import 'watchlist_screen.dart';
import 'kline_replay_screen.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final Widget screen;
  final List<Widget> Function(BuildContext)? actions; // 页面的action按钮
  final bool needsAppBar; // 是否需要HomeScreen提供AppBar
  final List<MenuItem>? subMenus;
  final bool isExpanded;

  const MenuItem({
    required this.title,
    required this.icon,
    required this.screen,
    this.actions,
    this.needsAppBar = false, // 默认不需要
    this.subMenus,
    this.isExpanded = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isMenuExpanded = false;
  Timer? _authCheckTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 定义菜单项，使用结构化方式便于扩展
  late List<MenuItem> _menuItems;

  @override
  void initState() {
    super.initState();
    
    // 不自动打开侧边栏，让用户主动点击菜单按钮
    
    // 初始化菜单项（将盘感练习加入侧边栏）
    _menuItems = [
      MenuItem(
        title: '技术量化',
        icon: Icons.storage,
        screen: const StockScannerScreen(),
        actions: StockScannerScreen.buildActions,
        needsAppBar: true, // 需要HomeScreen提供AppBar
      ),
      const MenuItem(
        title: '消息量化',
        icon: Icons.newspaper,
        screen: NewsAnalysisScreen(),
      ),
      const MenuItem(
        title: '交易记录',
        icon: Icons.list_alt,
        screen: TradeRecordScreen(),
      ),
      const MenuItem(
        title: '策略',
        icon: Icons.auto_graph,
        screen: StrategyScreen(),
      ),
      const MenuItem(
        title: '盘感练习',
        icon: Icons.play_circle_outline,
        screen: EnhancedKLineReplayScreen(),
      ),
      const MenuItem(
        title: '概览',
        icon: Icons.analytics,
        screen: AnalysisScreen(),
      ),
      // 添加设置页面
      const MenuItem(
        title: '系统设置',
        icon: Icons.settings,
        screen: SettingsScreen(), // 使用设置页面
      ),
    ];

    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TradeProvider>().loadTradeRecords();
      context.read<StrategyProvider>().loadStrategies();
      context.read<StockProvider>().loadStocks();
    });

    // 启动定期检查授权状态的定时器（每分钟检查一次）
    _startAuthCheckTimer();
  }

  @override
  void dispose() {
    _authCheckTimer?.cancel();
    super.dispose();
  }

  // 启动授权检查定时器
  void _startAuthCheckTimer() {
    // 取消现有的定时器（如果有）
    _authCheckTimer?.cancel();

    // 创建新的定时器，每30秒检查一次授权状态
    _authCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAuthStatus();
    });

    // 立即进行一次检查
    _checkAuthStatus();
  }

  // 检查授权状态
  Future<void> _checkAuthStatus() async {
    final isAuthorized = await AuthService.isAuthorized();

    if (!isAuthorized && mounted) {
      // 授权已过期，立即退出到登录页面
      _authCheckTimer?.cancel(); // 取消定时器

      // 显示提示消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('授权已过期，请重新输入授权码'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );

      // 立即导航到登录页面
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // 清除所有路由栈
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否为移动设备
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    // 检测屏幕方向
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    // 检查当前是否在盘感练习页面
    final isKLineReplayScreen = _menuItems[_selectedIndex].title == '盘感练习';

    if (isMobile) {
      // 移动设备使用底部导航栏（不包含盘感练习）
      final bottomNavItems = _menuItems.where((item) => item.title != '盘感练习').toList();
      final bottomNavIndex = _selectedIndex >= bottomNavItems.length 
          ? 0 
          : (_menuItems[_selectedIndex].title == '盘感练习' 
              ? 0 
              : bottomNavItems.indexWhere((item) => item.title == _menuItems[_selectedIndex].title));
      
      // 如果是横屏且在盘感练习页面，返回全屏布局
      if (isLandscape && isKLineReplayScreen) {
        return _menuItems[_selectedIndex].screen;
      }
      
      return Scaffold(
        key: _scaffoldKey,
        appBar: _menuItems[_selectedIndex].needsAppBar
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                title: Text(_menuItems[_selectedIndex].title),
                actions: _menuItems[_selectedIndex].actions?.call(context),
              )
            : null,
        body: Builder(
          builder: (context) {
            // 为子页面提供访问drawer的能力
            return _menuItems[_selectedIndex].screen;
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: bottomNavIndex.clamp(0, bottomNavItems.length - 1),
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = _menuItems.indexWhere((item) => item.title == bottomNavItems[index].title);
            });
          },
          destinations: bottomNavItems
              .map((item) => NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.title,
                  ))
              .toList(),
        ),
        // 使用美化的侧边栏导航
        drawer: _buildDrawer(),
      );
    } else {
      // 桌面设备使用侧边导航栏
      return Scaffold(
        body: Row(
          children: [
            // 可展开的左侧导航栏
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isMenuExpanded ? 220 : 70,
              child: Card(
                margin: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                elevation: 4,
                child: Column(
                  children: [
                    // 顶部 Logo 区域
                    Container(
                      height: 80,
                      alignment: Alignment.center,
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: _isMenuExpanded
                          ? Text(
                              '交易大陆',
                              style: Theme.of(context).textTheme.titleLarge,
                            )
                          : const Icon(Icons.bar_chart, size: 30),
                    ),

                    // 菜单展开/收起按钮
                    IconButton(
                      icon: Icon(
                        _isMenuExpanded
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                      ),
                      onPressed: () {
                        setState(() {
                          _isMenuExpanded = !_isMenuExpanded;
                        });
                      },
                    ),

                    // 导航菜单列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: _menuItems.length,
                        itemBuilder: (context, index) {
                          final item = _menuItems[index];
                          return ListTile(
                            selected: _selectedIndex == index,
                            selectedColor: Theme.of(context).primaryColor,
                            selectedTileColor:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            leading: Icon(item.icon),
                            title: _isMenuExpanded ? Text(item.title) : null,
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 右侧内容区域（移除顶部标题栏）
            Expanded(
              child: _menuItems[_selectedIndex].screen,
            ),
          ],
        ),
      );
    }
  }

  // 构建美化的侧边栏导航
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // 简洁的头部（移除logo）
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '交易大陆',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '职业交易培养助手',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 主导航菜单
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                // 主功能区域标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    '主要功能',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                
                // 遍历所有菜单项
                ...List.generate(_menuItems.length, (index) {
                  final item = _menuItems[index];
                  final isSelected = _selectedIndex == index;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected 
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.icon,
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? Theme.of(context).primaryColor 
                              : Colors.black87,
                        ),
                      ),
                      // 移除所有菜单项的箭头
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                        Navigator.pop(context); // 关闭侧边栏
                      },
                    ),
                  );
                }),
                
                const SizedBox(height: 16),
                const Divider(),

                // 快速操作区域
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    '快速操作',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                
                // 我的备选池带数量徽标
                _buildWatchlistTile(),
                
                _buildQuickActionTile(
                  icon: Icons.feedback,
                  title: '问题反馈',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeedbackScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建我的备选池带数量徽标
  Widget _buildWatchlistTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: FutureBuilder<int>(
        future: WatchlistService.getWatchlistCount(),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.star,
                color: Colors.grey.shade700,
                size: 22,
              ),
            ),
            title: const Text(
              '我的备选池',
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
            trailing: count > 0 ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ) : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WatchlistScreen(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 构建快速操作项
  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.grey.shade700,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
