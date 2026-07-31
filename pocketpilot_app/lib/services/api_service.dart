import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/autopay.dart';
import '../models/budget_summary.dart';
import '../models/monthly_archive.dart';
import '../models/spend_trend.dart';
import '../models/bank_account.dart';

class ApiService {
  // Pass the backend URL at run/build time, e.g.:
  //   flutter run --dart-define=API_URL=http://<your-mac-ip>:8000/api/v1
  // Falls back to localhost (works for iOS simulator only, not physical
  // devices/Android emulator) if not provided.
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
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
    } on DioException {
      rethrow;
    }
  }

  Future<User> updateUser(Map<String, dynamic> updates) async {
    try {
      final res = await _dio.patch(
        '/users/me',
        data: updates,
      );

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

  /// Simple day-by-day discretionary spend series for the quick-glance
  /// trend card. [days] is clamped server-side to a sane range.
  Future<List<SpendTrendPoint>> getSpendTrend({int days = 7}) async {
    final res = await _dio.get('/budget/trend', queryParameters: {'days': days});
    if (res.data['success'] == true) {
      final series = res.data['data']['series'] as List;
      return series.map((j) => SpendTrendPoint.fromJson(j)).toList();
    }
    throw Exception('Failed to get spend trend');
  }

  // FIX: Return a map with inserted/skipped counts, plus an optional
  // reset-candidate transaction id when a credit matching the user's
  // monthly_budget was detected as reset-eligible (see routers/sms.py).
  Future<Map<String, dynamic>> syncSmsTransactions(
      List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) {
      return {'inserted': 0, 'skipped': 0, 'resetCandidateTransactionId': null};
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
        'resetCandidateTransactionId':
            data['reset_candidate_transaction_id'] as String?,
      };
    } on DioException {
      rethrow;
    }
  }

  /// Confirms or declines a detected monthly reset. On confirm, the
  /// backend archives the ending cycle, rolls its savings into
  /// lifetime_savings, and starts a fresh cycle from now.
  Future<Map<String, dynamic>> confirmReset(
      String transactionId, bool confirmed) async {
    final res = await _dio.post(
      '/reset/confirm',
      data: {'transaction_id': transactionId, 'confirmed': confirmed},
    );
    if (res.data['success'] == true) {
      return res.data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to confirm reset');
  }

  /// Past cycle summaries plus the current lifetime savings total, for
  /// the "last month" glance and history drill-down on the dashboard.
  Future<(List<MonthlyArchive>, double)> getResetHistory() async {
    final res = await _dio.get('/reset/history');
    if (res.data['success'] == true) {
      final data = res.data['data'] as Map<String, dynamic>;
      final history = (data['history'] as List)
          .map((j) => MonthlyArchive.fromJson(j))
          .toList();
      final lifetimeSavings = (data['lifetimeSavings'] as num).toDouble();
      return (history, lifetimeSavings);
    }
    throw Exception('Failed to get reset history');
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

  Future<SavingsGoal> createSavingsGoal(SavingsGoalCreate data) async {
    final res = await _dio.post('/savings', data: data.toJson());
    if (res.data['success'] == true) {
      return SavingsGoal.fromJson(res.data['data']);
    }
    throw Exception('Failed to create savings goal');
  }

  Future<SavingsGoal> updateSavingsGoal(
      String id, SavingsGoalUpdate data) async {
    final res = await _dio.patch('/savings/$id', data: data.toJson());
    if (res.data['success'] == true) {
      return SavingsGoal.fromJson(res.data['data']);
    }
    throw Exception('Failed to update savings goal');
  }

  Future<void> deleteSavingsGoal(String id) async {
    await _dio.delete('/savings/$id');
  }

  /// Free-text identifiers (e.g. "hdfc savings", "dad's account") the
  /// classifier matches against SMS text to detect transfers between the
  /// user's own accounts, keeping them out of discretionary spend.
  Future<List<String>> getSelfAccounts() async {
    final res = await _dio.get('/settings/self-accounts');
    if (res.data['success'] == true) {
      return List<String>.from(res.data['data']['accounts'] ?? []);
    }
    throw Exception('Failed to get self accounts');
  }

  Future<List<String>> setSelfAccounts(List<String> accounts) async {
    final res = await _dio.put(
      '/settings/self-accounts',
      data: {'accounts': accounts},
    );
    if (res.data['success'] == true) {
      return List<String>.from(res.data['data']['accounts'] ?? []);
    }
    throw Exception('Failed to update self accounts');
  }

  /// Transactions the rule-based classifier could not confidently place.
  Future<List<Transaction>> getReviewQueue() async {
    final res = await _dio.get('/review/queue');
    if (res.data['success'] == true) {
      return (res.data['data'] as List)
          .map((j) => Transaction.fromJson(j))
          .toList();
    }
    throw Exception('Failed to get review queue');
  }

  Future<int> getReviewQueueCount() async {
    final res = await _dio.get('/review/queue/count');
    if (res.data['success'] == true) {
      return (res.data['data']['count'] as num).toInt();
    }
    throw Exception('Failed to get review queue count');
  }

  /// User confirms/corrects a transaction's class from the review queue.
  Future<Transaction> confirmClassification(
      String transactionId, TransactionClass txnClass) async {
    final res = await _dio.patch(
      '/review/$transactionId',
      data: {'txn_class': txnClass.wireValue},
    );
    if (res.data['success'] == true) {
      return Transaction.fromJson(res.data['data']);
    }
    throw Exception('Failed to confirm classification');
  }

  // --- Bank accounts ---

  Future<List<BankAccount>> getBankAccounts() async {
    final res = await _dio.get('/bank-accounts');
    if (res.data['success'] == true) {
      return (res.data['data'] as List)
          .map((j) => BankAccount.fromJson(j))
          .toList();
    }
    throw Exception('Failed to get bank accounts');
  }

  Future<BankAccount> createBankAccount(BankAccountCreate data) async {
    final res = await _dio.post('/bank-accounts', data: data.toJson());
    if (res.data['success'] == true) {
      return BankAccount.fromJson(res.data['data']);
    }
    throw Exception('Failed to create bank account');
  }

  Future<BankAccount> updateBankAccount(
      String id, BankAccountUpdate data) async {
    final res = await _dio.patch('/bank-accounts/$id', data: data.toJson());
    if (res.data['success'] == true) {
      return BankAccount.fromJson(res.data['data']);
    }
    throw Exception('Failed to update bank account');
  }

  Future<void> deleteBankAccount(String id) async {
    await _dio.delete('/bank-accounts/$id');
  }

  /// User confirms the informational bank-balance figure is accurate, or
  /// corrects it. [applyToCycle] additionally makes the corrected figure
  /// this cycle's real starting balance for budget math (see
  /// cycle_starting_balance docs backend-side) — opt-in, since confirming
  /// display accuracy and changing the actual math are different actions.
  Future<User> confirmOrCorrectBankBalance({
    required bool confirmed,
    double? correctedBalance,
    bool applyToCycle = false,
  }) async {
    final res = await _dio.post(
      '/users/me/bank-balance',
      data: {
        'confirmed': confirmed,
        if (correctedBalance != null) 'corrected_balance': correctedBalance,
        'apply_to_cycle': applyToCycle,
      },
    );
    if (res.data['success'] == true) {
      return User.fromJson(res.data['data']);
    }
    throw Exception('Failed to update bank balance');
  }
}