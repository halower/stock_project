# -*- coding: utf-8 -*-
"""系统状态和基本功能API"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Dict, Any

from app.db.session import get_db
from app.db.redis_storage import StockInfo, StockHistory
from app.core.logging import logger
from app.api.dependencies import verify_token

router = APIRouter(tags=["系统"])

