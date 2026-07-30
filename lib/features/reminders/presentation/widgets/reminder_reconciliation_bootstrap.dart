import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/auth_session_controller.dart';
import '../providers/reminder_providers.dart';

final class ReminderReconciliationBootstrap extends ConsumerStatefulWidget {
  const ReminderReconciliationBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderReconciliationBootstrap> createState() =>
      _ReminderReconciliationBootstrapState();
}

final class _ReminderReconciliationBootstrapState
    extends ConsumerState<ReminderReconciliationBootstrap>
    with WidgetsBindingObserver {
  late final ProviderSubscription<AsyncValue<bool>> _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = ref.listenManual(authSessionControllerProvider, (
      previous,
      next,
    ) {
      final becameAuthenticated = next.value == true && previous?.value != true;
      if (becameAuthenticated) {
        unawaited(_reconcile());
      }
    }, fireImmediately: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authSessionControllerProvider).value == true) {
      unawaited(_reconcile());
    }
  }

  Future<void> _reconcile() {
    return ref.read(reminderReconciliationRequestProvider)();
  }

  @override
  void dispose() {
    _authSubscription.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
