import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import 'home_shell.dart';

/// First-run flow. Categories/items are already seeded with your sheet's
/// presets (Needs, Wants, Funds, Investments) by the time this shows, so
/// onboarding now just explains that and gets the first income logged.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _amount = TextEditingController();
  final _name = TextEditingController(text: 'Salary');

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider(widget.userId));
    final notifier = ref.read(financeProvider(widget.userId).notifier);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome', style: AppTheme.serifDisplay(context, size: 28)),
              const SizedBox(height: 8),
              const Text(
                "Your preset categories are ready: Needs, Wants, Funds (savings envelopes) "
                "and Investments — each with starter items from your sheet. Rename, add, or "
                "remove any of them later from Manage Categories.",
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    for (final cat in finance.categories)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                finance.itemsIn(cat.id).map((i) => i.name).join(' · '),
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Log this month's first income (optional)", style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Salary')),
                            const SizedBox(height: 8),
                            TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Amount')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amt = double.tryParse(_amount.text);
                    if (amt != null && amt > 0) {
                      await notifier.addIncome(monthKeyNow(), _name.text.trim().isEmpty ? 'Income' : _name.text.trim(), amt);
                    }
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => HomeShell(userId: widget.userId)),
                      );
                    }
                  },
                  child: const Text('Enter Ledger'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String monthKeyNow() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
