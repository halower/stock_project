import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/providers/trade_provider.dart';
import '../services/providers/strategy_provider.dart';
import '../services/providers/stock_provider.dart';
import '../services/auth_service.dart';
import '../services/watchlist_service.dart';
import 'trade_record_screen.dart';
import 'stock_scanner_screen.dart';
import 'strategy_screen.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'news_analysis_screen.dart';
import 'feedback_screen.dart';
import 'watchlist_screen.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final Widget screen;
  final List<MenuItem>? subMenus;
  final bool isExpanded;

  const MenuItem({
    required this.title,
    required this.icon,
    required this.screen,
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

  // 定义菜单项，使用结构化方式便于扩展
  late List<MenuItem> _menuItems;

  @override
  void initState() {
    super.initState();
    // 初始化菜单项
    _menuItems = [
      const MenuItem(
        title: '技术量化',
        icon: Icons.storage,
        screen: StockScannerScreen(),
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

    if (isMobile) {
      // 移动设备使用底部导航栏
      return Scaffold(
        body: _menuItems[_selectedIndex].screen,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: _menuItems
              .map((item) => NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.title,
                  ))
              .toList(),
        ),
        // 添加抽屉菜单，用于显示更多选项
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
                              '交易系统',
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

            // 右侧内容区域
            Expanded(
              child: _menuItems[_selectedIndex].screen,
            ),
          ],
        ),
      );
    }
  }

  // 构建抽屉菜单
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // 抽屉菜单头部
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    color: Colors.white,
                    size: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '交易系统',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 抽屉菜单项
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 快速操作区域
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '快速操作',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('添加交易计划'),
                  onTap: () {
                    // 跳转到添加交易计划页面的逻辑
                    Navigator.pop(context); // 关闭抽屉
                    // 这里添加导航到添加交易计划页面的代码
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('搜索股票'),
                  onTap: () {
                    // 跳转到搜索股票页面的逻辑
                    Navigator.pop(context); // 关闭抽屉
                    // 这里添加导航到搜索股票页面的代码
                  },
                ),
                // 我的备选池 - 添加实时数量显示
                ValueListenableBuilder<int>(
                  valueListenable: WatchlistService.watchlistChangeNotifier,
                  builder: (context, changeCount, child) {
                    return FutureBuilder<int>(
                      future: WatchlistService.getWatchlistCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return ListTile(
                          leading: const Icon(Icons.star),
                          title: const Text('我的备选池'),
                          trailing: count > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : count.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(context); // 关闭抽屉
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const WatchlistScreen()),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const Divider(),

                // 系统设置区域
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '系统设置',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('个人设置'),
                  onTap: () {
                    // 跳转到个人设置页面的逻辑
                    Navigator.pop(context); // 关闭抽屉
                    // 这里添加导航到个人设置页面的代码
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('数据同步'),
                  onTap: () {
                    // 跳转到数据同步页面的逻辑
                    Navigator.pop(context); // 关闭抽屉
                    // 这里添加导航到数据同步页面的代码
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.feedback),
                  title: const Text('问题反馈'),
                  onTap: () {
                    // 关闭抽屉并跳转到反馈页面
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FeedbackScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于'),
                  onTap: () {
                    // 跳转到关于页面的逻辑
                    Navigator.pop(context); // 关闭抽屉
                    // 这里添加导航到关于页面的代码
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
