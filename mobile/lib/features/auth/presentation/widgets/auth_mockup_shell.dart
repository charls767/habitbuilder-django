import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class AuthMockupShell extends StatelessWidget {
  const AuthMockupShell({
    required this.heroTitle,
    required this.heroSubtitle,
    required this.child,
    super.key,
    this.onBack,
    this.contentMaxWidth = 440,
  });

  final String heroTitle;
  final String heroSubtitle;
  final Widget child;
  final VoidCallback? onBack;
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
          final extraTextHeight = ((textScale - 1).clamp(0, 1)) * 120;
          final heroHeight = (compact ? 340.0 : 290.0) + extraTextHeight;
          final panelMinHeight = constraints.hasBoundedHeight
              ? (constraints.maxHeight - heroHeight).clamp(0.0, double.infinity)
              : 0.0;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: heroHeight),
                    child: SafeArea(
                      bottom: false,
                      child: Stack(
                        children: [
                          if (onBack != null)
                            Positioned(
                              top: 4,
                              left: 8,
                              child: IconButton(
                                onPressed: onBack,
                                color: Colors.white,
                                icon: const Icon(Icons.arrow_back_rounded),
                                tooltip: 'Volver',
                              ),
                            ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                32,
                                24,
                                34,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 36,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Semantics(
                                    container: true,
                                    header: true,
                                    child: Text(
                                      heroTitle,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                    ),
                                    child: Text(
                                      heroSubtitle,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: panelMinHeight),
                    child: Material(
                      color: AppColors.canvas,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 24 : 40,
                            compact ? 30 : 40,
                            compact ? 24 : 40,
                            40,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: contentMaxWidth,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
