import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill.dart';
import '../config/app_config.dart';


class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  String? _token;

  Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    return _token;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final t = await token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  void _handleError(http.Response response) {
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      final detail = body['detail'] ?? '请求失败';
      throw ApiException(response.statusCode, detail.toString());
    }
  }

  Future<User> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    _handleError(response);
    return User.fromJson(jsonDecode(response.body));
  }

  Future<AuthToken> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    _handleError(response);
    final authToken = AuthToken.fromJson(jsonDecode(response.body));
    await saveToken(authToken.accessToken);
    return authToken;
  }

  Future<User> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _getHeaders(),
    );
    _handleError(response);
    return User.fromJson(jsonDecode(response.body));
  }

  Future<Bill> createBill(Bill bill) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bills/'),
      headers: await _getHeaders(),
      body: jsonEncode(bill.toJson()),
    );
    _handleError(response);
    return Bill.fromJson(jsonDecode(response.body));
  }

  Future<List<Bill>> getBills({
    int skip = 0,
    int limit = 100,
    String? month,
    String? billType,
    String? worker,
    String? category,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (month != null) queryParams['month'] = month;
    if (billType != null) queryParams['bill_type'] = billType;
    if (worker != null) queryParams['worker'] = worker;
    if (category != null) queryParams['category'] = category;

    final uri = Uri.parse('$baseUrl/bills/').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());
    _handleError(response);
    
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Bill.fromJson(json)).toList();
  }

  Future<Bill> getBill(int billId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bills/$billId'),
      headers: await _getHeaders(),
    );
    _handleError(response);
    return Bill.fromJson(jsonDecode(response.body));
  }

  Future<Bill> updateBill(int billId, BillUpdate update) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bills/$billId'),
      headers: await _getHeaders(),
      body: jsonEncode(update.toJson()),
    );
    _handleError(response);
    return Bill.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteBill(int billId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/bills/$billId'),
      headers: await _getHeaders(),
    );
    _handleError(response);
  }

  Future<BillStatistics> getMonthlyStatistics(String month) async {
    final uri = Uri.parse('$baseUrl/bills/statistics/monthly')
        .replace(queryParameters: {'month': month});
    final response = await http.get(uri, headers: await _getHeaders());
    _handleError(response);
    return BillStatistics.fromJson(jsonDecode(response.body));
  }

  Future<List<CategoryStatistics>> getCategoryStatistics({String? month}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;

    final uri = Uri.parse('$baseUrl/bills/statistics/category')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(uri, headers: await _getHeaders());
    _handleError(response);
    
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => CategoryStatistics.fromJson(json)).toList();
  }

  Future<List<WorkerStatistics>> getWorkerStatistics({String? month}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;

    final uri = Uri.parse('$baseUrl/bills/statistics/worker')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(uri, headers: await _getHeaders());
    _handleError(response);
    
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => WorkerStatistics.fromJson(json)).toList();
  }

  Future<String> exportBillsCsv({String? month}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;

    final uri = Uri.parse('$baseUrl/bills/export')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response = await http.get(uri, headers: await _getHeaders());
    _handleError(response);
    return response.body;
  }
}


class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}

final apiService = ApiService();
