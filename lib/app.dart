import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/auth_session_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/presentation/providers/profile_providers.dart';
import 'features/reminders/presentation/widgets/reminder_reconciliation_bootstrap.dart';

class HabitBuilderApp extends ConsumerWidget {
  const HabitBuilderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final authSession = ref.watch(authSessionControllerProvider);
    final profile = authSession.value == true
        ? ref.watch(myProfileProvider).value
        : null;
    final accessibility = profile?.accessibility;

    return MaterialApp.router(
      title: 'HabitBuilder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(highContrast: accessibility?.highContrast ?? false),
      darkTheme: AppTheme.dark(
        highContrast: accessibility?.highContrast ?? false,
      ),
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return ReminderReconciliationBootstrap(
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(
                accessibility?.textSize.scaleFactor ?? 1,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
