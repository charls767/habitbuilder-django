import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../data/admin_repository.dart';
import '../domain/admin_entities.dart';
import 'admin_inspiration_screen.dart';
import 'admin_requests_screen.dart';
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

class _AdminTabs extends StatefulWidget {
  const _AdminTabs();

  @override
  State<_AdminTabs> createState() => _AdminTabsState();
}

class _AdminTabsState extends State<_AdminTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 5, vsync: this);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      final content = Expanded(
        child: TabBarView(
          controller: _controller,
          children: const [
            _UsageTab(),
            _UsersTab(),
            _ModerationTab(),
            AdminInspirationScreen(),
            AdminRequestsScreen(),
          ],
        ),
      );
      if (desktop) {
        return Row(
          children: [
            NavigationRail(
              selectedIndex: _controller.index,
              onDestinationSelected: _controller.animateTo,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: Text('Uso'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Usuarios'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.flag_outlined),
                  selectedIcon: Icon(Icons.flag),
                  label: Text('Moderaci\u00F3n'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.lightbulb_outline),
                  selectedIcon: Icon(Icons.lightbulb),
                  label: Text('Inspiraci\u00F3n'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.how_to_reg_outlined),
                  selectedIcon: Icon(Icons.how_to_reg),
                  label: Text('Solicitudes'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            content,
          ],
        );
      }
      return Column(
        children: [
          TabBar(
            controller: _controller,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.insights_outlined), text: 'Uso'),
              Tab(icon: Icon(Icons.people_outline), text: 'Usuarios'),
              Tab(icon: Icon(Icons.flag_outlined), text: 'Moderaci\u00F3n'),
              Tab(
                icon: Icon(Icons.lightbulb_outline),
                text: 'Inspiraci\u00F3n',
              ),
              Tab(icon: Icon(Icons.how_to_reg_outlined), text: 'Solicitudes'),
            ],
          ),
          content,
        ],
      );
    },
  );
}

class _UsageTab extends ConsumerStatefulWidget {
  const _UsageTab();

  @override
  ConsumerState<_UsageTab> createState() => _UsageTabState();
}

class _UsageTabState extends ConsumerState<_UsageTab> {
  late Future<AdminUsage> _future;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminUsage> _load() => ref
      .read(adminRepositoryProvider)
      .usage(from: _from?.toIso8601String(), to: _to?.toIso8601String());

  Future<void> _pickDate(bool from) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: from ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
    );
    if (value == null) return;
    setState(() {
      if (from) {
        _from = value;
      } else {
        _to = value.add(const Duration(days: 1));
      }
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => AppContent(
    maxWidth: 1100,
    child: FutureBuilder<AdminUsage>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminError(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }
        final value = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(() {
            _future = _load();
          }),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Resumen de uso',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text('${_date(value.from)} - ${_date(value.to)}'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_from == null ? 'Desde' : _date(_from!)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.event),
                    label: Text(_to == null ? 'Hasta' : _date(_to!)),
                  ),
                  if (_from != null || _to != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _from = null;
                        _to = null;
                        _future = _load();
                      }),
                      child: const Text('Limpiar periodo'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
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
        );
      },
    ),
  );
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _search = TextEditingController();
  String? _status;
  String? _role;
  int _offset = 0;
  late Future<List<AdminUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<AdminUser>> _load() => ref
      .read(adminRepositoryProvider)
      .users(
        search: _search.text,
        status: _status,
        role: _role,
        offset: _offset,
      );

  void _applyFilters() => setState(() {
    _offset = 0;
    _future = _load();
  });

  @override
  Widget build(BuildContext context) => AppContent(
    maxWidth: 1100,
    child: FutureBuilder<List<AdminUser>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminError(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }
        final items = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 800;
            return RefreshIndicator(
              onRefresh: () async => setState(() {
                _future = _load();
              }),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _UserFilters(
                    search: _search,
                    status: _status,
                    role: _role,
                    onStatusChanged: (v) {
                      _status = v;
                      _applyFilters();
                    },
                    onRoleChanged: (v) {
                      _role = v;
                      _applyFilters();
                    },
                    onSubmit: _applyFilters,
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No hay usuarios para estos filtros.'),
                      ),
                    )
                  else if (desktop)
                    _UsersTable(
                      items: items,
                      onChanged: () => setState(() {
                        _future = _load();
                      }),
                    )
                  else
                    ...items.map(
                      (user) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _UserCard(
                          user: user,
                          onChanged: () => setState(() {
                            _future = _load();
                          }),
                        ),
                      ),
                    ),
                  _Pager(
                    hasNext: items.length == 50,
                    hasPrevious: _offset > 0,
                    onPrevious: () => setState(() {
                      _offset -= 50;
                      _future = _load();
                    }),
                    onNext: () => setState(() {
                      _offset += 50;
                      _future = _load();
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class _UserFilters extends StatelessWidget {
  const _UserFilters({
    required this.search,
    required this.status,
    required this.role,
    required this.onStatusChanged,
    required this.onRoleChanged,
    required this.onSubmit,
  });
  final TextEditingController search;
  final String? status;
  final String? role;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 280,
        child: TextField(
          controller: search,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: 'Buscar nombre o correo',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      DropdownButton<String?>(
        value: status,
        hint: const Text('Estado'),
        items: const [
          DropdownMenuItem(value: null, child: Text('Todos los estados')),
          DropdownMenuItem(value: 'activo', child: Text('Activo')),
          DropdownMenuItem(value: 'suspendido', child: Text('Suspendido')),
        ],
        onChanged: onStatusChanged,
      ),
      DropdownButton<String?>(
        value: role,
        hint: const Text('Rol'),
        items: const [
          DropdownMenuItem(value: null, child: Text('Todos los roles')),
          DropdownMenuItem(value: 'admin', child: Text('Administrador')),
          DropdownMenuItem(value: 'regular', child: Text('Usuario')),
        ],
        onChanged: onRoleChanged,
      ),
      FilledButton.icon(
        onPressed: onSubmit,
        icon: const Icon(Icons.filter_alt),
        label: const Text('Aplicar'),
      ),
    ],
  );
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({required this.items, required this.onChanged});
  final List<AdminUser> items;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Correo')),
          DataColumn(label: Text('Rol')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: items
            .map(
              (user) => DataRow(
                cells: [
                  DataCell(Text(user.name)),
                  DataCell(Text(user.email)),
                  DataCell(Text(user.role)),
                  DataCell(Text(user.status)),
                  DataCell(_UserActions(user: user, onChanged: onChanged)),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onChanged});
  final AdminUser user;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(user.name),
      subtitle: Text('${user.email}\n${user.role} \u00B7 ${user.status}'),
      isThreeLine: true,
      trailing: _UserActions(user: user, onChanged: onChanged),
    ),
  );
}

class _UserActions extends ConsumerWidget {
  const _UserActions({required this.user, required this.onChanged});
  final AdminUser user;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
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
      onChanged();
      if (context.mounted) _showMessage(context, 'Estado actualizado.');
    } on ApiException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
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
      onChanged();
      if (context.mounted) _showMessage(context, 'Rol actualizado.');
    } on ApiException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    }
  }
}

