# 🔧 家庭工时记账系统 - 开发者指南

> 面向开发者的技术文档，包含架构设计、性能优化、代码结构等详细信息。

**版本**: v2.0.0 (性能优化版)  
**最后更新**: 2025年12月30日

---

## 📐 技术架构

### 后端技术栈

| 组件 | 技术 | 版本 |
|------|------|------|
| 框架 | FastAPI | 0.104.1 |
| ORM | SQLAlchemy | 2.0.23 (异步) |
| 认证 | JWT (python-jose) | - |
| 密码 | bcrypt | - |
| 缓存 | Redis / 内存TTL缓存 | 5.0 |
| 序列化 | ORJson | - |
| 数据库 | PostgreSQL / SQLite | - |
| 部署 | Gunicorn + Uvicorn | - |

### Flutter 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | Flutter 3.0+ |
| 状态管理 | Provider |
| 网络 | HTTP (带重试) |
| 存储 | SharedPreferences |
| 语音 | speech_to_text |
| OCR | google_mlkit_text_recognition |
| 图表 | fl_chart |

---

## 📁 代码目录结构

```
bill/
├── main.py                    # FastAPI 入口 (中间件/路由/生命周期)
├── requirements.txt           # Python 依赖
├── start_dev.py               # 开发环境启动脚本
├── pytest.ini                 # 测试配置
│
├── config/
│   ├── config.py              # 统一配置 (环境变量/数据库/Redis/JWT)
│   └── env/.env.example       # 环境变量模板
│
├── db/
│   ├── database.py            # 同步数据库 (连接池/慢查询日志)
│   ├── async_database.py      # 异步数据库 (asyncpg/aiosqlite)
│   ├── init_db.py             # 表初始化
│   └── migration_*.py         # 迁移脚本
│
├── models/                    # SQLAlchemy ORM 模型
│   ├── user.py                # 用户模型
│   ├── bill.py                # 账单模型 (含复合索引)
│   └── project.py             # 项目模型
│
├── schemas/                   # Pydantic 请求/响应模型
│   ├── user.py
│   ├── bill.py                # BillCreate/Update/Response/ListItem
│   └── project.py
│
├── routers/                   # API 路由控制器
│   ├── auth.py                # 认证 (注册/登录/me)
│   ├── bills.py               # 账单 CRUD + 统计 + 批量操作
│   ├── projects.py            # 项目 CRUD
│   └── monitor.py             # 健康检查/性能统计/缓存状态
│
├── services/                  # 业务逻辑层
│   ├── auth_service.py        # 认证逻辑
│   ├── async_bill_service.py  # 账单逻辑 (异步+缓存)
│   ├── project_service.py     # 项目逻辑
│   └── ai_service.py          # DeepSeek AI 解析
│
├── utils/
│   ├── jwt.py                 # JWT 处理 (LRU缓存)
│   ├── cache.py               # 缓存模块 (Redis/内存降级)
│   ├── performance.py         # 性能监控
│   ├── exceptions.py          # 自定义异常
│   ├── logging_config.py      # 日志配置
│   ├── rate_limit.py          # 速率限制
│   ├── constants.py           # 常量定义
│   └── timezone_utils.py      # 时区处理
│
├── tests/                     # 测试
│   ├── conftest.py            # Fixtures
│   ├── test_auth.py
│   └── test_bills.py
│
├── docker/
│   ├── Dockerfile             # 生产镜像
│   └── docker-compose.prod.yml
│
└── flutter_app/               # Flutter 客户端 (见 flutter_app/README.md)
```

---

## ⚡ 性能优化

### 后端优化

#### 1. 异步数据库
- SQLAlchemy 2.0 异步模式
- asyncpg (PostgreSQL) / aiosqlite (SQLite)
- 避免 I/O 阻塞

#### 2. Redis 缓存
- 统计数据缓存 (5分钟 TTL)
- 用户信息缓存
- 自动降级到内存缓存

