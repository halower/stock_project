import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/html_to_markdown_service.dart';
import '../screens/news_web_view_screen.dart';

class NewsMarkdownViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? summary;

  const NewsMarkdownViewScreen({
    Key? key,
    required this.url,
    required this.title,
    this.summary,
  }) : super(key: key);

  @override
  State<NewsMarkdownViewScreen> createState() => _NewsMarkdownViewScreenState();
}

class _NewsMarkdownViewScreenState extends State<NewsMarkdownViewScreen> {
  String _markdownContent = '';
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAndConvertContent();
  }

  Future<void> _loadAndConvertContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 获取HTML内容
      final response = await http.get(
        Uri.parse(widget.url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        },
      );

      if (response.statusCode == 200) {
        // 转换为Markdown
        final markdown = HtmlToMarkdownService.convertToMarkdown(
          response.body,
          baseUrl: widget.url,
        );

        setState(() {
          _markdownContent = markdown;
          _isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}: 无法加载页面内容');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openInBrowser() async {
    final Uri uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3748),
        elevation: 0,
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAndConvertContent,
            tooltip: '重新加载',
          ),
          // 在浏览器中打开
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: '在浏览器中打开',
          ),
          // 更多选项
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'original':
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewsWebViewScreen(
                        url: widget.url,
                        title: widget.title,
                      ),
                    ),
                  );
                  break;
                case 'share':
                  // TODO: 实现分享功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享功能开发中...')),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'original',
                child: Row(
                  children: [
                    Icon(Icons.web, size: 20),
                    SizedBox(width: 8),
                    Text('查看原网页'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('分享'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2F80ED)),
            ),
            SizedBox(height: 16),
            Text(
              '正在加载并转换内容...',
              style: TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '内容加载失败',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadAndConvertContent,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重试'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F80ED),
                      side: const BorderSide(color: Color(0xFF2F80ED)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: const Text('浏览器打开'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F80ED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_markdownContent.isEmpty) {
      return const Center(
        child: Text(
          '暂无内容',
          style: TextStyle(
            color: Color(0xFF718096),
            fontSize: 16,
          ),
        ),
      );
    }

    // 直接显示Markdown内容，移除提示条
    return Markdown(
      data: _markdownContent,
      selectable: true,
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
        ],
      ),
      onTapLink: (text, href, title) async {
        if (href != null) {
          final Uri uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      styleSheet: MarkdownStyleSheet(
        // 标题样式
        h1: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3748),
          height: 1.4,
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3748),
          height: 1.4,
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A5568),
          height: 1.3,
        ),
        h4: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A5568),
          height: 1.3,
        ),
        
        // 正文样式
        p: const TextStyle(
          fontSize: 16,
          color: Color(0xFF2D3748),
          height: 1.6,
        ),
        
        // 强调样式
        strong: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3748),
        ),
        em: const TextStyle(
          fontStyle: FontStyle.italic,
          color: Color(0xFF4A5568),
        ),
        
        // 链接样式
        a: const TextStyle(
          color: Color(0xFF2F80ED),
          decoration: TextDecoration.underline,
        ),
        
        // 引用样式
        blockquote: const TextStyle(
          fontSize: 15,
          color: Color(0xFF718096),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(
              color: Color(0xFF2F80ED),
              width: 4,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.all(16),
        
        // 代码样式
        code: TextStyle(
          fontSize: 14,
          color: const Color(0xFFE53E3E),
          backgroundColor: Colors.grey.shade100,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        
        // 列表样式
        listBullet: const TextStyle(
          fontSize: 16,
          color: Color(0xFF2F80ED),
        ),
        
        // 分割线样式
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              width: 1.0,
              color: Colors.grey.shade300,
            ),
          ),
        ),
        
        // 表格样式
        tableHead: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3748),
        ),
        tableBody: const TextStyle(
          color: Color(0xFF4A5568),
        ),
        tableBorder: TableBorder.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        tableCellsPadding: const EdgeInsets.all(12),
        tableHeadAlign: TextAlign.center,
      ),
      padding: const EdgeInsets.all(16),
    );
  }
} 