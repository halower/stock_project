import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class HtmlToMarkdownService {
  // 广告相关的CSS选择器和关键词
  static const List<String> _adSelectors = [
    '.ad',
    '.ads',
    '.advertisement',
    '.banner',
    '.sponsor',
    '.promotion',
    '.popup',
    '.overlay',
    '.sidebar',
    '.footer',
    '.header-ad',
    '.bottom-ad',
    '.side-ad',
    '.google-ad',
    '.baidu-ad',
    '.tencent-ad',
    '.ali-ad',
    '[class*="ad-"]',
    '[class*="ads-"]',
    '[id*="ad-"]',
    '[id*="ads-"]',
    'iframe[src*="ad"]',
    'iframe[src*="ads"]',
    'script[src*="ad"]',
    'script[src*="ads"]',
  ];

  static const List<String> _adKeywords = [
    '广告',
    '推广',
    '赞助',
    '合作',
    '投放',
    'advertisement',
    'sponsored',
    'promotion',
    'banner',
    '点击查看',
    '立即购买',
    '马上下载',
    '免费试用',
    '限时优惠',
    '特价',
    '折扣',
    '返现',
    '红包',
    '优惠券',
  ];

  static const List<String> _unwantedTags = [
    'script',
    'style',
    'noscript',
    'iframe',
    'embed',
    'object',
    'applet',
    'form',
    'input',
    'button',
    'select',
    'textarea',
  ];

  /// 将HTML内容转换为清洁的Markdown
  static String convertToMarkdown(String htmlContent, {String? baseUrl}) {
    try {
      // 解析HTML
      final document = html_parser.parse(htmlContent);
      
      // 激进清理文档 - 移除所有非正文元素
      _aggressiveCleanDocument(document);
      
      // 提取主要内容
      final mainContent = _extractMainContent(document);
      
      if (mainContent == null || mainContent.text.trim().isEmpty) {
        return '内容解析失败，请访问原文链接查看完整内容。';
      }
      
      // 提取纯文本内容，移除所有链接和格式
      final pureText = _extractPureTextContent(mainContent);
      
      if (pureText.trim().length < 10) {
        return '内容解析失败，请访问原文链接查看完整内容。';
      }
      
      // 转换为简洁的Markdown格式
      String markdown = _convertToCleanMarkdown(pureText);
      
      return markdown;
    } catch (e) {
      return '内容解析失败，请访问原文链接查看完整内容。';
    }
  }

  /// 激进清理HTML文档，只保留正文相关元素
  static void _aggressiveCleanDocument(dom.Document document) {
    // 移除所有脚本、样式、表单等
    for (final tag in _unwantedTags) {
      document.querySelectorAll(tag).forEach((element) {
        element.remove();
      });
    }

    // 移除所有导航相关元素
    final navSelectors = [
      'nav', 'header', 'footer', 'aside', 'menu',
      '.nav', '.navigation', '.navbar', '.menu', '.sidebar',
      '.breadcrumb', '.pagination', '.share', '.social',
      '.comment', '.comments', '.related', '.recommend',
      '.hot', '.popular', '.tags', '.category', '.meta',
      '.toolbar', '.action', '.widget', '.module',
      '[class*="nav-"]', '[class*="menu-"]', '[class*="sidebar-"]',
      '[id*="nav"]', '[id*="menu"]', '[id*="sidebar"]',
      '[id*="footer"]', '[id*="header"]'
    ];

    for (final selector in navSelectors) {
      try {
        document.querySelectorAll(selector).forEach((element) {
          // 如果元素包含表格，保留表格部分
          final tables = element.querySelectorAll('table');
          if (tables.isNotEmpty) {
            // 将表格移到父元素中，然后删除导航容器
            final parent = element.parent;
            if (parent != null) {
              for (final table in tables) {
                parent.insertBefore(table, element);
              }
            }
          }
          element.remove();
        });
      } catch (e) {
        // 忽略无效选择器
      }
    }

    // 移除所有广告元素
    for (final selector in _adSelectors) {
      try {
        document.querySelectorAll(selector).forEach((element) {
          element.remove();
        });
      } catch (e) {
        // 忽略无效选择器
      }
    }

    // 移除包含大量链接的容器（通常是导航或推荐区域），但保留表格
    document.querySelectorAll('div, section, ul, ol').forEach((element) {
      final links = element.querySelectorAll('a');
      final text = element.text.trim();
      final tables = element.querySelectorAll('table');
      
      // 如果包含表格，不删除
      if (tables.isNotEmpty) {
        return;
      }
      
      // 如果链接数量过多，文本密度低，移除整个容器
      if (links.length >= 5 && text.length < links.length * 25) {
        element.remove();
      }
    });

    // 移除所有链接元素，只保留链接文本，但不影响表格内的链接
    document.querySelectorAll('a').forEach((link) {
      // 检查链接是否在表格内
      dom.Element? parent = link.parent;
      bool inTable = false;
      while (parent != null) {
        if (parent.localName == 'table' || parent.localName == 'td' || parent.localName == 'th') {
          inTable = true;
          break;
        }
        parent = parent.parent;
      }
      
      // 如果在表格内，保留链接文本
      if (inTable) {
        final linkText = link.text.trim();
        if (linkText.isNotEmpty) {
          final textNode = dom.Text(linkText);
          link.replaceWith(textNode);
        } else {
          link.remove();
        }
        return;
      }
      
      final linkText = link.text.trim();
      // 如果链接文本很短或包含导航关键词，直接移除
      if (linkText.length <= 15 || _isNavigationText(linkText)) {
        link.remove();
      } else {
        // 保留链接文本，但移除链接标签
        final textNode = dom.Text(linkText);
        link.replaceWith(textNode);
      }
    });

    // 移除空元素，但保留表格相关元素
    document.querySelectorAll('*').forEach((element) {
      if (element.text.trim().isEmpty && 
          element.children.isEmpty && 
          !['img', 'br', 'hr', 'table', 'tr', 'td', 'th'].contains(element.localName)) {
        element.remove();
      }
    });
  }

  /// 检查文本是否是导航相关
  static bool _isNavigationText(String text) {
    final lowerText = text.toLowerCase().trim();
    
    // 如果文本太长，不太可能是导航
    if (text.length > 100) {
      return false;
    }
    
    final navKeywords = [
      '首页', '主页', '返回', '上一页', '下一页',
      '分类', '栏目', '登录', '注册', '用户', '设置',
      'home', 'back', 'login', 'register', 'menu',
      '>', '<', '»', '«', '→', '←', '点击', '查看更多',
      // 社交分享相关
      '微信', '朋友圈', '分享', '扫一扫', '微博', 'qq', 'qzone',
      '微信扫一扫','分享到您的', '提示：', '手机上阅读文章','一手掌握市场脉搏',
      '专业，丰富','方便，快捷','手机查看财经快讯','东方财富APP','小 中 大',
      '分享到', '收藏', '关注', '订阅', '评论', '点赞',
      '转发', '复制链接', '打印', '下载', '保存',
      'wechat', 'weibo', 'share', 'follow', 'subscribe',
      'like', 'comment', 'forward', 'copy', 'download', 'save'
    ];
    
    // 只检查短文本中的导航关键词
    for (final keyword in navKeywords) {
      if (lowerText == keyword || lowerText.startsWith('$keyword ') || lowerText.endsWith(' $keyword')) {
        return true;
      }
    }
    
    // 纯数字通常是分页导航
    if (RegExp(r'^\d+$').hasMatch(text.trim())) {
      return true;
    }
    
    return false;
  }

  /// 提取纯文本内容
  static String _extractPureTextContent(dom.Element element) {
    final buffer = StringBuffer();
    
    // 遍历所有文本节点和段落
    _extractTextFromElement(element, buffer);
    
    // 恢复数字格式
    String result = buffer.toString();
    result = result.replaceAll('DECIMALPOINT', '.');
    
    return result;
  }

  /// 递归提取元素中的文本内容
  static void _extractTextFromElement(dom.Element element, StringBuffer buffer) {
    for (final node in element.nodes) {
      if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) {
          buffer.write(text);
          buffer.write(' ');
        }
      } else if (node is dom.Element) {
        final tagName = node.localName?.toLowerCase();
        
        // 处理表格
        if (tagName == 'table') {
          _extractTableContent(node, buffer);
        }
        // 处理段落和标题，添加换行
        else if (['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'br'].contains(tagName)) {
          _extractTextFromElement(node, buffer);
          buffer.write('\n\n');
        } 
        // 处理列表项
        else if (tagName == 'li') {
          buffer.write('• ');
          _extractTextFromElement(node, buffer);
          buffer.write('\n');
        }
        // 其他元素继续递归
        else {
          _extractTextFromElement(node, buffer);
        }
      }
    }
  }

  /// 提取表格内容并转换为Markdown格式
  static void _extractTableContent(dom.Element table, StringBuffer buffer) {
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) return;

    // 先收集所有行的数据
    final tableData = <List<String>>[];
    int maxColumns = 0;
    
    for (final row in rows) {
      final cells = row.querySelectorAll('td, th');
      final rowData = <String>[];
      
      for (final cell in cells) {
        String cellText = cell.text.trim().replaceAll('\n', ' ').replaceAll('|', '\\|');
        // 保护数字格式
        cellText = cellText.replaceAllMapped(RegExp(r'(\d)\.(\d)'), (match) {
          return '${match.group(1)!}DECIMALPOINT${match.group(2)!}';
        });
        rowData.add(cellText.isEmpty ? ' ' : cellText);
      }
      
      if (rowData.isNotEmpty) {
        tableData.add(rowData);
        maxColumns = maxColumns > rowData.length ? maxColumns : rowData.length;
      }
    }
    
    if (tableData.isEmpty) return;
    
    // 确保所有行都有相同的列数
    for (final row in tableData) {
      while (row.length < maxColumns) {
        row.add(' ');
      }
    }
    
    // 生成表格 - 修复格式，确保行连续
    buffer.write('\n\n'); // 表格前空行
    
    for (int i = 0; i < tableData.length; i++) {
      final row = tableData[i];
      
      // 构建表格行
      buffer.write('| ${row.join(' | ')} |');
      
      // 如果是第一行（表头），添加分隔线
      if (i == 0) {
        buffer.write('\n');
        buffer.write('|');
        for (int j = 0; j < maxColumns; j++) {
          buffer.write(' --- |');
        }
      }
      
      buffer.write('\n');
    }
    
    buffer.write('\n'); // 表格后空行
  }

  /// 将纯文本转换为简洁的Markdown
  static String _convertToCleanMarkdown(String text) {
    // 清理多余的空白，但保护换行和数字格式
    text = text.replaceAll(RegExp(r'[ \t]+'), ' '); // 只合并空格和制表符
    text = text.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n'); // 合并多个空行
    
    // 先保护小数点，避免被当作句号处理
    text = text.replaceAllMapped(RegExp(r'(\d)\.(\d)'), (match) {
      return '${match.group(1)!}DECIMALPOINT${match.group(2)!}';
    });
    
    // 按行分割，保持原有的换行结构
    final lines = text.split('\n');
    final result = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      // 过滤明显的广告或导航文本
      if (_isAdvertisementText(line) || _isNavigationText(line)) {
        continue;
      }
      
      // 检查是否是表格行
      final isTableRow = line.startsWith('|') && line.endsWith('|');
      
      if (isTableRow) {
        // 表格行直接添加，不添加额外空行
        result.add(line);
      } else {
        // 非表格行，如果前一行不是表格行，添加空行分隔
        if (result.isNotEmpty && !result.last.startsWith('|')) {
          result.add('');
        }
        result.add(line);
      }
    }
    
    if (result.isEmpty) {
      return '内容解析失败，请访问原文链接查看完整内容。';
    }
    
    // 恢复小数点
    String finalResult = result.join('\n');
    finalResult = finalResult.replaceAll('DECIMALPOINT', '.');
    
    return finalResult;
  }

  /// 检查是否是广告文本
  static bool _isAdvertisementText(String text) {
    final lowerText = text.toLowerCase();
    
    // 只检查明显的广告关键词，不检查价格
    final adKeywords = [
      '广告', '推广', '赞助', '合作', '联系我们', '客服',
      'advertisement', 'ad', 'sponsor', 'promotion'
    ];
    
    for (final keyword in adKeywords) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  /// 提取主要内容 - 简化算法
  static dom.Element? _extractMainContent(dom.Document document) {
    // 优先级1: 尝试常见的正文内容选择器
    final primaryContentSelectors = [
      'article',
      '.article',
      '.article-content',
      '.post-content',
      '.entry-content',
      '.news-content',
      '.content-body',
      '.main-content',
      '.text-content',
      '.detail-content',
      '.story-content',
      '.article-body',
      '#article-content',
      '#post-content',
      '#main-content',
    ];

    for (final selector in primaryContentSelectors) {
      try {
        final element = document.querySelector(selector);
        if (element != null && element.text.trim().length > 100) {
          return element;
        }
      } catch (e) {
        // 忽略无效的选择器
      }
    }

    // 优先级2: 尝试通用内容选择器
    final secondaryContentSelectors = [
      '.content',
      '#content',
      '#main',
      '#article',
      'main',
      '.container .content',
      '.wrapper .content',
    ];

    for (final selector in secondaryContentSelectors) {
      try {
        final element = document.querySelector(selector);
        if (element != null && element.text.trim().length > 100) {
          return element;
        }
      } catch (e) {
        // 忽略无效的选择器
      }
    }

    // 优先级3: 查找最大的文本块
    dom.Element? bestElement;
    int maxTextLength = 0;

    document.querySelectorAll('div, section, article, main').forEach((element) {
      final textLength = element.text.trim().length;
      if (textLength > maxTextLength && textLength > 200) {
        maxTextLength = textLength;
        bestElement = element;
      }
    });

    if (bestElement != null) {
      return bestElement;
    }

    return document.body;
  }

  /// 检查内容是否主要是广告
  static bool isMainlyAdvertisement(String content) {
    final text = content.toLowerCase();
    int adKeywordCount = 0;
    
    for (final keyword in _adKeywords) {
      if (text.contains(keyword)) {
        adKeywordCount++;
      }
    }
    
    // 如果广告关键词占比过高，认为主要是广告
    return adKeywordCount > 3 && content.length < 500;
  }

  /// 提取文章摘要
  static String extractSummary(String markdown, {int maxLength = 200}) {
    // 移除Markdown格式
    String text = markdown
        .replaceAll(RegExp(r'#+\s*'), '') // 移除标题标记
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // 移除粗体标记
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // 移除斜体标记
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1') // 移除链接，保留文本
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '') // 移除图片
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // 移除代码标记
        .replaceAll(RegExp(r'\n+'), ' ') // 将换行替换为空格
        .trim();

    if (text.length <= maxLength) {
      return text;
    }

    // 在合适的位置截断
    int cutIndex = maxLength;
    for (int i = maxLength; i > maxLength - 50 && i > 0; i--) {
      if (text[i] == '。' || text[i] == '！' || text[i] == '？' || 
          text[i] == '.' || text[i] == '!' || text[i] == '?') {
        cutIndex = i + 1;
        break;
      }
    }

    return '${text.substring(0, cutIndex)}...';
  }
} 