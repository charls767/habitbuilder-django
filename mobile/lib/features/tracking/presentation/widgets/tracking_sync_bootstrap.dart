import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/auth_session_controller.dart';
import '../providers/tracking_providers.dart';

final class TrackingSyncBootstrap extends ConsumerStatefulWidget {
  const TrackingSyncBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TrackingSyncBootstrap> createState() =>
      _TrackingSyncBootstrapState();
}

final class _TrackingSyncBootstrapState
    extends ConsumerState<TrackingSyncBootstrap>
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
      if (becameAuthenticated) unawaited(_sync());
    }, fireImmediately: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authSessionControllerProvider).value == true) {
      unawaited(_sync());
    }
  }

  Future<void> _sync() async {
    try {
      await ref.read(trackingSyncRequestProvider)();
      if (mounted) ref.invalidate(trackingLogProvider);
    } on Object {
      return;
    }
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
