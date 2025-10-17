# -*- coding: utf-8 -*-
"""API路由模块"""

from fastapi import APIRouter

# 创建主路由 - 简化版本，只包含现有模块
router = APIRouter()

# 由于模块结构简化，直接在main.py中手动包含各个路由
# 这样可以避免循环导入和模块不存在的问题 