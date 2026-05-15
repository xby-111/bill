# 🏠 家庭工时记账系统

> 专为家庭设计的工时与账单记录系统

**技术栈**: FastAPI (Python) + Flutter 移动端 + PostgreSQL/SQLite

## 🚀 快速启动

```bash
# 1. 激活虚拟环境
venv\Scripts\activate

# 2. 启动后端服务
python main.py

# 3. 访问 API 文档
# http://localhost:8000/docs
```

## ✨ 功能特性

- 📝 账单记录与分类管理
- 🎤 语音输入 (自动识别人员/工时/金额)
- 📷 OCR 拍照识别
- 🤖 AI 智能解析 (DeepSeek)
- 📊 统计图表分析
- 📂 项目分组管理
- 🕓 历史版本回溯

## 📁 项目结构

```
bill/
├── config/           # 配置文件
├── db/               # 数据库层
├── models/           # ORM 模型
├── schemas/          # Pydantic 模式
├── routers/          # API 路由
├── services/         # 业务逻辑
├── utils/            # 工具函数
├── tests/            # 测试文件
├── flutter_app/      # Flutter 客户端
├── docker/           # 容器化配置
└── docs/             # 用户文档
```

## 📖 文档

| 文档 | 说明 |
|------|------|
| [用户指南](docs/README.md) | 完整使用说明、API 接口、配置指南 |
| [开发者指南](DEVELOPER_GUIDE.md) | 架构设计、性能优化、代码结构 |
| [Flutter 客户端](flutter_app/README.md) | 移动端开发说明 |
| [许可证](docs/LICENSE) | AGPL v3.0 |

## 🗄️ 数据库

支持多种数据库：
- **SQLite** - 本地开发 (零配置)
- **PostgreSQL** - 生产环境
- **MySQL** - 可选支持

当前部署：华为云 PostgreSQL
