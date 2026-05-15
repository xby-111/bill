# 🏠 家庭工时记账系统 (Family Work Ledger)

一个专为家庭设计的工时与账单记录系统，帮助父母轻松记录临时工人的工作情况（如装修工人、保洁阿姨、维修师傅等）。

> **技术栈**：FastAPI (Python) 后端 + Flutter 移动端

---

## 📁 项目结构

```
bill/
├── 📂 后端 (FastAPI + SQLite)
│   ├── main.py                 # 🚀 FastAPI 应用入口
│   ├── requirements.txt        # Python 依赖
│   ├── data.db                 # SQLite 数据库（运行后生成）
│   ├── db/
│   │   ├── database.py         # 数据库连接配置
│   │   └── init_db.py          # 表初始化
│   ├── models/
│   │   ├── user.py             # 用户 ORM 模型
│   │   └── bill.py             # 账单 ORM 模型
│   ├── schemas/
│   │   ├── user.py             # 用户 Pydantic 模式
│   │   └── bill.py             # 账单 Pydantic 模式
│   ├── routers/
│   │   ├── auth.py             # 认证路由 (注册/登录)
│   │   └── bills.py            # 账单路由 (CRUD/统计/导出)
│   ├── services/
│   │   ├── auth_service.py     # 认证业务逻辑
│   │   └── async_bill_service.py # 账单业务逻辑 (异步)
│   └── utils/
│       └── jwt.py              # JWT 工具
│
└── 📂 flutter_app/ (Flutter 移动端)
    ├── pubspec.yaml            # Flutter 依赖配置
    ├── android/
    │   └── app/src/main/
    │       └── AndroidManifest.xml  # Android 权限配置
    ├── ios/
    │   └── Runner/
    │       └── Info.plist      # iOS 权限配置
    └── lib/
        ├── main.dart           # 🚀 Flutter 入口
        ├── config/
        │   └── app_config.dart # API 地址等常量配置
        ├── models/
        │   └── bill.dart       # Dart 数据模型
        ├── services/
        │   └── api_service.dart # HTTP API 调用封装
        └── pages/
            └── add_bill_page.dart # 记工时页面
```

---

## ✨ 功能特色

| 功能 | 说明 |
|------|------|
| 📝 **账单记录** | 记录金额、分类、日期、备注 |
| 👷 **人员管理** | 记录人员姓名、工作时长、支付方式 |
| 🎤 **语音输入** | 长按说话，自动识别工人、时间、工时 |
| 📷 **OCR 拍照** | 拍摄单据/收据，离线识别文字并自动填表 |
| 🤖 **智能计算** | 自动抽取时薪/工时并计算总金额，表单预填充 |
| 📊 **统计分析** | 按月/按分类/按工人汇总 |
| 📤 **CSV 导出** | 导出账单到 Excel |
| 🔐 **多用户** | 支持家庭成员各自登录 |

---

## 🚀 快速开始

### 1️⃣ 启动后端

#### 方式 A：使用 SQLite（推荐新手，零配置）

```powershell
# 进入项目根目录
cd d:\Projects\bill

# 创建虚拟环境（首次）
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# 安装依赖
pip install -r requirements.txt

# 启动服务（默认使用 SQLite）
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

#### 方式 B：使用 PostgreSQL（多用户/云端部署）

```powershell
# 1. 启动 PostgreSQL 容器
docker-compose up -d

# 2. 配置环境变量
copy .env.example .env
# 编辑 .env 设置:
#   DB_TYPE=postgresql
#   DB_USER=ledger
#   DB_PASSWORD=ledger123

# 3. 启动后端
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

#### 方式 C：使用 MySQL

```powershell
# 1. 启动 MySQL 容器或使用现有 MySQL
docker run -d --name mysql-ledger \
  -e MYSQL_ROOT_PASSWORD=root123 \
  -e MYSQL_DATABASE=family_ledger \
  -e MYSQL_USER=ledger \
  -e MYSQL_PASSWORD=ledger123 \
  -p 3306:3306 mysql:8

# 2. 配置环境变量
copy .env.example .env
# 编辑 .env 设置:
#   DB_TYPE=mysql
#   DB_PORT=3306
#   DB_USER=ledger
#   DB_PASSWORD=ledger123

# 3. 启动后端
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

后端启动后访问：
- **API 文档**：http://127.0.0.1:8000/docs
- **健康检查**：http://127.0.0.1:8000/health

### 2️⃣ 配置 Flutter

```powershell
# 进入 Flutter 目录
cd d:\Projects\bill\flutter_app

# 获取依赖
flutter pub get

