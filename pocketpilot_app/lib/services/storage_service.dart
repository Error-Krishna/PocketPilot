import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  Future<void> setToken(String token) async =>
      await _storage.write(key: 'auth_token', value: token);
  Future<String?> getToken() async =>
      await _storage.read(key: 'auth_token');
  Future<void> deleteToken() async =>
      await _storage.delete(key: 'auth_token');

  Future<void> setOnboardingCompleted(bool value) async =>
      await _storage.write(key: 'onboarding_completed', value: value.toString());
  Future<bool> getOnboardingCompleted() async {
    final val = await _storage.read(key: 'onboarding_completed');
    return val == 'true';
  }
}