abstract final class AppRoutes {
  static const String home = habits;
  static const String habits = '/habits';
  static const String habitCreate = '/habits/new';
  static const String tracking = '/tracking';
  static const String progress = '/progress';
  static const String goals = '/goals';
  static const String goalCreate = '/goals/new';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String profile = '/profile';
  static const String community = '/community';
  static const String inspiration = '/inspiration';
  static const String admin = '/admin';

  static String habitEdit(String habitId) => '/habits/$habitId/edit';
  static String habitReminders(String habitId) =>
      '/habits/${Uri.encodeComponent(habitId)}/reminders';
  static String goalDetail(String goalId) => '/goals/$goalId';
  static String goalEdit(String goalId) => '/goals/$goalId/edit';
  static String inspirationDetail(String inspirationId) =>
      '$inspiration/${Uri.encodeComponent(inspirationId)}';
}
