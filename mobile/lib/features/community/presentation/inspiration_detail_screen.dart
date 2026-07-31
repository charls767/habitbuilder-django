import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../domain/entities/community_content.dart';
import 'community_providers.dart';
import 'inspiration_media.dart';

class InspirationDetailScreen extends ConsumerWidget {
  const InspirationDetailScreen({required this.inspirationId, super.key});

  final String inspirationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(inspirationDetailProvider(inspirationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Inspírate')),
      body: AppContent(
        child: content.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(inspirationDetailProvider(inspirationId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
          data: (item) => _InspirationDetail(item: item),
        ),
      ),
    );
  }
}

class _InspirationDetail extends StatelessWidget {
  const _InspirationDetail({required this.item});

  final InspirationItem item;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        InspirationCover(item: item, height: 220),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: Icon(inspirationIcon(item.type), size: 18),
            label: Text(item.type.label),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.person_outline, size: 20, color: AppColors.muted),
            const SizedBox(width: 8),
            Text(item.author, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 20),
        Text(item.summary, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