#### 3. 连接池配置
```python
pool_size = 10          # 基础连接数
max_overflow = 5        # 溢出连接数
pool_recycle = 1800     # 30分钟回收
pool_use_lifo = True    # 复用热连接
pool_pre_ping = True    # 健康检查
```

#### 4. JWT 解码缓存
- LRU 缓存 (2000条, 5分钟TTL)
- Token Hash 作为 Key (安全)

#### 5. 数据库索引
```
idx_user_date          # 按月查询
idx_user_date_type     # 月度统计
idx_user_category      # 分类统计
idx_user_name          # 人员筛选
idx_user_project       # 项目筛选
idx_user_created       # 时间排序
```

#### 6. 慢查询监控
- 阈值: 0.5秒
- 保留最近 100 条

#### 7. 批量操作
- 批量创建: 最多 1000 条
- 批量删除: 最多 100 条

### Flutter 优化

- `const` 构造函数
- `RepaintBoundary` 隔离重绘
- 静态 `DateFormat` (避免重复创建)
- `PaginationController` 分页
- 懒加载 + 骨架屏

---

## 🔐 安全特性

| 特性 | 实现 |
|------|------|
| 认证 | JWT (30分钟过期 + 缓存) |
| 密码 | bcrypt (成本因子12) |
| 跨域 | CORS 白名单 |
| 注入 | SQLAlchemy ORM 防护 |
| 隔离 | 每个查询带 user_id |
| 限流 | 速率限制中间件 |
| 文档 | 生产环境隐藏 API 文档 |

---

## 🚀 开发环境

### 启动后端

```powershell
# 激活虚拟环境
.\venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
copy config\env\.env.example .env

# 启动 (热重载)
python start_dev.py
# 或: uvicorn main:app --reload

# 访问 API 文档
# http://localhost:8000/docs
```

### 运行测试

```powershell
pytest -v
```

### 生产部署

```powershell
# 构建镜像
docker build -t family-ledger -f docker/Dockerfile .

# 启动服务
docker-compose -f docker/docker-compose.prod.yml up -d

# 健康检查
curl http://localhost:8000/api/v1/monitor/health
```

---

## 📡 API 端点

### 认证 `/api/v1/auth`
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /register | 用户注册 |
| POST | /login | 用户登录 |
| GET | /me | 当前用户 |

### 账单 `/api/v1/bills`
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | / | 创建账单 |
| GET | / | 账单列表 (筛选/分页) |
| GET | /{id} | 账单详情 |
| PUT | /{id} | 更新账单 |
| DELETE | /{id} | 删除账单 |
| POST | /batch | 批量创建 |
| DELETE | /batch | 批量删除 |
| POST | /smart-parse | AI 智能解析 |
| GET | /export | 导出 CSV |
| GET | /statistics/monthly | 月度统计 |
| GET | /statistics/category | 分类统计 |
| GET | /statistics/name | 人员统计 |
| GET | /{id}/history | 账单历史 |
| POST | /history/{id}/restore | 恢复版本 |

### 项目 `/api/v1/projects`
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | / | 创建项目 |
| GET | / | 项目列表 |
| GET | /{id} | 项目详情 |
| PUT | /{id} | 更新项目 |
| DELETE | /{id} | 删除项目 |

### 监控 `/api/v1/monitor`
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /health | 健康检查 (无需认证) |
| GET | /stats | 性能统计 |
| GET | /cache | 缓存状态 |
| POST | /cache/clear | 清空缓存 |

---

## 🔧 环境变量

### 必需

| 变量 | 说明 |
|------|------|
| `SECRET_KEY` | JWT 密钥 (生产>=32字符) |
| `DB_TYPE` | 数据库类型: sqlite/postgresql/mysql |

### 可选

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `REDIS_URL` | - | Redis 地址 (不配置用内存缓存) |
| `DB_POOL_SIZE` | 10 | 连接池大小 |
| `SLOW_QUERY_THRESHOLD` | 0.5 | 慢查询阈值(秒) |
| `CACHE_TTL_STATS` | 300 | 统计缓存 TTL(秒) |

---

## 📜 许可证

AGPL v3.0
