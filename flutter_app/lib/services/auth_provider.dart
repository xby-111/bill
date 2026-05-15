/// 认证状态管理
/// 
/// 使用 ChangeNotifier 管理用户登录状态
library;

import 'package:flutter/foundation.dart';
import '../models/bill.dart';
import '../services/api_service.dart';

/// 认证状态
enum AuthStatus {
  /// 未知（正在检查）
  unknown,
  /// 已登录
  authenticated,
  /// 未登录
  unauthenticated,
}

/// 认证状态管理器
/// 
/// 负责：
/// - 检查登录状态
/// - 管理用户信息
/// - 处理登录/登出
class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _error;

  /// 当前认证状态
  AuthStatus get status => _status;

  /// 当前用户信息
  User? get user => _user;

  /// 是否已登录
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// 是否正在加载
  bool get isLoading => _status == AuthStatus.unknown;

  /// 错误信息
  String? get error => _error;

  /// 初始化 - 检查是否已登录
  Future<void> init() async {
    _status = AuthStatus.unknown;
    _error = null;
    notifyListeners();

    try {
      final hasToken = await apiService.isLoggedIn;
      if (!hasToken) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // 尝试获取用户信息验证 Token 是否有效
      _user = await apiService.getCurrentUser();
      _status = AuthStatus.authenticated;
    } on ApiException catch (e) {
      if (e.requiresReauth) {
        // Token 过期或无效
        await apiService.clearToken();
        _status = AuthStatus.unauthenticated;
      } else {
        // 网络错误等，保持未知状态让用户重试
        _error = e.message;
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _error = '初始化失败：$e';
      _status = AuthStatus.unauthenticated;
    }
    
    notifyListeners();
  }

  /// 登录成功后刷新用户信息
  Future<void> onLoginSuccess() async {
    try {
      _user = await apiService.getCurrentUser();
      _status = AuthStatus.authenticated;
      _error = null;
    } catch (e) {
      _error = '获取用户信息失败';
    }
    notifyListeners();
  }

  /// 登出
  Future<void> logout() async {
    await apiService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
