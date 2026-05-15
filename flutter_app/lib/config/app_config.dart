/// 应用配置
/// 
/// 支持通过 --dart-define 在编译时注入配置：
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
/// flutter build apk --dart-define=API_BASE_URL=https://api.example.com
/// flutter build web --dart-define=API_BASE_URL=  (Web端使用相对路径，由Nginx代理)
/// ```
class AppConfig {
  // ==================== API 配置 ====================
  
  /// API 基础地址
  /// 
  /// 优先级：--dart-define > 默认值
  /// - Android 模拟器: 10.0.2.2:8000
  /// - iOS 模拟器: localhost:8000
  /// - 真机: 替换为电脑局域网 IP (如 192.168.1.100)
  /// - 生产环境: 阿里云服务器地址
  /// - Web/PWA: 留空使用相对路径（由 Nginx 反向代理 /api/ 到后端）
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://xxxby.me:8000',
  );
  
  /// API 版本前缀（与后端对应）
  static const String apiVersion = String.fromEnvironment(
    'API_VERSION',
    defaultValue: 'v1', // 默认使用 v1 版本
  );
  
  /// 完整 API 基础路径
  static String get apiBasePath => apiVersion.isEmpty ? apiBaseUrl : '$apiBaseUrl/api/$apiVersion';

  /// API 请求超时时间（秒）
  static const int apiTimeout = int.fromEnvironment(
    'API_TIMEOUT',
    defaultValue: 15,
  );
  
  /// API 重试次数
  static const int apiRetryCount = int.fromEnvironment(
    'API_RETRY_COUNT',
    defaultValue: 2,
  );

  // ==================== 应用信息 ====================
  
  static const String appName = '家庭记账';
  static const String version = '1.0.0';
  static const String buildNumber = String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');

  // ==================== 业务默认值 ====================
  
  /// 预设工人列表（可从后端动态加载）
  static const List<String> defaultWorkers = ['张师傅', '李阿姨', '王叔叔'];
  
  /// 预设分类列表
  static const List<String> defaultCategories = [
    '人工', '材料', '餐饮', '交通', '水电', '维修', '其他'
  ];
  
  /// 支付方式列表
  static const List<String> payMethods = ['现金', '微信', '支付宝', '银行转账'];

  // ==================== 工时常量 ====================
  
  /// 半工时长（小时）
  static const double halfDayHours = 4.0;
  
  /// 全工时长（小时）
  static const double fullDayHours = 8.0;
  
  /// 最大工时（小时）
  static const double maxHours = 24.0;

  // ==================== 缓存配置 ====================
  
  /// 草稿自动保存间隔（毫秒）
  static const int draftSaveInterval = 500;
  
  /// 本地缓存过期时间（分钟）
  static const int cacheExpireMinutes = 30;

  // ==================== 调试配置 ====================
  
  /// 是否为调试模式
  static const bool isDebug = bool.fromEnvironment(
    'DEBUG',
    defaultValue: true,
  );
  
  /// 是否启用日志
  static const bool enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: true,
  );
}
