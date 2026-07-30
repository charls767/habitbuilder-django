import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../domain/entities/perfil_usuario.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _timezones = [
    'America/Bogota',
    'America/Lima',
    'America/Mexico_City',
    'America/New_York',
    'America/Santiago',
    'America/Sao_Paulo',
    'Europe/Madrid',
    'UTC',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _goalController = TextEditingController();
  String? _hydratedUserId;
  String _timezone = 'America/Bogota';
  bool _textToSpeech = false;
  TextSizePreference _textSize = TextSizePreference.medium;
  bool _highContrast = false;
  bool _notificationsEnabled = true;
  bool _habitReminders = true;
  bool _weeklySummary = true;

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _hydrate(PerfilUsuario profile) {
    if (_hydratedUserId == profile.usuarioId) return;
    _hydratedUserId = profile.usuarioId;
    _nameController.text = profile.nombreCompleto;
    _goalController.text = profile.objetivoGeneral;
    _timezone = _timezones.contains(profile.zonaHoraria)
        ? profile.zonaHoraria
        : 'UTC';
    _textToSpeech = profile.accessibility.textToSpeech;
    _textSize = profile.accessibility.textSize;
    _highContrast = profile.accessibility.highContrast;
    _notificationsEnabled = profile.notifications.enabled;
    _habitReminders = profile.notifications.habitReminders;
    _weeklySummary = profile.notifications.weeklySummary;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(
          nombreCompleto: _nameController.text.trim(),
          objetivoGeneral: _goalController.text.trim(),
          zonaHoraria: _timezone,
          accessibility: AccessibilityPreferences(
            textToSpeech: _textToSpeech,
            textSize: _textSize,
            highContrast: _highContrast,
          ),
          notifications: NotificationPreferences(
            enabled: _notificationsEnabled,
            habitReminders: _habitReminders,
            weeklySummary: _weeklySummary,
          ),
        );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Tendrás que volver a ingresar tu correo y contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(profileControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final controllerState = ref.watch(profileControllerProvider);

    ref.listen(profileControllerProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading) {
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        if (next.hasError) {
          final error = next.error;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                error is ApiException
                    ? error.message
                    : 'No se pudieron guardar los cambios.',
              ),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Perfil actualizado.')),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: controllerState.isLoading ? null : _confirmLogout,
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          _hydrate(profile);
          return AppContent(
            maxWidth: 700,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 32),
                  _SectionTitle(
                    icon: Icons.person_outline,
                    title: 'Información general',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().length < 2)
                        ? 'Ingresa tu nombre completo'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _goalController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Objetivo general',
                      hintText: 'Ej. Dormir mejor y tener más energía',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Define el objetivo que guía tus hábitos'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _timezone,
                    decoration: const InputDecoration(
                      labelText: 'Zona horaria',
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: _timezones
                        .map(
                          (timezone) => DropdownMenuItem(
                            value: timezone,
                            child: Text(timezone),
                          ),
                        )
                        .toList(),
                    onChanged: controllerState.isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _timezone = value);
                            }
                          },
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle(
                    icon: Icons.accessibility_new,
                    title: 'Accesibilidad',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lectura de texto'),
                    subtitle: const Text(
                      'Permite que la app lea contenido compatible en voz alta.',
                    ),
                    value: _textToSpeech,
                    onChanged: controllerState.isLoading
                        ? null
                        : (value) => setState(() => _textToSpeech = value),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tamaño del texto',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<TextSizePreference>(
                    showSelectedIcon: false,
                    segments: TextSizePreference.values
                        .map(
                          (preference) => ButtonSegment(
                            value: preference,
                            label: Text(preference.label),
                          ),
                        )
                        .toList(),
                    selected: {_textSize},
                    onSelectionChanged: controllerState.isLoading
                        ? null
                        : (selection) =>
                              setState(() => _textSize = selection.first),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alto contraste'),
                    subtitle: const Text(
                      'Refuerza la diferencia entre texto, fondos y controles.',
                    ),
                    value: _highContrast,
                    onChanged: controllerState.isLoading
                        ? null
                        : (value) => setState(() => _highContrast = value),
                  ),
                  const SizedBox(height: 32),
                  const _SectionTitle(
                    icon: Icons.notifications_outlined,
                    title: 'Notificaciones',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Permitir notificaciones'),
                    value: _notificationsEnabled,
                    onChanged: controllerState.isLoading
                        ? null
                        : (value) => setState(() {
                            _notificationsEnabled = value;
                            if (!value) {
                              _habitReminders = false;
                              _weeklySummary = false;
                            }
                          }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recordatorios de hábitos'),
                    value: _habitReminders,
                    onChanged:
                        controllerState.isLoading || !_notificationsEnabled
                        ? null
                        : (value) => setState(() => _habitReminders = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Resumen semanal'),
                    value: _weeklySummary,
                    onChanged:
                        controllerState.isLoading || !_notificationsEnabled
                        ? null
                        : (value) => setState(() => _weeklySummary = value),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: controllerState.isLoading ? null : _save,
                    icon: controllerState.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _ProfileLoadError(onRetry: () => ref.invalidate(myProfileProvider)),
      ),
      bottomNavigationBar: const AppDestinationBar(selectedIndex: 3),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final PerfilUsuario profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppColors.accent,
            foregroundImage: profile.fotoUrl != null
                ? NetworkImage(profile.fotoUrl!)
                : null,
            child: profile.fotoUrl == null
                ? Text(
                    _initials(profile.nombreCompleto),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.nombreCompleto,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.zonaHoraria,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFBCEFE6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'HB';
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No se pudo cargar el perfil.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
