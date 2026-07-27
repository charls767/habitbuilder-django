import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_routes.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const _ScaffoldScreen(),
      ),
    ],
  );
}

class _ScaffoldScreen extends StatelessWidget {
  const _ScaffoldScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('HabitBuilder')));
  }
}
