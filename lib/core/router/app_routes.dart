abstract final class AppRoutes {
  static const String home = habits;
  static const String habits = '/habits';
  static const String habitCreate = '/habits/new';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String profile = '/profile';

  static String habitEdit(String habitId) => '/habits/$habitId/edit';
}
