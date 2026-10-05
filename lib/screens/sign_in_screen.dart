import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authServiceProvider);
      if (_isSignUp) {
        await auth.signUpWithEmail(_email.text.trim(), _password.text);
      } else {
        await auth.signInWithEmail(_email.text.trim(), _password.text);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.savings_rounded, color: AppColors.gold, size: 40),
              const SizedBox(height: 16),
              Text('Ledger', style: AppTheme.serifDisplay(context, size: 34, color: Colors.white)),
              const SizedBox(height: 4),
              const Text(
                'Your personal finance passbook, synced across devices.',
                style: TextStyle(color: Color(0xFF8FB0A9), fontSize: 13),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Email', filled: true, fillColor: Color(0xFF1C4643)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Password', filled: true, fillColor: Color(0xFF1C4643)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.tealDeep),
                child: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isSignUp ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => ref.read(authServiceProvider).signInWithGoogle(),
                icon: const Icon(Icons.g_mobiledata, color: Colors.white),
                label: const Text('Continue with Google', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF2E6A64))),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? 'Already have an account? Sign in' : "New here? Create an account",
                  style: const TextStyle(color: Color(0xFF8FB0A9), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
