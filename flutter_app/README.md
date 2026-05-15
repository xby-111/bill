# 📱 家庭工时记账系统 - Flutter 客户端

Flutter 跨平台移动应用，支持 Android / iOS / Web。

## 🚀 快速开始

```bash
# 进入目录
cd flutter_app

# 获取依赖
flutter pub get

# 配置 API 地址 (重要!)
# 编辑 lib/config/app_config.dart
# 将 apiBaseUrl 改为后端服务地址

# 运行应用
flutter run
```

## ⚙️ 配置

编辑 `lib/config/app_config.dart`：

```dart
static const String apiBaseUrl = 'http://192.168.1.100:8000';
//                                ↑ 改为你的后端 IP
```

查看电脑 IP：
```powershell
ipconfig | Select-String "IPv4"
```

## 📁 项目结构

```
lib/
├── main.dart              # 应用入口
├── config/
│   └── app_config.dart    # API 地址配置
├── models/
│   ├── bill.dart          # 账单数据模型
│   └── project.dart       # 项目数据模型
├── pages/
│   ├── login_page.dart    # 登录页
│   ├── register_page.dart # 注册页
│   ├── bill_list_page.dart      # 账单列表
│   ├── add_bill_page.dart       # 添加/编辑账单
│   ├── bill_detail_page.dart    # 账单详情
│   ├── bill_history_page.dart   # 历史版本
│   ├── statistics_page.dart     # 统计图表
│   └── project_list_page.dart   # 项目管理
├── services/
│   ├── api_service.dart   # HTTP API 封装
│   ├── auth_provider.dart # 认证状态管理
│   └── speech_parser.dart # 语音/OCR 解析
└── widgets/               # 可复用组件
```

## ✨ 功能特性

| 功能 | 说明 |
|------|------|
| 🎤 语音输入 | 长按说话，自动识别人员、工时、金额 |
| 📷 OCR 拍照 | 离线识别单据文字，自动填表 |
| 📊 统计图表 | 月度/分类/人员统计 |
| 📂 项目管理 | 按项目分组账单 |
| 🕓 历史回溯 | 查看/恢复账单历史版本 |

## 📦 主要依赖

- `provider` - 状态管理
- `http` - 网络请求
- `shared_preferences` - 本地存储
- `speech_to_text` - 语音识别
- `google_mlkit_text_recognition` - OCR 文字识别
- `fl_chart` - 图表展示

## 🔧 权限配置

### Android (`android/app/src/main/AndroidManifest.xml`)
- `INTERNET` - 网络访问
- `RECORD_AUDIO` - 麦克风
- `CAMERA` - 相机

### iOS (`ios/Runner/Info.plist`)
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSCameraUsageDescription`

## 🏗️ 构建发布

```bash
# Android APK
flutter build apk --release

# iOS (需要 macOS)
flutter build ios --release

# Web
flutter build web --release
```
