import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class ReminderReconciliationBootstrap extends ConsumerWidget {
  const ReminderReconciliationBootstrap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => child;
}
