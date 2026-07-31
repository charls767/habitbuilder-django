import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_chrome.dart';
import '../domain/admin_entities.dart';
import 'admin_providers.dart';

class AdminAccessRequestScreen extends ConsumerStatefulWidget {
  const AdminAccessRequestScreen({super.key});

  @override
  ConsumerState<AdminAccessRequestScreen> createState() =>
      _AdminAccessRequestScreenState();
}

class _AdminAccessRequestScreenState
    extends ConsumerState<AdminAccessRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late Future<AdminAccessRequest?> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<AdminAccessRequest?> _load() async {
    try {
      return await ref.read(adminRepositoryProvider).myAdminRequest();
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final request = await ref
          .read(adminRepositoryProvider)
          .createAdminRequest(_reason.text.trim());
      if (!mounted) return;
      setState(() {
        _future = Future.value(request);
        _submitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud enviada.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  String _message(Object error) =>
      error is ApiException ? error.message : 'No se pudo enviar la solicitud.';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acceso administrativo')),
    body: AppContent(
      maxWidth: 680,
      child: FutureBuilder<AdminAccessRequest?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => setState(() => _future = _load()),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            );
          }
          final request = snapshot.data;
          if (request != null) return _RequestStatus(request: request);
          return _RequestForm(
            formKey: _formKey,
            controller: _reason,
            submitting: _submitting,
            onSubmit: _submit,
          );
        },
      ),
    ),
  );
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.formKey,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.admin_panel_settings_outlined, size: 52),
        const SizedBox(height: 18),
        Text(
          'Solicita acceso administrativo',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Cuéntanos por qué deseas apoyar la gestión del proyecto.'),
        const SizedBox(height: 24),
        TextFormField(
          controller: controller,
          minLines: 5,
          maxLines: 8,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Motivo de la solicitud',
            alignLabelWithHint: true,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Escribe un motivo'
              : null,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: submitting ? null : onSubmit,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Enviar solicitud'),
        ),
      ],
    ),
  );
}

class _RequestStatus extends StatelessWidget {
  const _RequestStatus({required this.request});
  final AdminAccessRequest request;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (request.status) {
      'aprobada' => ('Aprobada', Icons.check_circle, Colors.green),
      'rechazada' => ('Rechazada', Icons.cancel, Colors.red),
      _ => ('Pendiente de revisión', Icons.schedule, Colors.orange),
    };
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(icon, color: color, size: 52),
        const SizedBox(height: 16),
        Text(label, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        const Text('Motivo enviado'),
        const SizedBox(height: 6),
        Text(request.reason),
        if (request.decisionReason case final reason?) ...[
          const SizedBox(height: 18),
          const Text('Respuesta del administrador'),
          const SizedBox(height: 6),
          Text(reason),
        ],
      ],
    );
  }
}
