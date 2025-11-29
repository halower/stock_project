# -*- coding: utf-8 -*-
"""
WebSocket API端点

提供WebSocket连接端点和管理接口
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException
from typing import Dict, Any
import uuid

from app.core.logging import logger
from app.api.dependencies import verify_token
from app.models.websocket_models import ConnectedMessage
from app.services.websocket import (
    connection_manager,
    subscription_manager,
    message_handler,
    price_publisher
)

router = APIRouter()


@router.websocket("/ws/stock/prices")
async def websocket_stock_prices(websocket: WebSocket):
    """
    WebSocket端点：实时股票价格推送
    
    ## 连接说明
    
    客户端连接后会收到连接确认消息：
    ```json
    {
        "type": "connected",
        "client_id": "client_xxx",
        "message": "WebSocket连接成功",
        "timestamp": "2025-11-24T10:30:00"
    }
    ```
    
    ## 订阅消息
    
    订阅策略：
    ```json
    {
        "type": "subscribe",
        "subscription_type": "strategy",
        "target": "volume_wave"
    }
    ```
    
    订阅单个股票：
    ```json
    {
        "type": "subscribe",
        "subscription_type": "stock",
        "target": "600519"
    }
    ```
    
    ## 价格推送
    
    服务器会自动推送价格更新：
    ```json
    {
        "type": "price_update",
        "data": [
            {
                "code": "600519",
                "name": "贵州茅台",
                "price": 1850.5,
                "change": 25.3,
                "change_percent": 2.5,
                "volume": 12345678,
                "timestamp": "2025-11-24T10:30:00"
            }
        ],
        "count": 1,
        "timestamp": "2025-11-24T10:30:00"
    }
    ```
    
    ## 心跳
    
    客户端应定期发送心跳：
    ```json
    {
        "type": "ping"
    }
    ```
    
    服务器响应：
    ```json
    {
        "type": "pong",
        "timestamp": "2025-11-24T10:30:00"
    }
    ```
    """
    # 生成客户端ID
    client_id = f"client_{uuid.uuid4().hex[:8]}"
    
    try:
        # 建立连接
        success = await connection_manager.connect(websocket, client_id)
        
        if not success:
            logger.error(f"WebSocket连接失败: {client_id}")
            return
        
        # 发送连接确认消息
        welcome_message = ConnectedMessage(client_id=client_id)
        await websocket.send_json(welcome_message.model_dump())
        
        # 消息循环
        while True:
            try:
                # 接收客户端消息
                data = await websocket.receive_json()
                
                # 处理消息
                response = await message_handler.handle_message(client_id, data)
                
                # 发送响应（如果有）
                if response:
                    await websocket.send_json(response)
                
            except WebSocketDisconnect:
                logger.info(f"客户端主动断开连接: {client_id}")
                break
            
            except Exception as e:
                logger.error(f"处理WebSocket消息时出错: {client_id}, {e}")
                # 发送错误消息
                error_message = {
                    "type": "error",
                    "error": "消息处理失败",
                    "details": str(e)
                }
                try:
                    await websocket.send_json(error_message)
                except:
                    break
    
    except Exception as e:
        logger.error(f"WebSocket连接异常: {client_id}, {e}")
    
    finally:
        # 清理连接
        await connection_manager.disconnect(client_id, "连接关闭")
        subscription_manager.unsubscribe_all(client_id)


@router.get("/api/websocket/stats", summary="获取WebSocket统计信息", dependencies=[Depends(verify_token)])
async def get_websocket_stats() -> Dict[str, Any]:
    """
    获取WebSocket连接和订阅统计信息
    
    Returns:
        统计信息字典
    """
    try:
        # 获取连接统计
        connection_stats = connection_manager.get_stats()
        
        # 获取订阅统计
        subscription_stats = subscription_manager.get_stats()
        
        return {
            "code": 200,
            "message": "获取统计信息成功",
            "data": {
                "connections": connection_stats.model_dump(),
                "subscriptions": subscription_stats
            }
        }
    
    except Exception as e:
        logger.error(f"获取WebSocket统计信息失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/websocket/clients", summary="获取所有客户端信息", dependencies=[Depends(verify_token)])
async def get_websocket_clients() -> Dict[str, Any]:
    """
    获取所有连接的客户端信息
    
    Returns:
        客户端列表
    """
    try:
        clients = connection_manager.get_all_clients()
        
        # 添加订阅信息
        client_list = []
        for client in clients:
            client_dict = client.model_dump()
            client_dict['subscriptions'] = subscription_manager.get_client_subscriptions(
                client.client_id
            )
            client_list.append(client_dict)
        
        return {
            "code": 200,
            "message": "获取客户端信息成功",
            "data": {
                "clients": client_list,
                "count": len(client_list)
            }
        }
    
    except Exception as e:
        logger.error(f"获取WebSocket客户端信息失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/websocket/broadcast/test", summary="测试广播消息", dependencies=[Depends(verify_token)])
async def test_broadcast_message() -> Dict[str, Any]:
    """
    测试广播消息功能
    
    向所有连接的客户端发送测试消息
    """
    try:
        test_message = {
            "type": "test",
            "message": "这是一条测试消息",
            "timestamp": "2025-11-24T10:30:00"
        }
        
        count = await connection_manager.broadcast(test_message)
        
        return {
            "code": 200,
            "message": "广播测试消息成功",
            "data": {
                "sent_count": count
            }
        }
    
    except Exception as e:
        logger.error(f"广播测试消息失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/websocket/push/prices", summary="手动触发价格推送", dependencies=[Depends(verify_token)])
async def manual_push_prices(strategy: str = "volume_wave") -> Dict[str, Any]:
    """
    手动触发价格推送
    
    Args:
        strategy: 策略代码
        
    Returns:
        推送结果
    """
    try:
        count = await price_publisher.publish_strategy_prices(strategy)
        
        return {
            "code": 200,
            "message": "价格推送成功",
            "data": {
                "strategy": strategy,
                "client_count": count
            }
        }
    
    except Exception as e:
        logger.error(f"手动推送价格失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