# 修改 API 地址（重要！）
# 编辑 lib/config/app_config.dart
# 将 apiBaseUrl 改为你电脑的局域网 IP
```

### 3️⃣ 运行 Flutter 应用

```powershell
# 连接手机或启动模拟器后
flutter run
```

---

## 📋 账单字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `amount` | float | ✅ | 金额（元） |
| `bill_type` | string | ✅ | `income` 或 `expense` |
| `category` | string | ✅ | 分类：人工/材料/餐饮等 |
| `date` | datetime | ✅ | 日期 + 具体时分秒 |
| `name` | string | ❌ | 工人/人员姓名 |
| `duration_hours` | float | ❌ | 工作时长（小时） |
| `hourly_rate` | float | ❌ | 时薪单价（元/小时） |
| `pay_method` | string | ❌ | 支付方式 |
| `note` | string | ❌ | 备注 |
| `project_id` | int | ❌ | 关联项目ID |

---

## 📡 API 接口

### 认证
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/register` | 注册 |
| POST | `/auth/login` | 登录 |
| GET | `/auth/me` | 当前用户 |

### 账单
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/bills/` | 创建账单 |
| GET | `/bills/` | 账单列表 |
| GET | `/bills/{id}` | 单个账单 |
| PUT | `/bills/{id}` | 更新 |
| DELETE | `/bills/{id}` | 删除 |

### 统计
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/bills/statistics/monthly` | 月度统计 |
| GET | `/bills/statistics/category` | 分类统计 |
| GET | `/bills/statistics/name` | 人员统计 |
| GET | `/bills/export` | 导出 CSV |

---

## 🎤 语音识别示例

长按"语音助手"按钮说：

> "张师傅今天大工，8小时"

系统会自动识别：
- 工人：张师傅
- 工时：8 小时

支持的语音关键词：
- **工时**：半工(4h)、大工(8h)、加班、X小时
- **工人**：预设名单、或“XX师傅/阿姨/叔叔”等称谓

---

## 🧠 智能语音解析 & 自动计算

- **时间点提取**：识别“下午1点”“早上8:30”等自然语言时间，并与所选日期合并，精确到分钟。
- **时薪/总价推导**：解析“每小时30块”“30块钱一个工时”等表达；当同时识别出时薪与工时后，自动计算金额并在表单中标注“30元/h × 4h”。
- **乱序容错**：无论说“王五 3小时 120块”还是“120块给王五干了3小时”，都能映射到正确字段。
- **人工校验**：语音结束后仅预填表单，不直接提交；同时在备注中追加 `[语音原文] ...` 方便再次核对。

**高级示例**

> “王五是下午1点来的，干了4个小时，说好30块钱一个工时。”

解析结果：

| 字段 | 解析值 |
|------|--------|
| Name | 王五 |
| Date | 2025-11-30 13:00:00 |
| Duration | 4.0 小时 |
| Hourly Rate | 30.0 元/h |
| Amount | 120.0 元（自动计算） |
| Note | [语音原文] … + [语音推断] 基于 30元/h × 4h |

---

## 📷 OCR 拍照识别

点击"拍单据"按钮 → 调用相机拍摄收据/便签 → 端侧离线识别中文 → 自动填充表单。

**技术特点**：
- 使用 **Google ML Kit** 实现离线中文文字识别（无需上传服务器）
- 复用语音解析逻辑，自动提取工人、金额、工时等信息
- 识别结果追加到备注中（`[OCR原文] ...`）供核对

**支持的单据类型**：
- 手写便签、收据
- 打印的工时单、付款凭证
- 任何包含工人姓名、金额、时长的文字内容

---

## ⚙️ 配置说明

### Flutter API 地址配置

编辑 `flutter_app/lib/config/app_config.dart`：

```dart
static const String apiBaseUrl = 'http://192.168.1.100:8000';
//                                ^^^^^^^^^^^^^^
//                                改为你电脑的局域网 IP
```

查看电脑 IP：
```powershell
ipconfig | Select-String "IPv4"
```

### Android 权限（已配置）

- `INTERNET` - 网络访问
- `RECORD_AUDIO` - 麦克风（语音识别）
- `CAMERA` - 相机（OCR 拍照识别）

### iOS 权限（已配置）

- `NSMicrophoneUsageDescription` - 麦克风
- `NSSpeechRecognitionUsageDescription` - 语音识别
- `NSCameraUsageDescription` - 相机（OCR 拍照识别）

---

## 🐳 Docker 部署

### 本地开发（OpenGauss）

```powershell
# 启动数据库
docker-compose up -d

# 查看日志
docker-compose logs -f opengauss

# 停止
docker-compose down

# 删除数据卷（慎用）
docker-compose down -v
```

### 环境变量配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `DB_TYPE` | `sqlite` | 数据库类型：`sqlite` / `postgresql` |
| `DB_HOST` | `localhost` | 数据库主机 |
| `DB_PORT` | `5432` | 数据库端口 |
| `DB_NAME` | `family_ledger` | 数据库名称 |
| `DB_USER` | `gaussdb` | 数据库用户 |
| `DB_PASSWORD` | `Gauss@123` | 数据库密码 |
| `DB_POOL_SIZE` | `5` | 连接池大小 |
| `DB_MAX_OVERFLOW` | `10` | 连接池溢出上限 |

---

## 📄 许可证

AGPL v3.0 License

---

**Made with ❤️ for families**
