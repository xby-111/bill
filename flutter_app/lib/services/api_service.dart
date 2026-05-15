import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill.dart';
import '../models/project.dart';
import '../config/app_config.dart';

/// API 异常类型枚举
enum ApiErrorType {
  /// 网络连接错误
  network,
  /// 请求超时
  timeout,
  /// 服务器错误 (5xx)
  server,
  /// 客户端错误 (4xx)
  client,
  /// 认证错误 (401/403)
  auth,
  /// 未知错误
  unknown,
}

/// API 异常
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final ApiErrorType type;
  final dynamic originalError;

  ApiException({
    this.statusCode,
    required this.message,
    this.type = ApiErrorType.unknown,
    this.originalError,
  });

  /// 是否可以重试
  bool get isRetryable =>
      type == ApiErrorType.network ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.server;

  /// 是否需要重新登录
  bool get requiresReauth => type == ApiErrorType.auth;

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}

/// API 服务
/// 
/// 提供所有后端 API 的调用方法，支持：
/// - 请求超时配置
/// - 自动重试机制
/// - Token 管理
/// - 统一错误处理
class ApiService {
  static String get baseUrl => AppConfig.apiBasePath;

  /// 请求超时时间 (增加到 30s，适应远程数据库响应)
  static const Duration requestTimeout = Duration(seconds: 30);
  
  /// 最大重试次数
  static const int maxRetries = 2;
  
  /// 重试间隔
  static const Duration retryDelay = Duration(milliseconds: 1000);

