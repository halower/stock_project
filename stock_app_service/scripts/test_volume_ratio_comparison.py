#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
量能比值计算对比测试脚本
用于验证新旧算法的差异
"""

import numpy as np


def calculate_volume_ratio_old(volumes, current_index):
    """
    旧算法：当前成交量 / 前一根K线成交量
    """
    if current_index < 1:
        return 0.0
    
    current_volume = volumes[current_index]
    prev_volume = volumes[current_index - 1]
    
    if prev_volume > 0 and current_volume > 0:
        return round(current_volume / prev_volume, 2)
    return 0.0


def calculate_volume_ratio_new(volumes, current_index, period=20):
    """
    新算法：当前成交量 / 过去20日平均成交量
    """
    if current_index < period:
        return 0.0
    
    current_volume = volumes[current_index]
    
    # 计算过去20日平均成交量（不包括当前）
    start_idx = max(0, current_index - period)
    end_idx = current_index
    
    volume_list = [v for v in volumes[start_idx:end_idx] if v > 0]
    
    if len(volume_list) >= 10 and current_volume > 0:
        avg_volume = sum(volume_list) / len(volume_list)
        if avg_volume > 0:
            return round(current_volume / avg_volume, 2)
    
    return 0.0


def generate_test_data():
    """生成测试数据"""
    test_cases = [
        {
            "name": "正常放量",
            "volumes": [100] * 20 + [200],  # 最后一天放量2倍
            "description": "正常放量情况"
        },
        {
            "name": "极端放量",
            "volumes": [100] * 20 + [500],  # 最后一天放量5倍
            "description": "极端放量情况"
        },
        {
            "name": "缩量",
            "volumes": [100] * 20 + [50],   # 最后一天缩量50%
            "description": "缩量情况"
        },
        {
            "name": "前日极小量",
            "volumes": [100] * 19 + [5, 100],  # 前一天很小，今天正常
            "description": "前一天极小量，容易导致旧算法异常"
        },
        {
            "name": "波动大",
            "volumes": [100, 200, 50, 300, 80, 150, 40, 250, 70, 180,
                       110, 220, 60, 290, 90, 170, 45, 240, 75, 190, 120],
            "description": "成交量波动较大"
        },
        {
            "name": "递增",
            "volumes": list(range(100, 121)),  # 从100递增到120
            "description": "成交量递增趋势"
        }
    ]
    
    return test_cases


def run_comparison():
    """运行对比测试"""
    print("=" * 80)
    print("量能比值计算算法对比测试")
    print("=" * 80)
    print()
    
    test_cases = generate_test_data()
    
    for i, case in enumerate(test_cases, 1):
        volumes = case["volumes"]
        current_index = len(volumes) - 1
        
        old_ratio = calculate_volume_ratio_old(volumes, current_index)
        new_ratio = calculate_volume_ratio_new(volumes, current_index)
        
        print(f"测试用例 {i}: {case['name']}")
        print(f"说明: {case['description']}")
        print(f"当前成交量: {volumes[current_index]}")
        
        if current_index >= 1:
            print(f"前一日成交量: {volumes[current_index - 1]}")
        
        if current_index >= 20:
            avg_20 = sum(volumes[current_index-20:current_index]) / 20
            print(f"前20日平均成交量: {avg_20:.2f}")
        
        print(f"旧算法量能比值: {old_ratio}")
        print(f"新算法量能比值: {new_ratio}")
        
        # 判断差异
        if abs(old_ratio - new_ratio) > 0.5:
            print(f"⚠️  差异较大: {abs(old_ratio - new_ratio):.2f}")
            if old_ratio > 10:
                print(f"⚠️  旧算法异常: 比值超过10")
        else:
            print(f"✓ 差异较小")
        
        print("-" * 80)
        print()


def analyze_real_scenario():
    """分析真实场景"""
    print("=" * 80)
    print("真实场景模拟分析")
    print("=" * 80)
    print()
    
    # 模拟真实股票成交量数据（单位：手）
    np.random.seed(42)
    base_volume = 50000  # 基础成交量5万手
    
    # 生成30天的成交量数据（有波动）
    volumes = []
    for i in range(30):
        # 添加随机波动 (-30% ~ +50%)
        fluctuation = np.random.uniform(0.7, 1.5)
        volumes.append(int(base_volume * fluctuation))
    
    # 最后一天明显放量（2.5倍）
    volumes.append(int(base_volume * 2.5))
    
    current_index = len(volumes) - 1
    
    print(f"模拟股票最近31天成交量数据（最后一天放量）")
    print(f"基础成交量: {base_volume:,} 手")
    print()
    
    # 显示最近5天的数据
    print("最近5天成交量:")
    for i in range(max(0, current_index - 4), current_index + 1):
        mark = " <-- 今日" if i == current_index else ""
        print(f"  第{i+1}天: {volumes[i]:,} 手{mark}")
    print()
    
    old_ratio = calculate_volume_ratio_old(volumes, current_index)
    new_ratio = calculate_volume_ratio_new(volumes, current_index)
    
    print("计算结果:")
    print(f"  旧算法（vs前一日）: {old_ratio}")
    print(f"  新算法（vs 20日均值）: {new_ratio}")
    print()
    
    # 分析
    print("分析:")
    if old_ratio > 5:
        print(f"  ⚠️  旧算法比值过高: {old_ratio}")
    
    if 1.5 <= new_ratio <= 2.5:
        print(f"  ✓ 新算法显示明显放量: {new_ratio} (1.5-2.5为明显放量)")
    elif new_ratio > 2.5:
        print(f"  ✓ 新算法显示极端放量: {new_ratio} (>2.5为极端放量)")
    
    print()
    print("结论:")
    print("  新算法更能反映相对于平均水平的放量情况，")
    print("  而旧算法容易受前一日成交量影响产生异常值。")
    print()


def main():
    """主函数"""
    run_comparison()
    analyze_real_scenario()
    
    print("=" * 80)
    print("测试完成")
    print("=" * 80)


if __name__ == "__main__":
    main()

