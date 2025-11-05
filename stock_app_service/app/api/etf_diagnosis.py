#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ETF信号诊断API
"""

from fastapi import APIRouter, Depends, Query
from typing import Dict, Any
import asyncio

from app.core.logging import logger
from app.db.session import RedisCache
from app.services.stock.stock_data_manager import StockDataManager
from app.services.signal.signal_manager import SignalManager
from app.api.dependencies import verify_token

router = APIRouter(tags=["ETF诊断"])

redis_cache = RedisCache()


@router.get(
    "/api/etf/diagnosis",
    summary="ETF信号计算诊断",
    description="检查ETF数据完整性和信号计算状态",
    dependencies=[Depends(verify_token)]
)
async def diagnose_etf_signals() -> Dict[str, Any]:
    """
    诊断ETF信号计算问题
    
    检查项目：
    1. Redis中的ETF列表
    2. stock_list中的ETF数据
    3. ETF K线数据
    4. 现有的买入信号
    5. ETF信号比例
    """
    
    diagnosis_result = {
        "status": "running",
        "checks": []
    }
    
    sdm = None
    
    try:
        # 1. 检查Redis中的ETF列表
        check1 = {"name": "Redis ETF列表检查", "status": "checking"}
        try:
            etf_list_redis = redis_cache.get_cache("etf:list:all")
            if etf_list_redis:
                check1["status"] = "success"
                check1["etf_count"] = len(etf_list_redis)
                check1["message"] = f"找到 {len(etf_list_redis)} 个ETF"
                if len(etf_list_redis) > 0:
                    check1["sample"] = etf_list_redis[0]
            else:
                check1["status"] = "warning"
                check1["message"] = "etf:list:all 不存在，ETF列表未初始化"
        except Exception as e:
            check1["status"] = "error"
            check1["message"] = f"检查失败: {str(e)}"
        
        diagnosis_result["checks"].append(check1)
        
        # 2. 检查stock_list中的ETF
        check2 = {"name": "stock_list ETF检查", "status": "checking"}
        try:
            sdm = StockDataManager()
            await sdm.initialize()
            
            all_stocks = await sdm._get_all_stocks()
            etf_stocks = [s for s in all_stocks if s.get('market') == 'ETF']
            stock_only = [s for s in all_stocks if s.get('market') != 'ETF']
            
            check2["status"] = "success" if len(etf_stocks) > 0 else "warning"
            check2["total_items"] = len(all_stocks)
            check2["etf_count"] = len(etf_stocks)
            check2["stock_count"] = len(stock_only)
            check2["message"] = f"总标的 {len(all_stocks)}, 股票 {len(stock_only)}, ETF {len(etf_stocks)}"
            
            if len(etf_stocks) > 0:
                check2["etf_samples"] = etf_stocks[:3]
            else:
                check2["message"] += " - ⚠️ 没有找到ETF数据"
                
        except Exception as e:
            check2["status"] = "error"
            check2["message"] = f"检查失败: {str(e)}"
        
        diagnosis_result["checks"].append(check2)
        
        # 3. 检查ETF K线数据
        check3 = {"name": "ETF K线数据检查", "status": "checking"}
        try:
            etf_with_kline = 0
            etf_without_kline = 0
            etf_codes_with_data = []
            etf_codes_without_data = []
            
            etf_list_redis = redis_cache.get_cache("etf:list:all")
            if etf_list_redis:
                # 检查前20个ETF
                for etf in etf_list_redis[:20]:
                    ts_code = etf.get('ts_code')
                    if ts_code:
                        kline_key = f"stock_trend:{ts_code}"
                        kline_data = redis_cache.get_cache_raw(kline_key)
                        if kline_data:
                            etf_with_kline += 1
                            if len(etf_codes_with_data) < 5:
                                etf_codes_with_data.append(ts_code)
                        else:
                            etf_without_kline += 1
                            if len(etf_codes_without_data) < 5:
                                etf_codes_without_data.append(ts_code)
                
                check3["status"] = "success" if etf_with_kline > 0 else "warning"
                check3["checked_count"] = 20
                check3["with_kline"] = etf_with_kline
                check3["without_kline"] = etf_without_kline
                check3["message"] = f"抽查20个ETF: {etf_with_kline}个有K线数据, {etf_without_kline}个无数据"
                check3["samples_with_data"] = etf_codes_with_data
                check3["samples_without_data"] = etf_codes_without_data
            else:
                check3["status"] = "warning"
                check3["message"] = "无法检查，ETF列表不存在"
                
        except Exception as e:
            check3["status"] = "error"
            check3["message"] = f"检查失败: {str(e)}"
        
        diagnosis_result["checks"].append(check3)
        
        # 4. 检查现有的买入信号
        check4 = {"name": "买入信号检查", "status": "checking"}
        try:
            buy_signals = redis_cache.get_cache("stock:buy_signals")
            
            if buy_signals:
                total_signals = len(buy_signals)
                etf_signals = [s for s in buy_signals if s.get('market') == 'ETF']
                stock_signals = [s for s in buy_signals if s.get('market') != 'ETF']
                
                check4["status"] = "success" if len(etf_signals) > 0 else "warning"
                check4["total_signals"] = total_signals
                check4["stock_signals"] = len(stock_signals)
                check4["etf_signals"] = len(etf_signals)
                check4["message"] = f"总信号 {total_signals}, 股票 {len(stock_signals)}, ETF {len(etf_signals)}"
                
                if etf_signals:
                    check4["etf_signal_samples"] = etf_signals[:3]
                else:
                    check4["message"] += " - ⚠️ 没有ETF信号"
            else:
                check4["status"] = "warning"
                check4["message"] = "没有任何买入信号"
                
        except Exception as e:
            check4["status"] = "error"
            check4["message"] = f"检查失败: {str(e)}"
        
        diagnosis_result["checks"].append(check4)
        
        # 5. 总结
        diagnosis_result["status"] = "completed"
        
        # 判断是否有问题
        has_etf_list = check1.get("status") == "success"
        has_etf_in_stock_list = check2.get("etf_count", 0) > 0
        has_etf_kline = check3.get("with_kline", 0) > 0
        has_etf_signals = check4.get("etf_signals", 0) > 0
        
        if has_etf_list and has_etf_in_stock_list and has_etf_kline and has_etf_signals:
            diagnosis_result["summary"] = "✅ ETF数据和信号计算正常"
            diagnosis_result["recommendation"] = "无需操作"
        elif not has_etf_list:
            diagnosis_result["summary"] = "❌ ETF列表未初始化"
            diagnosis_result["recommendation"] = "需要执行ETF初始化：POST /api/scheduler/tasks/trigger?task_name=init_etf"
        elif not has_etf_in_stock_list:
            diagnosis_result["summary"] = "❌ stock_list中没有ETF"
            diagnosis_result["recommendation"] = "需要执行ETF初始化：POST /api/scheduler/tasks/trigger?task_name=init_etf"
        elif not has_etf_kline:
            diagnosis_result["summary"] = "❌ ETF没有K线数据"
            diagnosis_result["recommendation"] = "需要获取ETF历史数据：POST /api/scheduler/tasks/trigger?task_name=init_etf"
        elif not has_etf_signals:
            diagnosis_result["summary"] = "⚠️ ETF信号缺失"
            diagnosis_result["recommendation"] = "需要手动触发信号计算：POST /api/etf/diagnosis/recalculate"
        else:
            diagnosis_result["summary"] = "⚠️ 部分检查项有问题"
            diagnosis_result["recommendation"] = "查看详细检查结果"
        
        return diagnosis_result
        
    except Exception as e:
        logger.error(f"ETF诊断失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        
        return {
            "status": "error",
            "message": str(e),
            "traceback": traceback.format_exc()
        }
    
    finally:
        if sdm:
            try:
                await sdm.close()
            except:
                pass


@router.post(
    "/api/etf/diagnosis/recalculate",
    summary="手动重新计算ETF信号",
    description="仅计算ETF的买入信号，并追加到现有信号中",
    dependencies=[Depends(verify_token)]
)
async def recalculate_etf_signals(
    clear_existing: bool = Query(False, description="是否清空现有信号（默认False，追加模式）")
) -> Dict[str, Any]:
    """
    手动触发ETF信号计算
    """
    signal_manager = None
    
    try:
        logger.info("开始手动计算ETF信号...")
        
        signal_manager = SignalManager()
        await signal_manager.initialize()
        
        result = await signal_manager.calculate_buy_signals(
            force_recalculate=True,
            etf_only=True,
            clear_existing=clear_existing
        )
        
        # 再次检查信号数量
        buy_signals = redis_cache.get_cache("stock:buy_signals")
        etf_signals = [s for s in buy_signals if s.get('market') == 'ETF'] if buy_signals else []
        
        return {
            "status": "success",
            "message": "ETF信号计算完成",
            "calculation_result": result,
            "etf_signal_count": len(etf_signals),
            "total_signal_count": len(buy_signals) if buy_signals else 0,
            "etf_signal_samples": etf_signals[:5] if etf_signals else []
        }
        
    except Exception as e:
        logger.error(f"ETF信号计算失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        
        return {
            "status": "error",
            "message": str(e),
            "traceback": traceback.format_exc()
        }
    
    finally:
        if signal_manager:
            try:
                await signal_manager.close()
            except:
                pass


@router.get(
    "/api/etf/signals",
    summary="获取ETF买入信号",
    description="获取当前所有ETF的买入信号",
    dependencies=[Depends(verify_token)]
)
async def get_etf_signals(
    strategy: str = Query(None, description="策略类型（可选）：volume_wave 或 trend_continuation")
) -> Dict[str, Any]:
    """
    获取ETF买入信号列表
    """
    try:
        buy_signals = redis_cache.get_cache("stock:buy_signals")
        
        if not buy_signals:
            return {
                "status": "success",
                "message": "暂无买入信号",
                "etf_signals": [],
                "count": 0
            }
        
        # 过滤出ETF信号
        etf_signals = [s for s in buy_signals if s.get('market') == 'ETF']
        
        # 如果指定了策略，进一步过滤
        if strategy:
            etf_signals = [s for s in etf_signals if s.get('strategy') == strategy]
        
        return {
            "status": "success",
            "message": f"找到 {len(etf_signals)} 个ETF信号",
            "etf_signals": etf_signals,
            "count": len(etf_signals),
            "strategies": list(set([s.get('strategy') for s in etf_signals]))
        }
        
    except Exception as e:
        logger.error(f"获取ETF信号失败: {e}")
        return {
            "status": "error",
            "message": str(e)
        }