  String? _token;
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// 获取当前 Token
  Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    return _token;
  }

  /// 保存 Token
  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  /// 清除 Token
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  /// 检查是否已登录
  Future<bool> get isLoggedIn async => (await token) != null;

  /// 获取请求头
  Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Connection': 'keep-alive', // 显式请求保持连接，复用 TCP 通道，减少握手耗时
    };
    if (withAuth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  /// 处理响应错误
  ApiException _handleResponseError(http.Response response) {
    String message = '请求失败';
    ApiErrorType type = ApiErrorType.client;

    try {
      final body = jsonDecode(response.body);
      // 支持新的错误格式
      if (body['error'] != null) {
        message = body['error']['message'] ?? message;
      } else {
        message = body['detail']?.toString() ?? message;
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : '请求失败';
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      type = ApiErrorType.auth;
    } else if (response.statusCode >= 500) {
      type = ApiErrorType.server;
    }

    return ApiException(
      statusCode: response.statusCode,
      message: message,
      type: type,
    );
  }

  /// 执行带重试的请求
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request, {
    int retries = maxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await request().timeout(requestTimeout);
        
        // 服务器错误时重试
        if (response.statusCode >= 500 && attempt < retries) {
          attempt++;
          await Future.delayed(retryDelay * attempt);
          continue;
        }
        
        return response;
      } on TimeoutException {
        if (attempt < retries) {
          attempt++;
          print('⏰ 请求超时，正在重试 (${attempt}/${retries})...');
          await Future.delayed(retryDelay * attempt);
          continue;
        }
        throw ApiException(
          message: '请求超时 (${requestTimeout.inSeconds}秒)，服务器响应缓慢，请稍后重试',
          type: ApiErrorType.timeout,
        );
      } on http.ClientException catch (e) {
        if (attempt < retries) {
          attempt++;
          print('🔌 网络错误，正在重试 ($attempt/$retries)...');
          await Future.delayed(retryDelay * attempt);
          continue;
        }
        throw ApiException(
          message: '无法连接到服务器 ($baseUrl)，请检查：\n1. 后端服务是否运行\n2. 网络连接是否正常\n3. 防火墙设置',
          type: ApiErrorType.network,
          originalError: e,
        );
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(
          message: '请求失败：$e',
          type: ApiErrorType.unknown,
          originalError: e,
        );
      }
    }
  }

  /// 发送 GET 请求
  Future<dynamic> _get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path')
        .replace(queryParameters: queryParams?.isNotEmpty == true ? queryParams : null);
    
    final headers = await _getHeaders();
    final response = await _executeWithRetry(
      () => _client.get(uri, headers: headers),
    );
    
    if (response.statusCode >= 400) {
      throw _handleResponseError(response);
    }
    
    return jsonDecode(response.body);
  }

  /// 发送 POST 请求
  Future<dynamic> _post(String path, {dynamic body, bool withAuth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders(withAuth: withAuth);
    
    final response = await _executeWithRetry(
      () => _client.post(uri, headers: headers, body: jsonEncode(body)),
    );
    
    if (response.statusCode >= 400) {
      throw _handleResponseError(response);
    }
    
    return jsonDecode(response.body);
  }

  /// 发送 PUT 请求
  Future<dynamic> _put(String path, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    
    final response = await _executeWithRetry(
      () => _client.put(uri, headers: headers, body: jsonEncode(body)),
    );
    
    if (response.statusCode >= 400) {
      throw _handleResponseError(response);
    }
    
    return jsonDecode(response.body);
  }

  /// 发送 DELETE 请求
  Future<void> _delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders();
    
    final response = await _executeWithRetry(
      () => _client.delete(uri, headers: headers),
    );
    
    if (response.statusCode >= 400) {
      throw _handleResponseError(response);
    }
  }

  // ==================== 认证接口 ====================

  /// 用户注册
  Future<User> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/register', body: {
      'username': username,
      'email': email,
      'password': password,
    }, withAuth: false);
    return User.fromJson(data);
  }

  /// 用户登录
  Future<AuthToken> login({
    required String username,
    required String password,
  }) async {
    final data = await _post('/auth/login', body: {
      'username': username,
      'password': password,
    }, withAuth: false);
    final authToken = AuthToken.fromJson(data);
    await saveToken(authToken.accessToken);
    return authToken;
  }

  /// 获取当前用户信息
  Future<User> getCurrentUser() async {
    final data = await _get('/auth/me');
    return User.fromJson(data);
  }

  /// 登出
  Future<void> logout() async {
    await clearToken();
  }

  // ==================== 账单接口 ====================

  /// 创建账单
  Future<Bill> createBill(Bill bill) async {
    final data = await _post('/bills/', body: bill.toJson());
    return Bill.fromJson(data);
  }

  /// 获取账单列表
  Future<List<Bill>> getBills({
    int skip = 0,
    int limit = 100,
    String? month,
    String? billType,
    String? worker,
    String? category,
    int? projectId,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (month != null) queryParams['month'] = month;
    if (billType != null) queryParams['bill_type'] = billType;
    if (worker != null) queryParams['worker'] = worker;
    if (category != null) queryParams['category'] = category;
    if (projectId != null) queryParams['project_id'] = projectId.toString();

    final data = await _get('/bills/', queryParams: queryParams);
    return (data as List).map((json) => Bill.fromJson(json)).toList();
  }

  /// 获取单个账单
  Future<Bill> getBill(int billId) async {
    final data = await _get('/bills/$billId');
    return Bill.fromJson(data);
  }

  /// 更新账单
  Future<Bill> updateBill(int billId, BillUpdate update) async {
    final data = await _put('/bills/$billId', body: update.toJson());
    return Bill.fromJson(data);
  }

  /// 删除账单
  Future<void> deleteBill(int billId) async {
    await _delete('/bills/$billId');
  }

  /// 获取账单历史
  Future<List<BillHistory>> getBillHistory(int billId) async {
    final data = await _get('/bills/$billId/history');
    return (data as List).map((json) => BillHistory.fromJson(json)).toList();
  }

  /// 回滚账单版本
  Future<Bill> restoreBillVersion(int historyId) async {
    final data = await _post('/bills/history/$historyId/restore', body: {});
    return Bill.fromJson(data);
  }

  // ==================== 统计接口 ====================

  /// 获取统计（支持单日、单月、日期范围、月份范围）
  Future<BillStatistics> getMonthlyStatistics({
    String? month, 
    String? date, 
    String? startDate,
    String? endDate,
    String? startMonth,
    String? endMonth,
    int? projectId,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;
    if (date != null) queryParams['date'] = date;
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (startMonth != null) queryParams['start_month'] = startMonth;
    if (endMonth != null) queryParams['end_month'] = endMonth;
    if (projectId != null) queryParams['project_id'] = projectId.toString();
    
    final data = await _get('/bills/statistics/monthly', queryParams: queryParams);
    return BillStatistics.fromJson(data);
  }

  /// 获取分类统计
  Future<List<CategoryStatistics>> getCategoryStatistics({String? month, int? projectId}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;
    if (projectId != null) queryParams['project_id'] = projectId.toString();
    
    final data = await _get('/bills/statistics/category', queryParams: queryParams);
    return (data as List).map((json) => CategoryStatistics.fromJson(json)).toList();
  }

  /// 获取名称统计
  Future<List<NameStatistics>> getNameStatistics({
    String? month, 
    String? date, 
    String? startDate,
    String? endDate,
    String? startMonth,
    String? endMonth,
    int? projectId,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;
    if (date != null) queryParams['date'] = date;
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (startMonth != null) queryParams['start_month'] = startMonth;
    if (endMonth != null) queryParams['end_month'] = endMonth;
    if (projectId != null) queryParams['project_id'] = projectId.toString();
    
    final data = await _get('/bills/statistics/name', queryParams: queryParams);
    return (data as List).map((json) => NameStatistics.fromJson(json)).toList();
  }

  /// 导出账单 CSV
  Future<String> exportBillsCsv({String? month}) async {
    final queryParams = month != null ? {'month': month} : <String, String>{};
    final uri = Uri.parse('$baseUrl/bills/export')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final headers = await _getHeaders();
    
    final response = await _executeWithRetry(
      () => _client.get(uri, headers: headers),
    );
    
    if (response.statusCode >= 400) {
      throw _handleResponseError(response);
    }
    
    return response.body;
  }

  // ==================== 项目相关 API ====================
  
  /// 获取所有项目
  Future<List<Project>> getProjects() async {
    final data = await _get('/projects/');
    return (data as List).map((json) => Project.fromJson(json)).toList();
  }

  /// 创建项目
  Future<Project> createProject({
    required String name,
    String? description,
  }) async {
    final body = {
      'name': name,
      if (description != null) 'description': description,
    };
    final data = await _post('/projects/', body: body);
    return Project.fromJson(data);
  }

  /// 更新项目
  Future<Project> updateProject({
    required int projectId,
    String? name,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    
    final data = await _put('/projects/$projectId', body: body);
    return Project.fromJson(data);
  }

  /// 删除项目
  Future<void> deleteProject(int projectId) async {
    await _delete('/projects/$projectId');
  }

  /// 获取项目详情（包含账单）
  Future<Project> getProjectWithBills(int projectId) async {
    final data = await _get('/projects/$projectId');
    return Project.fromJson(data);
  }

  /// 释放资源
  void dispose() {
    _client.close();
  }
}

/// 全局 API 服务实例
final apiService = ApiService();

