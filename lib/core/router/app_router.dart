import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/goals/presentation/screens/goal_detail_screen.dart';
import '../../features/goals/presentation/screens/goal_form_screen.dart';
import '../../features/goals/presentation/screens/goals_list_screen.dart';
import '../../features/habits/presentation/screens/habit_form_screen.dart';
import '../../features/habits/presentation/screens/habits_list_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/reminders/presentation/screens/reminders_screen.dart';
import '../../features/tracking/presentation/screens/tracking_screen.dart';
import '../network/auth_session_controller.dart';
import 'app_routes.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authSession = ref.watch(authSessionControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final isPublicRoute = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
      }.contains(state.matchedLocation);
      final isAuthenticated = authSession.value ?? false;

      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isPublicRoute) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          initialToken: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: AppRoutes.habits,
        builder: (context, state) => const HabitsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.tracking,
        builder: (context, state) => const TrackingScreen(),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (context, state) => const ProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.habitCreate,
        builder: (context, state) => const HabitFormScreen(),
      ),
      GoRoute(
        path: '/habits/:habitId/edit',
        builder: (context, state) =>
            HabitFormScreen(habitId: state.pathParameters['habitId']!),
      ),
      GoRoute(
        path: '/habits/:habitId/reminders',
        builder: (context, state) =>
            RemindersScreen(habitId: state.pathParameters['habitId']!),
      ),
      GoRoute(
        path: AppRoutes.goals,
        builder: (context, state) => const GoalsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.goalCreate,
        builder: (context, state) => const GoalFormScreen(),
      ),
      GoRoute(
        path: '/goals/:goalId',
        builder: (context, state) =>
            GoalDetailScreen(goalId: state.pathParameters['goalId']!),
      ),
      GoRoute(
        path: '/goals/:goalId/edit',
        builder: (context, state) =>
            GoalFormScreen(goalId: state.pathParameters['goalId']!),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
}

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authSessionControllerProvider, (_, _) => notifyListeners());
  }
}
