import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import '../../utils/design_system.dart';

class ThemeProvider with ChangeNotifier {
  // 使用设计系统的颜色
  static const Color _primaryColor = AppDesignSystem.primary;
  static const Color _upColor = AppDesignSystem.upColor;      // A股红色(上涨)
  static const Color _downColor = AppDesignSystem.downColor;  // A股绿色(下跌)
  
  late ThemeData _lightTheme;
  late ThemeData _darkTheme;
  bool _isDarkMode = false; // 默认使用明亮模式
  String _fontFamily = 'System Default';
  double _fontSize = 1.0;
  
  ThemeProvider() {
    _initThemes();
    _loadSettings();
  }
  
  void _initThemes() {
    // 亮色主题
    _lightTheme = _createTheme(false);
    
    // 暗色主题
    _darkTheme = _createTheme(true);
  }
  
  ThemeData get themeData => _isDarkMode ? _darkTheme : _lightTheme;
  bool get isDarkMode => _isDarkMode;
  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  
  // 获取涨跌颜色
  Color get upColor => _upColor;    // 上涨(红色)
  Color get downColor => _downColor; // 下跌(绿色)
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isDarkMode = prefs.getBool('darkMode') ?? false; // 默认明亮模式
      _fontFamily = prefs.getString('fontFamily') ?? 'System Default';
      _fontSize = prefs.getDouble('fontSize') ?? 1.0;
      