class _ModerationTab extends ConsumerStatefulWidget {
  const _ModerationTab();
  @override
  ConsumerState<_ModerationTab> createState() => _ModerationTabState();
}

class _ModerationTabState extends ConsumerState<_ModerationTab> {
  int _offset = 0;
  late Future<List<ModerationReport>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ModerationReport>> _load() =>
      ref.read(adminRepositoryProvider).moderationQueue(offset: _offset);

  @override
  Widget build(BuildContext context) => AppContent(
    maxWidth: 1000,
    child: FutureBuilder<List<ModerationReport>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminError(
            error: snapshot.error!,
            onRetry: () => setState(() {
              _future = _load();
            }),
          );
        }
        final items = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(() {
            _future = _load();
          }),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No hay reportes pendientes.')),
                )
              else
                ...items.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReportCard(
                      report: report,
                      onChanged: () => setState(() {
                        _future = _load();
                      }),
                    ),
                  ),
                ),
              _Pager(
                hasNext: items.length == 50,
                hasPrevious: _offset > 0,
                onPrevious: () => setState(() {
                  _offset -= 50;
                  _future = _load();
                }),
                onNext: () => setState(() {
                  _offset += 50;
                  _future = _load();
                }),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report, required this.onChanged});
  final ModerationReport report;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      onTap: () => _showPublication(context, ref),
      title: Text('Publicaci\u00F3n ${report.publicationId}'),
      subtitle: Text(
        '${report.reason}\n${report.detail.isEmpty ? 'Sin detalle adicional' : report.detail}',
      ),
      isThreeLine: true,
      leading: const Icon(Icons.flag_outlined),
      trailing: PopupMenuButton<String>(
        tooltip: 'Resolver reporte',
        onSelected: (resolution) => _resolve(context, ref, resolution),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'ocultar',
            child: Text('Ocultar publicaci\u00F3n'),
          ),
          PopupMenuItem(value: 'aprobar', child: Text('Aprobar reporte')),
        ],
      ),
    ),
  );

  Future<void> _showPublication(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => FutureBuilder<CommunityPostData>(
        future: ref
            .read(adminRepositoryProvider)
            .publication(report.publicationId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return AlertDialog(
              title: const Text('Detalle de publicaci\u00F3n'),
              content: snapshot.hasError
                  ? const Text('No se pudo cargar la publicaci\u00F3n.')
                  : const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            );
          }
          final post = snapshot.data!;
          return AlertDialog(
            title: Text(post.author),
            content: SingleChildScrollView(
              child: ListBody(
                children: [
                  Text(post.content),
                  const SizedBox(height: 12),
                  Text('Creada: ${_date(post.createdAt)}'),
                  Text('Estado: ${post.status}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    String resolution,
  ) async {
    final reason = await _reasonDialog(context, 'Resolver reporte');
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveModeration(report.id, resolution, reason);
      onChanged();
      if (context.mounted) _showMessage(context, 'Reporte resuelto.');
    } on ApiException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    }
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.hasNext,
    required this.hasPrevious,
    required this.onPrevious,
    required this.onNext,
  });
  final bool hasNext;
  final bool hasPrevious;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'P\u00E1gina anterior',
          onPressed: hasPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'P\u00E1gina siguiente',
          onPressed: hasNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
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
      label: Text(
        error is ApiException ? (error as ApiException).message : 'Reintentar',
      ),
    ),
  );
}

Future<String?> _reasonDialog(BuildContext context, String title) async =>
    showDialog<String>(context: context, builder: (_) => const _ReasonDialog());

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();
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
    title: const Text('Raz\u00F3n obligatoria'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Raz\u00F3n'),
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

void _showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
