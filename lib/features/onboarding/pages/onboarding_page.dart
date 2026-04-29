import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _PageData(
      icon: Icons.self_improvement_rounded,
      color: Colors.deepPurple,
      title: 'Welcome to Personal App',
      description:
          'Your all-in-one personal life manager. Organise tasks, track finances, '
          'save recipes, and much more — all in one place.',
    ),
    _PageData(
      icon: Icons.check_circle_rounded,
      color: Colors.blue,
      title: 'Tasks & Calendar',
      description:
          'Keep on top of what needs to be done with Tasks, and never miss '
          'an event with the integrated Calendar view.',
    ),
    _PageData(
      icon: Icons.restaurant_menu_rounded,
      color: Colors.orange,
      title: 'Recipes & Knowledge',
      description:
          'Save favourite recipes with ingredients, instructions, and video links. '
          'Build a personal Knowledge Bank for notes, guides, and references.',
    ),
    _PageData(
      icon: Icons.account_balance_wallet_rounded,
      color: Colors.green,
      title: 'Finances & Inventory',
      description:
          'Track income and expenses, manage assets, and keep a home inventory '
          'so you always know what you have.',
    ),
    _PageData(
      icon: Icons.auto_awesome_rounded,
      color: Colors.indigo,
      title: 'AI, Passwords & More',
      description:
          'Chat with Gemini AI, store passwords securely in the encrypted vault, '
          'manage your shopping list, and explore even more features via the More menu.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).markComplete();
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: !isLast
                    ? TextButton(onPressed: _finish, child: const Text('Skip'))
                    : const SizedBox(height: 40),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) =>
                    _OnboardingSlide(data: _pages[index]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Next / Get Started
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final _PageData data;
  const _OnboardingSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: data.color),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _PageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
