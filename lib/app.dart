import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';

/// Placeholder root route — replaced by the real auth/home flow starting
/// with the HBM-8 (registration/login) and HBM-1 epic tickets.
final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const _ScaffoldPlaceholder(),
    ),
  ],
);

class HabitBuilderApp extends StatelessWidget {
  const HabitBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HabitBuilder',
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('HabitBuilder — scaffold only, see Jira epic HBM-1'),
      ),
    );
  }
}
