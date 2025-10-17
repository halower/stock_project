class StockDetailedInfo {
  final Map<String, dynamic> basicInfo;
  final Map<String, dynamic> technicalIndicators;
  final Map<String, dynamic> financialInfo;
  final List<NewsItem> news;

  StockDetailedInfo({
    required this.basicInfo,
    required this.technicalIndicators,
    required this.financialInfo,
    required this.news,
  });

  factory StockDetailedInfo.fromJson(Map<String, dynamic> json) {
    List<NewsItem> newsItems = [];
    if (json['新闻资讯'] != null) {
      newsItems = List<NewsItem>.from(
        (json['新闻资讯'] as List).map((item) => NewsItem.fromJson(item)),
      );
    }

    return StockDetailedInfo(
      basicInfo: json['基本信息'] ?? {},
      technicalIndicators: json['技术指标'] ?? {},
      financialInfo: json['财务信息'] ?? {},
      news: newsItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '基本信息': basicInfo,
      '技术指标': technicalIndicators,
      '财务信息': financialInfo,
      '新闻资讯': news.map((item) => item.toJson()).toList(),
    };
  }
}

class NewsItem {
  final String keyword;
  final String title;
  final String content;
  final String publishTime;
  final String source;
  final String url;

  NewsItem({
    required this.keyword,
    required this.title,
    required this.content,
    required this.publishTime,
    required this.source,
    required this.url,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      keyword: json['关键词'] ?? '',
      title: json['新闻标题'] ?? '',
      content: json['新闻内容'] ?? '',
      publishTime: json['发布时间'] ?? '',
      source: json['文章来源'] ?? '',
      url: json['新闻链接'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '关键词': keyword,
      '新闻标题': title,
      '新闻内容': content,
      '发布时间': publishTime,
      '文章来源': source,
      '新闻链接': url,
    };
  }
} 