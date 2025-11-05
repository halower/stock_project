# -*- coding: utf-8 -*-
"""
ETF 配置文件
包含所有需要监控的 ETF 列表（122个）
"""

# ETF 列表 - 直接在代码中定义，避免文件读取问题
ETF_LIST = [
    {"ts_code": "560510.SH", "symbol": "560510", "name": "中证A500ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20241015"},
    {"ts_code": "510300.SH", "symbol": "510300", "name": "沪深300ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20120528"},
    {"ts_code": "510500.SH", "symbol": "510500", "name": "中证500ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20130315"},
    {"ts_code": "560010.SH", "symbol": "560010", "name": "中证1000ETF指数", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20220804"},
    {"ts_code": "159800.SZ", "symbol": "159800", "name": "中证800ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20240712"},
    {"ts_code": "510050.SH", "symbol": "510050", "name": "上证50ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20050223"},
    {"ts_code": "510180.SH", "symbol": "510180", "name": "上证180ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20060518"},
    {"ts_code": "159901.SZ", "symbol": "159901", "name": "深证100ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20060424"},
    {"ts_code": "159903.SZ", "symbol": "159903", "name": "深成ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20100202"},
    {"ts_code": "159923.SZ", "symbol": "159923", "name": "中证A100ETF基金", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20130305"},
    {"ts_code": "159915.SZ", "symbol": "159915", "name": "创业板ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20111209"},
    {"ts_code": "159949.SZ", "symbol": "159949", "name": "创业板50ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20160722"},
    {"ts_code": "159572.SZ", "symbol": "159572", "name": "创业板200ETF易方达", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20231225"},
    {"ts_code": "159782.SZ", "symbol": "159782", "name": "双创50ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210707"},
    {"ts_code": "515180.SH", "symbol": "515180", "name": "红利ETF易方达", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20191220"},
    {"ts_code": "515100.SH", "symbol": "515100", "name": "红利低波100ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20200703"},
    {"ts_code": "159717.SZ", "symbol": "159717", "name": "ESGETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210929"},
    {"ts_code": "515600.SH", "symbol": "515600", "name": "央企创新ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20191218"},
    {"ts_code": "159515.SZ", "symbol": "159515", "name": "国企红利ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230906"},
    {"ts_code": "515070.SH", "symbol": "515070", "name": "人工智能AIETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20191224"},
    {"ts_code": "515230.SH", "symbol": "515230", "name": "软件ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210302"},
    {"ts_code": "512720.SH", "symbol": "512720", "name": "计算机ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20190816"},
    {"ts_code": "562920.SH", "symbol": "562920", "name": "信息安全ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230612"},
    {"ts_code": "562030.SH", "symbol": "562030", "name": "信创ETF基金", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20231012"},
    {"ts_code": "515400.SH", "symbol": "515400", "name": "大数据ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210120"},
    {"ts_code": "516510.SH", "symbol": "516510", "name": "云计算ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210407"},
    {"ts_code": "512760.SH", "symbol": "512760", "name": "芯片ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20190612"},
    {"ts_code": "512480.SH", "symbol": "512480", "name": "半导体ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20190612"},
    {"ts_code": "562820.SH", "symbol": "562820", "name": "集成电路ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20240422"},
    {"ts_code": "561980.SH", "symbol": "561980", "name": "半导体设备ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230901"},
    {"ts_code": "562590.SH", "symbol": "562590", "name": "半导体材料ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20231018"},
    {"ts_code": "515050.SH", "symbol": "515050", "name": "5G通信ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20191016"},
    {"ts_code": "515880.SH", "symbol": "515880", "name": "通信ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20190906"},
    {"ts_code": "159583.SZ", "symbol": "159583", "name": "通信设备ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20240708"},
    {"ts_code": "563010.SH", "symbol": "563010", "name": "电信ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230713"},
    {"ts_code": "515260.SH", "symbol": "515260", "name": "电子ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20200731"},
    {"ts_code": "159732.SZ", "symbol": "159732", "name": "消费电子ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210823"},
    {"ts_code": "516330.SH", "symbol": "516330", "name": "物联网ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210409"},
    {"ts_code": "515030.SH", "symbol": "515030", "name": "新能源车ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20200304"},
    {"ts_code": "515250.SH", "symbol": "515250", "name": "智能汽车ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210108"},
    {"ts_code": "516110.SH", "symbol": "516110", "name": "汽车ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210507"},
    {"ts_code": "562700.SH", "symbol": "562700", "name": "汽车零部件ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20240514"},
    {"ts_code": "515790.SH", "symbol": "515790", "name": "光伏ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20201218"},
    {"ts_code": "159840.SZ", "symbol": "159840", "name": "锂电池ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210820"},
    {"ts_code": "159305.SZ", "symbol": "159305", "name": "储能电池ETF广发", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20240927"},
    {"ts_code": "561170.SH", "symbol": "561170", "name": "绿色电力ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230316"},
    {"ts_code": "159611.SZ", "symbol": "159611", "name": "电力ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20220107"},
    {"ts_code": "159320.SZ", "symbol": "159320", "name": "电网ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20241224"},
    {"ts_code": "560060.SH", "symbol": "560060", "name": "碳中和ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20220721"},
    {"ts_code": "512580.SH", "symbol": "512580", "name": "环保ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20170228"},
    {"ts_code": "512010.SH", "symbol": "512010", "name": "医药ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20131028"},
    {"ts_code": "159828.SZ", "symbol": "159828", "name": "医疗ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210112"},
    {"ts_code": "512290.SH", "symbol": "512290", "name": "生物医药ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20190520"},
    {"ts_code": "515120.SH", "symbol": "515120", "name": "创新药ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210104"},
    {"ts_code": "562600.SH", "symbol": "562600", "name": "医疗器械ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20231211"},
    {"ts_code": "159643.SZ", "symbol": "159643", "name": "疫苗ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20220822"},
    {"ts_code": "560080.SH", "symbol": "560080", "name": "中药ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20221017"},
    {"ts_code": "159928.SZ", "symbol": "159928", "name": "消费ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20130916"},
    {"ts_code": "515170.SH", "symbol": "515170", "name": "食品饮料ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210113"},
    {"ts_code": "512690.SH", "symbol": "512690", "name": "酒ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20190506"},
    {"ts_code": "515710.SH", "symbol": "515710", "name": "食品ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210107"},
    {"ts_code": "561120.SH", "symbol": "561120", "name": "家电ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20220215"},
    {"ts_code": "159725.SZ", "symbol": "159725", "name": "线上消费ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210702"},
    {"ts_code": "517200.SH", "symbol": "517200", "name": "互联网ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210208"},
    {"ts_code": "516550.SH", "symbol": "516550", "name": "农业ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210408"},
    {"ts_code": "516670.SH", "symbol": "516670", "name": "畜牧养殖ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210326"},
    {"ts_code": "159698.SZ", "symbol": "159698", "name": "粮食ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230818"},
    {"ts_code": "159931.SZ", "symbol": "159931", "name": "金融ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20130916"},
    {"ts_code": "512800.SH", "symbol": "512800", "name": "银行ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20170803"},
    {"ts_code": "512900.SH", "symbol": "512900", "name": "证券ETF南方", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20170331"},
    {"ts_code": "515630.SH", "symbol": "515630", "name": "保险证券ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20200403"},
    {"ts_code": "516860.SH", "symbol": "516860", "name": "金融科技ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20211011"},
    {"ts_code": "512200.SH", "symbol": "512200", "name": "房地产ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20170925"},
    {"ts_code": "516320.SH", "symbol": "516320", "name": "高端装备ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210608"},
    {"ts_code": "516800.SH", "symbol": "516800", "name": "智能制造ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210219"},
    {"ts_code": "159663.SZ", "symbol": "159663", "name": "机床ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20221026"},
    {"ts_code": "159886.SZ", "symbol": "159886", "name": "机械ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210428"},
    {"ts_code": "159542.SZ", "symbol": "159542", "name": "工程机械ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20240607"},
    {"ts_code": "562500.SH", "symbol": "562500", "name": "机器人ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20211229"},
    {"ts_code": "512660.SH", "symbol": "512660", "name": "军工ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20160808"},
    {"ts_code": "512670.SH", "symbol": "512670", "name": "国防ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20190801"},
    {"ts_code": "159267.SZ", "symbol": "159267", "name": "航天ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20250801"},
    {"ts_code": "159392.SZ", "symbol": "159392", "name": "航空ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20250514"},
    {"ts_code": "563320.SH", "symbol": "563320", "name": "通用航空ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20250903"},
    {"ts_code": "563230.SH", "symbol": "563230", "name": "卫星ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20250917"},
    {"ts_code": "516710.SH", "symbol": "516710", "name": "新材料50ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210817"},
    {"ts_code": "159713.SZ", "symbol": "159713", "name": "稀土ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210816"},
    {"ts_code": "159608.SZ", "symbol": "159608", "name": "稀有金属ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20211223"},
    {"ts_code": "512400.SH", "symbol": "512400", "name": "有色金属ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20170901"},
    {"ts_code": "515210.SH", "symbol": "515210", "name": "钢铁ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20200302"},
    {"ts_code": "515220.SH", "symbol": "515220", "name": "煤炭ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20200302"},
    {"ts_code": "516020.SH", "symbol": "516020", "name": "化工ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210308"},
    {"ts_code": "516750.SH", "symbol": "516750", "name": "建材ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20211105"},
    {"ts_code": "159697.SZ", "symbol": "159697", "name": "油气ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230504"},
    {"ts_code": "561260.SH", "symbol": "561260", "name": "能源ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230809"},
    {"ts_code": "518800.SH", "symbol": "518800", "name": "黄金基金ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20130729"},
    {"ts_code": "159271.SZ", "symbol": "159271", "name": "恒生指数ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20250811"},
    {"ts_code": "513130.SH", "symbol": "513130", "name": "恒生科技ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20210601"},
    {"ts_code": "513550.SH", "symbol": "513550", "name": "港股通50ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20210113"},
    {"ts_code": "512970.SH", "symbol": "512970", "name": "大湾区ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20191111"},
    {"ts_code": "513630.SH", "symbol": "513630", "name": "港股红利指数ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20231208"},
    {"ts_code": "513230.SH", "symbol": "513230", "name": "港股消费ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20220124"},
    {"ts_code": "513700.SH", "symbol": "513700", "name": "香港医药ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20210806"},
    {"ts_code": "513020.SH", "symbol": "513020", "name": "港股科技ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20220208"},
    {"ts_code": "513770.SH", "symbol": "513770", "name": "港股互联网ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20220218"},
    {"ts_code": "513120.SH", "symbol": "513120", "name": "港股创新药ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20220712"},
    {"ts_code": "513100.SH", "symbol": "513100", "name": "纳指ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20130515"},
    {"ts_code": "513650.SH", "symbol": "513650", "name": "标普500ETF南方", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20230404"},
    {"ts_code": "513850.SH", "symbol": "513850", "name": "美国50ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20231117"},
    {"ts_code": "513880.SH", "symbol": "513880", "name": "日经225ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20190625"},
    {"ts_code": "159561.SZ", "symbol": "159561", "name": "德国ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20240430"},
    {"ts_code": "513080.SH", "symbol": "513080", "name": "法国CAC40ETF", "area": "", "industry": "T+0交易", "market": "ETF", "list_date": "20200612"},
    {"ts_code": "515150.SH", "symbol": "515150", "name": "一带一路ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20200115"},
    {"ts_code": "512980.SH", "symbol": "512980", "name": "传媒ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20180119"},
    {"ts_code": "516010.SH", "symbol": "516010", "name": "游戏ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210305"},
    {"ts_code": "516620.SH", "symbol": "516620", "name": "影视ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20211105"},
    {"ts_code": "562510.SH", "symbol": "562510", "name": "旅游ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20211230"},
    {"ts_code": "516910.SH", "symbol": "516910", "name": "物流ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20210611"},
    {"ts_code": "159666.SZ", "symbol": "159666", "name": "交通运输ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20230213"},
    {"ts_code": "560800.SH", "symbol": "560800", "name": "数字经济ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20220107"},
    {"ts_code": "159399.SZ", "symbol": "159399", "name": "现金流ETF", "area": "", "industry": "T+1交易", "market": "ETF", "list_date": "20250227"},
]


def get_etf_list():
    """
    获取 ETF 列表
    
    Returns:
        List[Dict]: ETF 列表，每个 ETF 包含以下字段：
            - ts_code: Tushare 代码
            - symbol: 股票代码
            - name: ETF 名称
            - area: 地域（ETF 为空）
            - industry: T+0交易 或 T+1交易
            - market: ETF（固定值）
            - list_date: 上市日期
    """
    return ETF_LIST.copy()


def get_etf_count():
    """获取 ETF 数量"""
    return len(ETF_LIST)


def get_etf_by_code(ts_code: str):
    """
    根据代码获取 ETF 信息
    
    Args:
        ts_code: ETF 代码（如 510300.SH）
        
    Returns:
        Dict or None: ETF 信息，如果不存在返回 None
    """
    for etf in ETF_LIST:
        if etf['ts_code'] == ts_code:
            return etf.copy()
    return None


def is_etf_in_list(ts_code: str):
    """
    判断是否在 ETF 列表中
    
    Args:
        ts_code: ETF 代码
        
    Returns:
        bool: 是否在列表中
    """
    return any(etf['ts_code'] == ts_code for etf in ETF_LIST)

