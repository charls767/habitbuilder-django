import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_chrome.dart';
import '../domain/admin_entities.dart';
import 'admin_providers.dart';

class AdminRequestsScreen extends ConsumerStatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  ConsumerState<AdminRequestsScreen> createState() =>
      _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends ConsumerState<AdminRequestsScreen> {
  String _status = 'pendiente';

  Future<void> _resolve(AdminAccessRequest request, String decision) async {
    final reason = await _askReason(context, decision);
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveAdminRequest(request.id, decision, reason);
      ref.invalidate(adminRequestsProvider(_status));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'aprobar'
                  ? 'Solicitud aprobada.'
                  : 'Solicitud rechazada.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<String?> _askReason(BuildContext context, String decision) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          decision == 'aprobar' ? 'Aprobar solicitud' : 'Rechazar solicitud',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Razón de la decisión'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result;
  }

  String _errorMessage(Object error) => error is ApiException
      ? error.message
      : 'No se pudo resolver la solicitud.';

  @override
  Widget build(BuildContext context) => AppContent(
    maxWidth: 1100,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Solicitudes de acceso',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(
                    value: 'pendiente',
                    child: Text('Pendientes'),
                  ),
                  DropdownMenuItem(value: 'aprobada', child: Text('Aprobadas')),
                  DropdownMenuItem(
                    value: 'rechazada',
                    child: Text('Rechazadas'),
                  ),
                ],
                onChanged: (value) => setState(() => _status = value!),
              ),
            ],
          ),
        ),
        Expanded(
          child: ref
              .watch(adminRequestsProvider(_status))
              .when(
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Text('No hay solicitudes en este estado.'),
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(adminRequestsProvider(_status)),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _RequestTile(
                            request: items[index],
                            onApprove: items[index].status == 'pendiente'
                                ? () => _resolve(items[index], 'aprobar')
                                : null,
                            onReject: items[index].status == 'pendiente'
                                ? () => _resolve(items[index], 'rechazar')
                                : null,
                          ),
                        ),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(adminRequestsProvider(_status)),
                    icon: const Icon(Icons.refresh),
                    label: Text(_errorMessage(error)),
                  ),
                ),
              ),
        ),
      ],
    ),
  );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, this.onApprove, this.onReject});

  final AdminAccessRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.userName.isEmpty
                      ? request.userEmail
                      : request.userName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(request.status)),
            ],
          ),
          Text(request.userEmail),
          const SizedBox(height: 12),
          Text(request.reason),
          if (request.decisionReason case final reason?) ...[
            const SizedBox(height: 10),
            Text('Respuesta: $reason'),
          ],
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                ),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('Aprobar'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
