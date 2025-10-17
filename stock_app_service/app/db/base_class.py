# -*- coding: utf-8 -*-
"""数据库模型基类

这个模块导出用于所有SQLAlchemy模型的Base类。
所有数据库模型都应该从这个Base类继承。
"""

from app.db.session import Base

# 重新导出Base类，便于统一导入
# 这样所有模型可以从app.db.base_class导入Base
# 而不是直接从session导入，使代码结构更清晰 