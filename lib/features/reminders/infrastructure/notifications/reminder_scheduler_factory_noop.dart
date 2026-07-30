import '../../domain/services/reminder_scheduler.dart';
import 'noop_reminder_scheduler.dart';

ReminderScheduler createReminderScheduler() => NoopReminderScheduler();
