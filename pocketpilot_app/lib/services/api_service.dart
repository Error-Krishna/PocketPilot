import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/autopay.dart';
import '../models/budget_summary.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.29.67:8000/api/v1',
  );

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        return handler.next(options);
      },
    ));
  }

  Future<void> setAuthToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> clearAuthToken() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<User> getCurrentUser() async {
    final res = await _dio.get('/users/me');
    if (res.data['success'] == true) {
      return User.fromJson(res.data['data']);
    }
    throw Exception('Failed to get user');
  }

  Future<User> registerUser() async {
    try {
      final res = await _dio.post('/users/register');

      if (res.data['success'] == true) {
        return User.fromJson(res.data['data']);
      }

      throw Exception('Registration failed');
    } on DioException catch (e) {
      print('REGISTER ERROR STATUS: ${e.response?.statusCode}');
      print('REGISTER ERROR DATA: ${e.response?.data}');
      rethrow;
    }
  }

  Future<User> updateUser(Map<String, dynamic> updates) async {
    try {
      print('SENDING UPDATE: $updates');

      final res = await _dio.patch(
        '/users/me',
        data: updates,
      );

      print('STATUS: ${res.statusCode}');
      print('DATA: ${res.data}');

      if (res.data['success'] == true) {
        return User.fromJson(res.data['data']);
      }

      throw Exception('Update failed');
    } on DioException {
      rethrow;
    }
  }

  Future<List<Transaction>> getTransactions() async {
    final res = await _dio.get('/transactions');
    if (res.data['success'] == true) {
      return (res.data['data'] as List)
          .map((j) => Transaction.fromJson(j))
          .toList();
    }
    throw Exception('Failed to get transactions');
  }

  Future<Transaction> createTransaction(TransactionCreate data) async {
    final res = await _dio.post('/transactions', data: data.toJson());
    if (res.data['success'] == true) {
      return Transaction.fromJson(res.data['data']);
    }
    throw Exception('Failed to create transaction');
  }

  Future<void> deleteTransaction(String id) async {
    await _dio.delete('/transactions/$id');
  }

  Future<List<Autopay>> getAutopays() async {
    final res = await _dio.get('/autopays');
    if (res.data['success'] == true) {
      return (res.data['data'] as List)
          .map((j) => Autopay.fromJson(j))
          .toList();
    }
    throw Exception('Failed to get autopays');
  }

  Future<Autopay> createAutopay(AutopayCreate data) async {
    final res = await _dio.post('/autopays', data: data.toJson());
    if (res.data['success'] == true) {
      return Autopay.fromJson(res.data['data']);
    }
    throw Exception('Failed to create autopay');
  }

  Future<Autopay> updateAutopay(String id, AutopayUpdate data) async {
    final res = await _dio.patch('/autopays/$id', data: data.toJson());
    if (res.data['success'] == true) {
      return Autopay.fromJson(res.data['data']);
    }
    throw Exception('Failed to update autopay');
  }

  Future<void> deleteAutopay(String id) async {
    await _dio.delete('/autopays/$id');
  }

  Future<BudgetSummary> getBudgetSummary() async {
    final res = await _dio.get('/budget/summary');
    if (res.data['success'] == true) {
      return BudgetSummary.fromJson(res.data['data']);
    }
    throw Exception('Failed to get budget summary');
  }

  // FIX: Return a map with inserted/skipped counts
  Future<Map<String, int>> syncSmsTransactions(
      List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) {
      return {'inserted': 0, 'skipped': 0};
    }

    try {
      final res = await _dio.post(
        '/sms/sync',
        data: {'transactions': transactions},
      );

      if (res.data['success'] != true) {
        throw Exception('SMS sync failed: ${res.data['error']}');
      }

      final data = res.data['data'] as Map<String, dynamic>;
      return {
        'inserted': (data['inserted'] as num).toInt(),
        'skipped': (data['skipped'] as num).toInt(),
      };
    } on DioException catch (e) {
      print('SMS SYNC ERROR STATUS: ${e.response?.statusCode}');
      print('SMS SYNC ERROR DATA: ${e.response?.data}');
      rethrow;
    }
  }

  Future<List<SavingsGoal>> getSavingsGoals() async {
    final res = await _dio.get('/savings');
    if (res.data['success'] == true) {
      return (res.data['data'] as List)
          .map((j) => SavingsGoal.fromJson(j))
          .toList();
    }
    throw Exception('Failed to get savings goals');
  }
}