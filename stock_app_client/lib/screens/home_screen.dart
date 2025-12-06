import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stock_app/services/watchlist_service.dart';
import 'dart:async';
import '../services/providers/trade_provider.dart';
import '../services/providers/strategy_provider.dart';
import '../services/providers/stock_provider.dart';
import '../services/auth_service.dart';
import '../utils/design_system.dart';
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
import 'index_analysis_screen.dart';
import 'limit_board_screen.dart';

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
          icon: Icons.query_stats,
          screen: const StockScannerScreen(),
          actions: StockScannerScreen.buildActions,
          needsAppBar: true, // 需要HomeScreen提供AppBar
        ),
        const MenuItem(
          title: '消息量化',
          icon: Icons.article,
          screen: NewsAnalysisScreen(),
          needsAppBar: false, // 消息量化有自己的AppBar，不需要HomeScreen提供
        ),
        const MenuItem(
          title: '交易记录',
          icon: Icons.receipt_long,
          screen: TradeRecordScreen(),
          needsAppBar: false, // 交易记录有自己的AppBar，不需要HomeScreen提供
        ),
        const MenuItem(
          title: '交易策略',
          icon: Icons.psychology,
          screen: StrategyScreen(),
          needsAppBar: false, // 交易策略有自己的AppBar，不需要HomeScreen提供
        ),
        const MenuItem(
          title: 'K线回放',
          icon: Icons.candlestick_chart,
          screen: EnhancedKLineReplayScreen(),
          needsAppBar: false, // K线回放有自己的AppBar，不需要HomeScreen提供
        ),
        const MenuItem(
          title: '打板数据',
          icon: Icons.bolt,
          screen: LimitBoardScreen(),
          needsAppBar: false, // 打板数据有自己的AppBar，不需要HomeScreen提供
        ),
        MenuItem(
          title: '大盘分析',
          icon: Icons.show_chart,
          screen: const IndexAnalysisScreen(),
          needsAppBar: false, // 大盘分析有自己的AppBar，不需要HomeScreen提供
        ),
        const MenuItem(
          title: '交易概览',
          icon: Icons.dashboard,
          screen: AnalysisScreen(),
          needsAppBar: false, // 交易概览有自己的AppBar，不需要HomeScreen提供
        ),
        // 添加设置页面
        const MenuItem(
          title: '系统设置',
          icon: Icons.settings_suggest,
          screen: SettingsScreen(),
          needsAppBar: false, // 系统设置有自己的AppBar，不需要HomeScreen提供
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
  
  // 获取对应的空心图标
  IconData _getOutlinedIcon(IconData icon) {
    final iconMap = {
      Icons.query_stats: Icons.query_stats_outlined,
      Icons.article: Icons.article_outlined,
      Icons.receipt_long: Icons.receipt_long_outlined,
      Icons.psychology: Icons.psychology_outlined,
      Icons.candlestick_chart: Icons.candlestick_chart_outlined,
      Icons.bolt: Icons.bolt_outlined,
      Icons.show_chart: Icons.show_chart_outlined,
      Icons.dashboard: Icons.dashboard_outlined,
      Icons.settings_suggest: Icons.settings_suggest_outlined,
    };
    return iconMap[icon] ?? icon;
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否为移动设备
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    // 检测屏幕方向
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    // 检查当前是否在K线回放页面
    final isKLineReplayScreen = _menuItems[_selectedIndex].title == 'K线回放';

    if (isMobile) {
      // 移动设备使用底部导航栏（不包含K线回放、打板数据和大盘分析，这些只在侧边栏显示）
      final sidebarOnlyItems = ['K线回放', '打板数据', '大盘分析'];
      final bottomNavItems = _menuItems.where((item) => !sidebarOnlyItems.contains(item.title)).toList();
      final bottomNavIndex = _selectedIndex >= bottomNavItems.length 
          ? 0 
          : (sidebarOnlyItems.contains(_menuItems[_selectedIndex].title)
              ? 0 
              : bottomNavItems.indexWhere((item) => item.title == _menuItems[_selectedIndex].title));
      
      // 如果是横屏且在盘感练习页面，返回全屏布局
      if (isLandscape && isKLineReplayScreen) {
        return _menuItems[_selectedIndex].screen;
      }
      
      // 根据页面是否需要AppBar来决定是否显示
      final currentItem = _menuItems[_selectedIndex];
      
      return Scaffold(
        key: _scaffoldKey,
        appBar: currentItem.needsAppBar 
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                title: Text(currentItem.title),
                actions: currentItem.actions?.call(context),
              )
            : null, // 如果不需要AppBar，则设为null
        body: IndexedStack(
          index: _selectedIndex,
          children: _menuItems.map((item) => item.screen).toList(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: bottomNavIndex.clamp(0, bottomNavItems.length - 1),
          onDestinationSelected: (int index) {
            final selectedItem = bottomNavItems[index];
            final newIndex = _menuItems.indexWhere((item) => item.title == selectedItem.title);
            if (newIndex != -1) {
              setState(() {
                _selectedIndex = newIndex;
              });
            }
          },
          destinations: bottomNavItems.map((item) => NavigationDestination(
            icon: Icon(_getOutlinedIcon(item.icon)),
            selectedIcon: Icon(item.icon),
                    label: item.title,
          )).toList(),
        ),
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
              child: IndexedStack(
                index: _selectedIndex,
                children: _menuItems.map((item) => item.screen).toList(),
              ),
            ),
          ],
        ),
      );
    }
  }

  // 构建美化的侧边栏导航
  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: isDark ? AppDesignSystem.darkBg1 : Colors.white,
      child: Column(
        children: [
          // 头部设计 - Logo和标题在同一行
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppDesignSystem.primary,
                  AppDesignSystem.primary.withOpacity(0.85),
                  const Color(0xFF7C3AED),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    // Logo图标
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.trending_up_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 标题和副标题
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '交易大陆',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '专业量化交易平台',
                        style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                          ),
                        ],
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 遍历所有菜单项
                ...List.generate(_menuItems.length, (index) {
                  final item = _menuItems[index];
                  final isSelected = _selectedIndex == index;
                  final itemColor = _getMenuItemColor(item.title);
                  
                  return _buildDrawerItem(
                    icon: item.icon,
                    title: item.title,
                    isSelected: isSelected,
                    itemColor: itemColor,
                    isDark: isDark,
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      Navigator.pop(context);
                      },
                  );
                }),
                
                const SizedBox(height: 12),
                
                // 分隔线
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                
                const SizedBox(height: 8),

                // 快速操作区域标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '快速操作',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // 我的备选池
                _buildWatchlistTile(),
                
                // 问题反馈
                _buildQuickActionTile(
                  icon: Icons.feedback_outlined,
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
          
          // 底部版本信息
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'v1.2.13',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppDesignSystem.darkText4 : AppDesignSystem.lightText4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 获取菜单项颜色
  Color _getMenuItemColor(String title) {
    switch (title) {
      case 'K线回放': return const Color(0xFF8B5CF6);
      case '技术量化': return AppDesignSystem.primary;
      case '消息量化': return const Color(0xFFF59E0B);
      case '交易记录': return AppDesignSystem.downColor;
      case '交易策略': return const Color(0xFF0EA5E9);
      case '打板数据': return const Color(0xFFEF4444); // 红色，表示打板
      case '大盘分析': return const Color(0xFFEC4899);
      case '交易概览': return const Color(0xFF6366F1);
      case '系统设置': return AppDesignSystem.lightText3;
      default: return AppDesignSystem.primary;
    }
  }
  
  // 构建侧边栏菜单项
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required Color itemColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected 
            ? itemColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 图标
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? itemColor 
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected 
                        ? Colors.white 
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // 标题
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? itemColor
                          : (isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                    ),
                  ),
                ),
                // 选中指示器
                if (isSelected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: itemColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // 构建我的备选池带数量徽标
  Widget _buildWatchlistTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: FutureBuilder<int>(
        future: WatchlistService.getWatchlistCount(),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          return ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.star_rounded,
                color: AppDesignSystem.accent,
                size: 20,
              ),
            ),
            title: const Text(
              '我的备选池',
              style: TextStyle(fontSize: 14),
            ),
            trailing: count > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                      color: AppDesignSystem.upColor,
                      borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                      count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                ),
              ),
                  )
                : null,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14),
        ),
        onTap: onTap,
      ),
    );
  }
}
