import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/env.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  runApp(const ProviderScope(child: FinanceTrackerApp()));
}

class FinanceTrackerApp extends StatelessWidget {
  const FinanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ledger — Personal Finance Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// signed out -> SignInScreen; signed in and brand new (no income/entries
/// logged yet) -> OnboardingScreen; otherwise -> HomeShell (bottom-nav
/// Dashboard/Budget/Expenses/Funds/Investments).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
      data: (userId) {
        if (userId == null) return const SignInScreen();

        final finance = ref.watch(financeProvider(userId));
        if (finance.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final isBrandNew = finance.incomes.isEmpty && finance.entries.isEmpty;
        return isBrandNew ? OnboardingScreen(userId: userId) : HomeShell(userId: userId);
      },
    );
  }
}
