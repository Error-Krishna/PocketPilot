import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthService(this._api);

  Future<bool> isSignedIn() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await _refreshToken();
    return true;
  }

  Future<void> _refreshToken() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final token = await user.getIdToken(true);
    if (token == null) throw Exception('Failed to obtain auth token');
    await _api.setAuthToken(token);
  }

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final token = await userCredential.user!.getIdToken(true);
    if (token == null) throw Exception('Failed to obtain auth token');
    await _api.setAuthToken(token);

    try {
      await _api.getCurrentUser();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          e.response?.data?['success'] == false) {
        await _api.registerUser();
      }
    } catch (_) {
      await _api.registerUser();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _api.clearAuthToken();
  }
}