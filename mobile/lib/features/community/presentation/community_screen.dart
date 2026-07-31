import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../domain/entities/community_content.dart';
import 'community_providers.dart';
import 'inspiration_media.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  InspirationType _inspirationType = InspirationType.all;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comunidad'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.forum_outlined), text: 'Foro'),
              Tab(icon: Icon(Icons.lightbulb_outline), text: 'Inspírate'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _CommunityFeed(),
            _InspirationFeed(
              selected: _inspirationType,
              onTypeChanged: (value) =>
                  setState(() => _inspirationType = value),
            ),
          ],
        ),
        bottomNavigationBar: const AppDestinationBar(selectedIndex: 5),
      ),
    );
  }
}

class _CommunityFeed extends ConsumerWidget {
  const _CommunityFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(communityFeedProvider);
    return AppContent(
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(communityFeedProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            _ComposerCard(onTap: () => _showComposer(context, ref)),
            const SizedBox(height: 16),
            ...feed.when(
              data: (posts) => [
                if (posts.isEmpty)
                  const _EmptyCommunity()
                else
                  ...posts.map(
                    (post) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PostCard(post: post),
                    ),
                  ),
              ],
              loading: () => [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, _) => [
                _RetryView(
                  onRetry: () => ref.invalidate(communityFeedProvider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: Icon(Icons.person_outline)),
            SizedBox(width: 12),
            Expanded(child: Text('Comparte tu progreso de hoy...')),
            Icon(Icons.edit_outlined),
          ],
        ),
      ),
    ),
  );
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person_outline),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _dateLabel(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones de publicación',
                  onSelected: (value) {
                    if (value == 'report') _showReport(context, ref, post.id);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: Text('Reportar publicación'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(post.content),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: post.reacted ? 'Quitar reacción' : 'Reaccionar',
                  onPressed: () async {
                    await ref
                        .read(communityRepositoryProvider)
                        .react(post.id, reacted: post.reacted);
                    ref.invalidate(communityFeedProvider);
                  },
                  icon: Icon(
                    post.reacted ? Icons.favorite : Icons.favorite_border,
                    color: post.reacted ? AppColors.primary : null,
                  ),
                ),
                Text('${post.reactions}'),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Ver comentarios',
                  onPressed: () => _showComments(context, ref, post),
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                Text('${post.comments}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InspirationFeed extends ConsumerWidget {
  const _InspirationFeed({required this.selected, required this.onTypeChanged});
  final InspirationType selected;
  final ValueChanged<InspirationType> onTypeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inspirationProvider(selected));
    return AppContent(
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Wrap(
              spacing: 8,
              children: InspirationType.values
                  .map(
                    (type) => ChoiceChip(
                      label: Text(type.label),
                      selected: selected == type,
                      onSelected: (_) => onTypeChanged(type),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: items.when(
              data: (content) => content.isEmpty
                  ? const _EmptyInspiration()
                  : _PaginatedInspirationList(
                      type: selected,
                      initialItems: content,
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _RetryView(
                onRetry: () => ref.invalidate(inspirationProvider(selected)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginatedInspirationList extends ConsumerStatefulWidget {
  const _PaginatedInspirationList({
    required this.type,
    required this.initialItems,
  });

  final InspirationType type;
  final List<InspirationItem> initialItems;

  @override
  ConsumerState<_PaginatedInspirationList> createState() =>
      _PaginatedInspirationListState();
}

class _PaginatedInspirationListState
    extends ConsumerState<_PaginatedInspirationList> {
  static const _pageSize = 50;

  late List<InspirationItem> _items;
  var _loadingMore = false;
  var _hasMore = false;

  @override
  void initState() {
    super.initState();
    _items = [...widget.initialItems];
    _hasMore = _items.length == _pageSize;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(communityRepositoryProvider)
          .listInspiration(widget.type, offset: _items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(next);
        _hasMore = next.length == _pageSize;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasHero = widget.type == InspirationType.all && _items.isNotEmpty;
    final footerCount = _loadingMore ? 1 : 0;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        itemCount: _items.length + footerCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (hasHero && index == 0) {
            return _InspirationHero(item: _items.first);
          }
          if (_loadingMore && index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _InspirationCard(item: _items[index]);
        },
      ),
    );
  }
}

class _InspirationHero extends StatelessWidget {
  const _InspirationHero({required this.item});

  final InspirationItem item;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InspirationCover(item: item, height: 190),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Destacado',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(item.summary),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: _ViewContentButton(item: item),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InspirationCard extends StatelessWidget {
  const _InspirationCard({required this.item});
  final InspirationItem item;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push(AppRoutes.inspirationDetail(item.id)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InspirationCover(item: item, height: 120),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(inspirationIcon(item.type), color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  item.type.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(item.summary),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.author,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                _ViewContentButton(item: item),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ViewContentButton extends StatelessWidget {
  const _ViewContentButton({required this.item});

  final InspirationItem item;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: () => context.push(AppRoutes.inspirationDetail(item.id)),
    icon: const Icon(Icons.arrow_forward, size: 18),
    label: const Text('Ver contenido'),
  );
}

class _EmptyInspiration extends StatelessWidget {
  const _EmptyInspiration();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text('Todavía no hay contenido de inspiración.'),
    ),
  );
}

class _EmptyCommunity extends StatelessWidget {
  const _EmptyCommunity();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'Todavía no hay publicaciones. Sé la primera persona en compartir.',
      ),
    ),
  );
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.onRetry});
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

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

Future<void> _showComposer(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final content = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Comparte tu progreso'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 5,
        maxLength: 1000,
        decoration: const InputDecoration(
          hintText: '¿Qué te gustaría compartir?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Publicar'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (content == null || content.trim().isEmpty) return;
  await ref.read(communityRepositoryProvider).createPost(content.trim());
  ref.invalidate(communityFeedProvider);
}

Future<void> _showComments(
  BuildContext context,
  WidgetRef ref,
  CommunityPost post,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CommentsSheet(post: post),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.post});
  final CommunityPost post;
  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(communityCommentsProvider(widget.post.id));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: 480,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Comentarios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: comments.when(
                  data: (items) => ListView(
                    children: items
                        .map(
                          (item) => ListTile(
                            title: Text(item.authorName),
                            subtitle: Text(item.content),
                          ),
                        )
                        .toList(),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(
                    child: Text('No se pudieron cargar los comentarios.'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un comentario',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Enviar comentario',
                      onPressed: () async {
                        final text = _controller.text.trim();
                        if (text.isEmpty) return;
                        await ref
                            .read(communityRepositoryProvider)
                            .createComment(widget.post.id, text);
                        _controller.clear();
                        ref.invalidate(
                          communityCommentsProvider(widget.post.id),
                        );
                      },
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showReport(
  BuildContext context,
  WidgetRef ref,
  String postId,
) async {
  const reasons = {
    'spam': 'Spam',
    'acoso': 'Acoso',
    'inapropiado': 'Contenido inapropiado',
    'otro': 'Otro',
  };
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('Reportar publicación'),
      children: reasons.entries
          .map(
            (entry) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Text(entry.value),
            ),
          )
          .toList(),
    ),
  );
  if (reason == null) return;
  await ref.read(communityRepositoryProvider).report(postId, reason, '');
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reporte enviado.')));
  }
}
