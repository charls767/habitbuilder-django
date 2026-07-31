import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../domain/admin_entities.dart';
import 'admin_providers.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminAccessProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Administraci\u00F3n')),
      body: access.when(
        data: (isAdmin) => isAdmin ? const _AdminTabs() : const _Forbidden(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AdminError(
          error: error,
          onRetry: () => ref.invalidate(adminAccessProvider),
        ),
      ),
    );
  }
}

class _AdminTabs extends StatelessWidget {
  const _AdminTabs();
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.insights_outlined), text: 'Uso'),
            Tab(icon: Icon(Icons.people_outline), text: 'Usuarios'),
            Tab(icon: Icon(Icons.flag_outlined), text: 'Moderaci\u00F3n'),
          ],
        ),
        const Expanded(
          child: TabBarView(
            children: [_UsageTab(), _UsersTab(), _ModerationTab()],
          ),
        ),
      ],
    ),
  );
}

class _UsageTab extends ConsumerWidget {
  const _UsageTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(adminUsageProvider);
    return AppContent(
      child: usage.when(
        data: (value) => RefreshIndicator(
          onRefresh: () async => ref.refresh(adminUsageProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Resumen de uso',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${_date(value.from)} - ${_date(value.to)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(label: 'Usuarios activos', value: value.activeUsers),
                  _Metric(label: 'Registrados', value: value.registeredUsers),
                  _Metric(label: 'H\u00E1bitos creados', value: value.habits),
                  _Metric(label: 'Registros', value: value.records),
                  _Metric(label: 'Publicaciones', value: value.publications),
                ],
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AdminError(
          error: error,
          onRetry: () => ref.invalidate(adminUsageProvider),
        ),
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    return AppContent(
      child: users.when(
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.refresh(adminUsersProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _UserCard(user: items[index]),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AdminError(
          error: error,
          onRetry: () => ref.invalidate(adminUsersProvider),
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});
  final AdminUser user;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      title: Text(user.name),
      subtitle: Text('${user.email}\n${user.role} \u00B7 ${user.status}'),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: user.status == 'activo'
                ? 'Suspender usuario'
                : 'Reactivar usuario',
            icon: Icon(
              user.status == 'activo'
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
            onPressed: () => _changeStatus(context, ref),
          ),
          PopupMenuButton<String>(
            tooltip: 'Cambiar rol',
            onSelected: (role) => _changeRole(context, ref, role),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'admin', child: Text('Administrador')),
              PopupMenuItem(value: 'regular', child: Text('Usuario')),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    final next = user.status == 'activo' ? 'suspendido' : 'activo';
    final reason = await _reasonDialog(
      context,
      next == 'suspendido' ? 'Suspender usuario' : 'Reactivar usuario',
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .changeUserStatus(user.id, next, reason);
      ref.invalidate(adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Estado actualizado.')));
      }
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    String role,
  ) async {
    if (role == user.role) return;
    final reason = await _reasonDialog(context, 'Cambiar rol a $role');
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .changeUserRole(user.id, role, reason);
      ref.invalidate(adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rol actualizado.')));
      }
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

class _ModerationTab extends ConsumerWidget {
  const _ModerationTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(moderationQueueProvider);
    return AppContent(
      child: reports.when(
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.refresh(moderationQueueProvider.future),
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(child: Text('No hay reportes pendientes.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _ReportCard(report: items[index]),
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AdminError(
          error: error,
          onRetry: () => ref.invalidate(moderationQueueProvider),
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});
  final ModerationReport report;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      title: Text('Publicaci\u00F3n ${report.publicationId}'),
      subtitle: Text(
        '${report.reason}\n${report.detail.isEmpty ? 'Sin detalle adicional' : report.detail}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        tooltip: 'Resolver reporte',
        onSelected: (resolution) async {
          final reason = await _reasonDialog(context, 'Resolver reporte');
          if (reason == null || !context.mounted) return;
          try {
            await ref
                .read(adminRepositoryProvider)
                .resolveModeration(report.id, resolution, reason);
            ref.invalidate(moderationQueueProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte resuelto.')),
              );
            }
          } on ApiException catch (error) {
            if (context.mounted) _showError(context, error.message);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'ocultar',
            child: Text('Ocultar publicaci\u00F3n'),
          ),
          PopupMenuItem(value: 'descartar', child: Text('Descartar reporte')),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _Forbidden extends StatelessWidget {
  const _Forbidden();
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('No tienes permisos para acceder a esta secci\u00F3n.'),
  );
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Reintentar'),
    ),
  );
}

Future<String?> _reasonDialog(BuildContext context, String title) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});
  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Raz\u00F3n obligatoria'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_controller.text.trim().isNotEmpty) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Confirmar'),
      ),
    ],
  );
}

void _showError(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
