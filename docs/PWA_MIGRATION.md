# PWA 改造总结文档

> 改造日期：2026-02-28  
> 目标：将 Flutter 移动应用改造为 PWA（渐进式 Web 应用），解决 iOS 无法编译安装的问题

---

## 一、改造背景

- iOS 原生编译需要 Mac + Apple Developer 账号，环境搭建复杂
- 应用功能（账单 CRUD、统计图表、登录注册）全部基于 HTTP API，无原生硬件依赖
- 所有 Flutter 依赖（`http`、`provider`、`shared_preferences`、`fl_chart`、`intl`）均支持 Web 平台
- PWA 可在 iOS Safari 中「添加到主屏幕」，体验接近原生应用

---

## 二、修改文件清单

### 1. 修改的文件

| 文件 | 修改内容 | 原因 |
|------|----------|------|
| `flutter_app/lib/services/api_service.dart` | 移除 `import 'dart:io'`，将 `SocketException` 替换为 `http.ClientException` + 通用 `catch` | `dart:io` 在 Web 平台不可用 |
| `flutter_app/lib/config/app_config.dart` | 更新注释，增加 Web/PWA 部署说明 | 说明 Web 端使用相对路径 API |
| `flutter_app/web/index.html` | 更新标题为「家庭记账」，添加 `viewport` meta 标签，优化 iOS PWA 配置 | 定制 PWA 体验 |
| `flutter_app/web/manifest.json` | 更新应用名称、主题色、描述 | PWA 安装信息定制 |

### 2. 新增的文件

| 文件 | 说明 |
|------|------|
| `flutter_app/web/` 目录 (7个文件) | Flutter Web 平台支持文件（由 `flutter create --platforms web` 自动生成） |
| `docker/nginx.conf` | Nginx 配置：托管 PWA 静态文件 + 反向代理 API |
| `docker/docker-compose.pwa.yml` | Docker Compose 配置：一键部署 PWA + API + 数据库 |
| `scripts/build_web.ps1` | Windows 构建脚本 |
| `scripts/build_web.sh` | Linux/Mac 构建脚本 |
| `docs/PWA_MIGRATION.md` | 本文档 |

### 3. 未修改的文件

- **后端代码** — 零改动，CORS 已配置为 `*`
- **Android 构建** — 不受影响，仍可正常编译 APK
- **其他 Flutter 页面/组件** — 无 Web 不兼容代码，零改动
- **数据模型/服务层** — 完全兼容

---

## 三、核心代码变更详情

### 3.1 api_service.dart — 移除 dart:io 依赖

**变更前：**
```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';                          // ← Web 不可用
import 'package:http/http.dart' as http;

// ... 在 _executeWithRetry 中:
} on SocketException catch (e) {           // ← Web 不可用
    // ...
} on http.ClientException catch (e) {
    // ...
}
```

**变更后：**
```dart
import 'dart:async';
import 'dart:convert';
                                           // ← 已移除 dart:io
import 'package:http/http.dart' as http;

// ... 在 _executeWithRetry 中:
} on http.ClientException catch (e) {      // ← 合并网络错误处理，Web/移动端通用
    // 支持重试
    // ...
} catch (e) {                             // ← 通用兜底异常
    if (e is ApiException) rethrow;
    throw ApiException(
      message: '请求失败：$e',
      type: ApiErrorType.unknown,
      originalError: e,
    );
}
```

**影响评估：**
- `SocketException` 是 `dart:io` 中的类型，只在原生平台存在
- `http.ClientException` 是 `package:http` 的通用异常，在所有平台都可用
- 原生平台（Android）上，底层网络错误会被包装成 `http.ClientException`，行为不变
- 新增通用 `catch` 兜底，防止未预期异常导致应用崩溃

---

## 四、部署指南

### 4.1 本地开发测试

```powershell
# 在 flutter_app 目录下
cd flutter_app

# 方式一：直接运行（会打开 Chrome）
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000

# 方式二：使用构建脚本
..\scripts\build_web.ps1 -Mode dev
```

### 4.2 生产部署（推荐：Docker 一键部署）

```bash
# 1. 在本地构建 Web 产物
cd flutter_app
flutter build web --release --dart-define=API_BASE_URL=

# 2. 上传整个项目到服务器

# 3. 在服务器上启动
cd /root/bill
docker-compose -f docker/docker-compose.pwa.yml up -d
```

服务说明：
- **Nginx (端口 80)** — 托管 PWA 静态文件 + 反向代理 `/api/` 到后端
- **FastAPI (内部 8000)** — 后端 API，不直接暴露
- **PostgreSQL (内部 5432)** — 数据库

### 4.3 iOS 用户使用方式

1. 用 Safari 打开 `http://你的服务器IP/`
2. 点击底部「分享」按钮 (⬆️)
3. 选择「添加到主屏幕」
4. 应用图标会出现在主屏幕，点击即可全屏打开

### 4.4 已有部署的迁移

如果已使用 `deploy.ps1` 部署了后端，只需额外部署 Nginx 容器即可。在 `deploy.ps1` 的 docker-compose 配置中添加 `web` 服务，或独立使用 `docker-compose.pwa.yml`。

---

## 五、注意事项

1. **API 地址**：Web 构建时使用 `--dart-define=API_BASE_URL=`（空值），由 Nginx 反向代理 `/api/` 路径；Android APK 构建仍然使用完整 URL
2. **缓存策略**：`index.html` 和 Service Worker 设置为不缓存，确保更新及时生效；静态资源（JS/CSS/图片）设置长期缓存
3. **HTTPS**：生产环境建议配置 SSL，PWA 的 Service Worker 在非 localhost 环境需要 HTTPS
4. **兼容性**：iOS 14+ 的 Safari 均支持 PWA；所有现代浏览器（Chrome/Firefox/Edge/Safari）均支持

---

## 六、回滚方案

如需回滚，只需：
1. 将 `api_service.dart` 中的 `import 'dart:io'` 加回
2. 恢复 `SocketException` 和 `http.ClientException` 的分开捕获
3. 删除 `web/` 目录（可选，不影响移动端编译）

移动端（Android）构建完全不受本次改造影响。
