import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/autopay.dart';
import '../models/budget_summary.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.29.167:8000/api/v1';
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
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

  // User
  Future<User> getCurrentUser() async {
    final res = await _dio.get('/users/me');
    if (res.data['success'] == true) {
      return User.fromJson(res.data['data']);
    }
    throw Exception('Failed to get user');
  }

  Future<User> registerUser() async {
    final res = await _dio.post('/users/register');
    if (res.data['success'] == true) {
      return User.fromJson(res.data['data']);
    }
    throw Exception('Registration failed');
  }

  Future<User> updateUser(Map<String, dynamic> updates) async {
    final res = await _dio.patch('/users/me', data: updates);
    if (res.data['success'] == true) {
      return User.fromJson(res.data['data']);
    }
    throw Exception('Update failed');
  }

  // Transactions
  Future<List<Transaction>> getTransactions() async {
    final res = await _dio.get('/transactions');
    if (res.data['success'] == true) {
      return (res.data['data'] as List)
          .map((j) => Transaction.fromJson(j))
          .toList();
    }
    throw Exception();
  }

  Future<Transaction> createTransaction(TransactionCreate data) async {
    final res = await _dio.post('/transactions', data: data.toJson());
    if (res.data['success'] == true) {
      return Transaction.fromJson(res.data['data']);
    }
    throw Exception();
  }

  Future<void> deleteTransaction(String id) async {
    await _dio.delete('/transactions/$id');
  }

  // Autopays
  Future<List<Autopay>> getAutopays() async {
    final res = await _dio.get('/autopays');
    if (res.data['success'] == true) {
      return (res.data['data'] as List)
          .map((j) => Autopay.fromJson(j))
          .toList();
    }
    throw Exception();
  }

  Future<Autopay> createAutopay(AutopayCreate data) async {
    final res = await _dio.post('/autopays', data: data.toJson());
    if (res.data['success'] == true) {
      return Autopay.fromJson(res.data['data']);
    }
    throw Exception();
  }

  Future<Autopay> updateAutopay(String id, AutopayUpdate data) async {
    final res = await _dio.patch('/autopays/$id', data: data.toJson());
    if (res.data['success'] == true) {
      return Autopay.fromJson(res.data['data']);
    }
    throw Exception();
  }

  Future<void> deleteAutopay(String id) async {
    await _dio.delete('/autopays/$id');
  }

  // Budget summary
  Future<BudgetSummary> getBudgetSummary() async {
    final res = await _dio.get('/budget/summary');
    if (res.data['success'] == true) {
      return BudgetSummary.fromJson(res.data['data']);
    }
    throw Exception();
  }

  // Savings goals (list all)
  Future<List<SavingsGoal>> getSavingsGoals() async {
    final res = await _dio.get('/savings');
    if (res.data['success'] == true) {
      return (res.data['data'] as List)
          .map((j) => SavingsGoal.fromJson(j))
          .toList();
    }
    throw Exception();
  }
}