import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/auth_validators.dart';
import '../auth_error_message.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_mockup_shell.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _acceptsTerms = false;
  bool _acceptsPrivacy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final success = await ref
        .read(authControllerProvider.notifier)
        .register(
          nombre: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          aceptaTerminos: _acceptsTerms,
          aceptaPrivacidad: _acceptsPrivacy,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada. Ya puedes iniciar sesión.'),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentError = authState.error;
    final apiError = currentError is ApiException ? currentError : null;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(authErrorMessage(next.error!))),
          );
      }
    });

    return AuthMockupShell(
      heroTitle: 'Crea tu cuenta',
      heroSubtitle: 'Empieza a construir mejores hábitos hoy',
      contentMaxWidth: 520,
      onBack: () => context.pop(),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: apiError?.errorFor('nombre'),
                ),
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearError(),
                validator: AuthValidators.name,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.mail_outline),
                  errorText: apiError?.errorFor('email'),
                ),
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearError(),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: apiError?.errorFor('password'),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onChanged: (_) =>
                    ref.read(authControllerProvider.notifier).clearError(),
                validator: AuthValidators.password,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmationController,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirmation
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                    icon: Icon(
                      _obscureConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => AuthValidators.passwordConfirmation(
                  value,
                  _passwordController.text,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _acceptsTerms,
                onChanged: authState.isLoading
                    ? null
                    : (value) {
                        setState(() => _acceptsTerms = value ?? false);
                        ref.read(authControllerProvider.notifier).clearError();
                      },
                title: const Text('Acepto los términos de uso'),
                subtitle: apiError?.errorFor('aceptaTerminos') != null
                    ? Text(
                        apiError!.errorFor('aceptaTerminos')!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _acceptsPrivacy,
                onChanged: authState.isLoading
                    ? null
                    : (value) {
                        setState(() => _acceptsPrivacy = value ?? false);
                        ref.read(authControllerProvider.notifier).clearError();
                      },
                title: const Text('Acepto la política de privacidad'),
                subtitle: apiError?.errorFor('aceptaPrivacidad') != null
                    ? Text(
                        apiError!.errorFor('aceptaPrivacidad')!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
              ),
              if (!_acceptsTerms || !_acceptsPrivacy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Debes aceptar ambos documentos para registrarte.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              FilledButton.icon(
                onPressed:
                    authState.isLoading || !_acceptsTerms || !_acceptsPrivacy
                    ? null
                    : _submit,
                icon: authState.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
                label: const Text('Crear cuenta'),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('¿Ya tienes cuenta?'),
                  TextButton(
                    onPressed: authState.isLoading ? null : () => context.pop(),
                    child: const Text('Inicia sesión'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