      // 重新初始化主题以应用设置
      _initThemes();
      notifyListeners();
      print('主题设置已加载: 暗色模式=$_isDarkMode');
    } catch (e) {
      print('加载主题设置时出错: $e');
    }
  }
  
  // 修复暗色模式切换问题
  Future<void> setDarkMode(bool isDarkMode) async {
    if (_isDarkMode == isDarkMode) return; // 如果状态没变，直接返回
    
    try {
      _isDarkMode = isDarkMode; // 先设置状态
      _initThemes(); // 重新创建主题
      notifyListeners(); // 通知UI更新
      
      // 然后保存到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', isDarkMode);
      
      print('暗色模式已${isDarkMode ? "开启" : "关闭"}');
    } catch (e) {
      print('设置暗色模式出错: $e');
    }
  }
  
  // 简化设置方法，不再包含主题颜色选择
  Future<void> setTheme(bool isDarkMode, String fontFamily, double fontSize) async {
    try {
      // 先更新内存中的值
      _isDarkMode = isDarkMode;
      _fontFamily = fontFamily;
      _fontSize = fontSize;
      
      // 重新创建主题
      _initThemes();
      
      // 通知UI更新
      notifyListeners();
      
      // 然后保存到持久化存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', isDarkMode);
      await prefs.setString('fontFamily', fontFamily);
      await prefs.setDouble('fontSize', fontSize);
      
      print('主题设置已更新: 暗色模式=$_isDarkMode, 字体=$_fontFamily, 字号=$_fontSize');
    } catch (e) {
      print('保存主题设置时出错: $e');
    }
  }
  
  ThemeData _createTheme(bool isDark) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    
    // 使用设计系统的颜色
    final ColorScheme colorScheme = isDark
        ? ColorScheme.dark(
            primary: _primaryColor,
            secondary: AppDesignSystem.accent,
            tertiary: AppDesignSystem.techGradient.colors.first,
            surface: AppDesignSystem.darkBg2,
            onSurface: AppDesignSystem.darkText1,
            onPrimary: Colors.white,
            onSecondary: AppDesignSystem.darkBg1,
            error: _upColor,
            onError: Colors.white,
            surfaceContainerHighest: AppDesignSystem.darkBg3,
            onSurfaceVariant: AppDesignSystem.darkText2,
            outline: AppDesignSystem.darkBorder1,
          )
        : ColorScheme.light(
            primary: _primaryColor,
            secondary: AppDesignSystem.accent,
            tertiary: AppDesignSystem.techGradient.colors.first,
            surface: AppDesignSystem.lightBg2,
            onSurface: AppDesignSystem.lightText1,
            onPrimary: Colors.white,
            onSecondary: AppDesignSystem.lightText1,
            error: _upColor,
            onError: Colors.white,
            surfaceContainerHighest: AppDesignSystem.lightBg3,
            onSurfaceVariant: AppDesignSystem.lightText2,
            outline: AppDesignSystem.lightBorder1,
          );
    
    // 文本主题
    final textTheme = _getAdjustedTextTheme(brightness);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? AppDesignSystem.darkBg1 : AppDesignSystem.lightBg1,
      fontFamily: _getFontFamily(),
      textTheme: textTheme,
      primaryColor: _primaryColor,
      
      // AppBar主题 - 现代透明效果
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18 * _fontSize,
          fontWeight: FontWeight.w700,
          fontFamily: _getFontFamily(),
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: 24,
        ),
      ),
      
      // 卡片主题 - 现代玻璃态风格
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          side: BorderSide(
            color: isDark 
                ? AppDesignSystem.darkBorder1.withOpacity(0.5)
                : AppDesignSystem.lightBorder1.withOpacity(0.8),
            width: 1,
          ),
        ),
        color: isDark ? AppDesignSystem.darkBg3 : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: AppDesignSystem.space6, horizontal: 0),
        shadowColor: isDark ? Colors.black54 : Colors.black12,
      ),
      
      // 按钮主题 - 现代渐变效果
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: _primaryColor.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.space24, vertical: AppDesignSystem.space12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15 * _fontSize,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // 文字按钮主题
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.space16, vertical: AppDesignSystem.space8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14 * _fontSize,
          ),
        ),
      ),
      
      // 输入框主题 - 现代风格
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark 
            ? AppDesignSystem.darkBg3.withOpacity(0.5)
            : AppDesignSystem.lightBg3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: BorderSide(
            color: isDark 
                ? AppDesignSystem.darkBorder1.withOpacity(0.5)
                : AppDesignSystem.lightBorder1,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: BorderSide(
            color: isDark 
                ? AppDesignSystem.darkBorder1.withOpacity(0.5)
                : AppDesignSystem.lightBorder1,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: BorderSide(
            color: _primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          borderSide: BorderSide(
            color: _upColor,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.space16, vertical: AppDesignSystem.space16),
        hintStyle: TextStyle(
          color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
        ),
        labelStyle: TextStyle(
          color: isDark ? AppDesignSystem.darkText2 : AppDesignSystem.lightText2,
        ),
      ),
      
      // NavigationBar主题 - 现代浮动效果
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 70,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _primaryColor.withOpacity(0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11 * _fontSize,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            );
          }
          return TextStyle(
            fontSize: 11 * _fontSize,
            fontWeight: FontWeight.w500,
            color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: _primaryColor,
              size: 24,
            );
          }
          return IconThemeData(
            color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
            size: 24,
          );
        }),
      ),
      
      // 分割线主题
      dividerTheme: DividerThemeData(
        color: isDark 
            ? AppDesignSystem.darkBorder1.withOpacity(0.5)
            : AppDesignSystem.lightBorder1,
        thickness: 1,
        space: 1,
      ),
      
      // 切换开关主题
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText4;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return isDark ? AppDesignSystem.darkBg4 : AppDesignSystem.lightBg4;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return Colors.transparent;
        }),
      ),
      
      // 芯片主题
      chipTheme: ChipThemeData(
        backgroundColor: isDark 
            ? AppDesignSystem.darkBg3 
            : AppDesignSystem.lightBg3,
        selectedColor: _primaryColor.withOpacity(0.15),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.space12, vertical: AppDesignSystem.space6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        ),
        side: BorderSide(
          color: isDark 
              ? AppDesignSystem.darkBorder1.withOpacity(0.5)
              : AppDesignSystem.lightBorder1,
        ),
      ),
      
      // 底部弹出框主题
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppDesignSystem.darkBg2 : Colors.white,
        modalBackgroundColor: isDark ? AppDesignSystem.darkBg2 : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppDesignSystem.radiusXl),
            topRight: Radius.circular(AppDesignSystem.radiusXl),
          ),
        ),
        elevation: 0,
      ),
      
      // 对话框主题
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppDesignSystem.darkBg2 : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusXl),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20 * _fontSize,
          fontWeight: FontWeight.w700,
          color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
        ),
      ),
      
      // 浮动操作按钮主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
        ),
      ),
      
      // 列表磁贴主题
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space16,
          vertical: AppDesignSystem.space4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
        ),
        selectedTileColor: _primaryColor.withOpacity(0.1),
        selectedColor: _primaryColor,
      ),
      
      // 页面过渡动画
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
  
  String? _getFontFamily() {
    if (_fontFamily == 'System Default') {
      return null;
    }
    
    // 使用Google Fonts支持的字体
    try {
      switch (_fontFamily) {
        case 'Noto Sans SC':
          // 使用getFont方法获取Noto Sans SC，如果不可用则回退
          return GoogleFonts.getFont('Noto Sans SC').fontFamily;
        case 'Noto Serif SC':
          // 使用getFont方法获取Noto Serif SC，如果不可用则回退
          return GoogleFonts.getFont('Noto Serif SC').fontFamily;
        case 'PingFang SC':
          // PingFang SC是苹果系统字体，回退到系统字体
          return null;
        case 'Microsoft YaHei':
          // 微软雅黑回退到系统字体
          return null;
        case 'SimHei':
          // 黑体回退到系统字体
          return null;
        case 'SimSun':
          // 宋体回退到系统字体
          return null;
        case 'Roboto':
          return GoogleFonts.roboto().fontFamily;
        case 'Open Sans':
          return GoogleFonts.openSans().fontFamily;
        case 'Lato':
          return GoogleFonts.lato().fontFamily;
        default:
          return _fontFamily;
      }
    } catch (e) {
      // 如果字体加载失败，回退到系统默认字体
      debugPrint('字体加载失败: $_fontFamily, 错误: $e');
      return null;
    }
  }
  
  TextTheme _getAdjustedTextTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    
    // 基本文本主题
    final baseTextTheme = isLight
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    
    // 文本颜色
    final primaryTextColor = isLight ? Colors.black : Colors.white;
    final secondaryTextColor = isLight 
        ? Colors.black.withOpacity(0.6) 
        : Colors.white.withOpacity(0.7);
    
    // 调整字体大小
    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 32 * _fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 24 * _fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 18 * _fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 16 * _fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 18 * _fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16 * _fontSize,
        fontWeight: FontWeight.w600,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 14 * _fontSize,
        fontWeight: FontWeight.w600,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16 * _fontSize,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14 * _fontSize,
        fontFamily: _getFontFamily(),
        color: primaryTextColor,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12 * _fontSize,
        fontFamily: _getFontFamily(),
        color: secondaryTextColor,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14 * _fontSize,
        fontWeight: FontWeight.w500,
        fontFamily: _getFontFamily(),
        color: secondaryTextColor,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12 * _fontSize,
        fontWeight: FontWeight.w500,
        fontFamily: _getFontFamily(),
        color: secondaryTextColor,
      ),
    );
  }
} 