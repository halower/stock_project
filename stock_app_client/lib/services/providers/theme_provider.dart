import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';

class ThemeProvider with ChangeNotifier {
  // 固定主题颜色
  static const Color _primaryColor = Color(0xFF2F80ED); // 固定使用蓝色，不再允许修改
  static const Color _upColor = Color(0xFFE64A19);      // 更柔和的橙红色(上涨)，替换刺眼的红色
  static const Color _downColor = Color(0xFF26A69A);    // 更柔和的青绿色(下跌)
  static const Color _darkBackground = Color(0xFF121212); // 深色背景
  static const Color _darkSurface = Color(0xFF1E1E1E);    // 深色表面
  
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
    
    // 基本配色
    final ColorScheme colorScheme = isDark
        ? ColorScheme.dark(
            primary: _primaryColor,
            secondary: _primaryColor.withOpacity(0.8),
            surface: _darkSurface,
            onSurface: Colors.white,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            error: _upColor,
            onError: Colors.white,
            surfaceContainerHighest: const Color(0xFF2C2C2C),
            onSurfaceVariant: Colors.white70,
            outline: Colors.white38,
          )
        : ColorScheme.light(
            primary: _primaryColor,
            secondary: _primaryColor.withOpacity(0.8),
            surface: Colors.white,
            onSurface: Colors.black,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            error: _upColor,
            onError: Colors.white,
            surfaceContainerHighest: Colors.grey[200]!,
            onSurfaceVariant: Colors.black54,
            outline: Colors.black26,
          );
    
    // 文本主题
    final textTheme = _getAdjustedTextTheme(brightness);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: _getFontFamily(),
      textTheme: textTheme,
      primaryColor: _primaryColor, // 确保旧组件也使用正确的颜色
      
      // AppBar主题
      appBarTheme: AppBarTheme(
        elevation: 0,
        color: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18 * _fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: _getFontFamily(),
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
        ),
      ),
      
      // 卡片主题
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.1) 
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        color: colorScheme.surface,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      
      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark 
            ? colorScheme.surface 
            : colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _primaryColor,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: _primaryColor,
        unselectedItemColor: isDark 
            ? Colors.white.withOpacity(0.5) 
            : Colors.black.withOpacity(0.5),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // 分割线主题
      dividerTheme: DividerThemeData(
        color: isDark 
            ? Colors.white.withOpacity(0.1) 
            : Colors.black.withOpacity(0.1),
        thickness: 1,
        space: 1,
      ),
      
      // 切换开关主题
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return isDark ? Colors.grey[400] : Colors.grey[50];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor.withOpacity(0.5);
          }
          return isDark ? Colors.grey[800] : Colors.grey[300];
        }),
      ),
      
      // 芯片主题
      chipTheme: ChipThemeData(
        backgroundColor: isDark 
            ? colorScheme.surface 
            : colorScheme.surface,
        selectedColor: _primaryColor.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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