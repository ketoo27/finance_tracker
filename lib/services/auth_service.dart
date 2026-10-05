import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._supabase);
  final SupabaseClient _supabase;

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  Future<void> signUpWithEmail(String email, String password) async {
    await _supabase.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Google sign-in via Supabase OAuth. Requires the Google provider to be
  /// configured in Supabase Auth settings, and the Android app's SHA-1
  /// fingerprint + package name registered there (see README).
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.financetracker://login-callback/',
    );
  }

  Future<void> signOut() => _supabase.auth.signOut();
}
