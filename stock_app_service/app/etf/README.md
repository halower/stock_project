# ETF 数据说明

## 📊 数据概览

- **总数**: 1220 个可交易 ETF
- **T+0 交易**: 159 个（跨境、债券、黄金、货币、QDII、港股/美股）
- **T+1 交易**: 1061 个（A股市场 ETF）
- **数据来源**: Tushare
- **更新时间**: 2025-10-16

## 🎯 筛选标准

### ✅ 包含的 ETF
1. **场内交易 ETF**
   - 上交所: 51xxxx, 56xxxx 开头
   - 深交所: 15xxxx, 16xxxx 开头

2. **可在同花顺交易**
   - 支持 T+0 交易
   - 流动性好
   - 散户可直接买卖

### ❌ 排除的基金
1. **不可交易代码** (459 个) - 非场内交易代码
2. **LOF 基金** (389 个) - 场外基金，不是纯 ETF
3. **分级基金** (242 个) - 如军工A/B、证券A/B等，已退市或不能交易
4. **债券 ETF** (76 个) - 散户一般不交易
5. **货币 ETF** (20 个) - 类似货币基金
6. **场外基金** (1 个) - 联接基金等

## 📈 市场分布

| 市场 | 代码前缀 | 数量 | 说明 |
|------|---------|------|------|
| 深交所 | 15xxxx | 881 | 主要是行业、主题 ETF |
| 上交所 | 51xxxx | 437 | 宽基、行业 ETF |
| 上交所 | 56xxxx | 195 | 新发行的 ETF |
| 深交所 | 16xxxx | 61 | 部分行业 ETF |

## 🔄 数据更新

### 手动更新 CSV
```bash
cd /Users/hsb/Downloads/stock_app_service
python3 -c "
import sys
sys.path.insert(0, '.')
from app.services.etf_manager import etf_manager
import pandas as pd

# 获取最新的可交易 ETF
all_funds = etf_manager.load_etf_list_from_tushare(filter_lof=False)
tradable_etfs = []

for fund in all_funds:
    ts_code = fund['ts_code']
    name = fund['name']
    symbol = fund['symbol']
    
    # 排除 LOF、债券、货币
    if 'LOF' in name or '债' in name or '货币' in name:
        continue
    
    # 只保留场内可交易代码
    if (symbol.startswith(('51', '56')) and '.SH' in ts_code) or \
       (symbol.startswith(('15', '16')) and '.SZ' in ts_code):
        tradable_etfs.append(fund)

# 保存
df = pd.DataFrame(tradable_etfs)
df.to_csv('app/etf/ETF列表.csv', index=False, encoding='utf-8')
print(f'✅ 更新完成，共 {len(tradable_etfs)} 个可交易 ETF')
"
```

### 系统自动初始化
```bash
# 使用 etf_only 模式
docker-compose up -d

# 或通过 API
curl -X POST "http://localhost:8000/api/stocks/scheduler/init?mode=etf_only" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## 💡 使用说明

### 1. 初始化 ETF 数据
- 每次初始化会**自动清空**旧的 ETF 代码和 K线数据
- 然后重新加载 CSV 中的 1574 个可交易 ETF
- 获取最近 180 天的 K线数据

### 2. 数据接口
- ETF 使用 `fund_daily` 接口获取日线数据
- 股票使用 `daily` 接口获取日线数据
- 系统自动识别并使用正确的接口

### 3. 信号计算
- ETF 信号仅在以下时机计算：
  - 17:30 定时任务后
  - 启动时 `full_init` 或 `etf_only` 模式
- 盘中实时更新**不包括** ETF

## 🔍 示例 ETF

### 热门宽基 ETF
- 510300.SH - 沪深300ETF
- 510500.SH - 中证500ETF
- 159915.SZ - 创业板ETF
- 512000.SH - 券商ETF

### 行业 ETF
- 512880.SH - 证券ETF
- 512170.SH - 医药ETF
- 515050.SH - 5GETF
- 512690.SH - 酒ETF

### 主题 ETF
- 159995.SZ - 芯片ETF
- 515790.SH - 光伏ETF
- 516160.SH - 新能源ETF
- 159992.SZ - 创新药ETF

## ⚠️ 注意事项

### 交易规则
1. **T+0 交易** (159个)：
   - 跨境ETF、债券ETF、黄金ETF、货币ETF
   - QDII、港股/美股相关ETF（如恒生ETF、纳指ETF）
   - 当天买入当天可卖出
   
2. **T+1 交易** (1061个)：
   - A股市场ETF（如沪深300ETF、创业板ETF）
   - 当天买入，次日才能卖出
   
### 其他注意
3. **交易费用**: 一般为万分之几，比股票便宜
4. **流动性**: 选择成交量大的 ETF，避免流动性风险
5. **跟踪误差**: ETF 可能与指数有偏差，注意跟踪误差

## 📝 更新日志

- 2025-10-16 v3: 添加交易类型标识
  - CSV 中新增 `industry` 字段：`T+0交易` 或 `T+1交易`
  - T+0 交易：159 个（跨境、债券、黄金、货币、QDII、港股/美股）
  - T+1 交易：1061 个（A股市场 ETF）
  - 用户可直接查看交易规则，无需程序判断

- 2025-10-16 v2: 优化筛选，1220 个可交易 ETF
  - 排除分级基金（如军工A/B、证券A/B）
  - 排除 LOF、债券、货币、场外基金
  - 只保留场内可交易代码
  - 支持自动清空和重新初始化
  - 包含所有热门 ETF（沪深300、中证500、创业板等）

- 2025-10-16 v1: 初始版本

