# -*- coding: utf-8 -*-
"""API通用依赖函数"""

from fastapi import Header, HTTPException, status
from typing import Optional

from app.core.config import API_TOKEN, API_TOKEN_ENABLED

async def verify_token(x_api_token: Optional[str] = Header(None, alias="X-API-Token")):
    """验证API Token
    
    使用X-API-Token头进行认证
    如果API_TOKEN_ENABLED为False，则跳过验证
    否则检查请求头中的token是否与配置中的API_TOKEN匹配
    """
    if not API_TOKEN_ENABLED:
        return
    
    # 检查是否提供了token
    if not x_api_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="缺少API Token，请在请求头中提供 X-API-Token"
        )
    
    # 验证token
    if x_api_token != API_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API Token无效"
        ) 