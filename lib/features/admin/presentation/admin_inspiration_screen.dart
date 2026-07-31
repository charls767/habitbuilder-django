import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_chrome.dart';
import '../domain/admin_entities.dart';
import 'admin_providers.dart';

class AdminInspirationScreen extends ConsumerStatefulWidget {
  const AdminInspirationScreen({super.key});

  @override
  ConsumerState<AdminInspirationScreen> createState() =>
      _AdminInspirationScreenState();
}

class _AdminInspirationScreenState
    extends ConsumerState<AdminInspirationScreen> {
  final _search = TextEditingController();
  String? _type;
  int _offset = 0;
  late Future<List<AdminInspiration>> _future;

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

  Future<List<AdminInspiration>> _load() => ref
      .read(adminRepositoryProvider)
      .inspiration(type: _type, search: _search.text, offset: _offset);

  void _refresh({bool reset = false}) => setState(() {
    if (reset) _offset = 0;
    _future = _load();
  });

  @override
  Widget build(BuildContext context) => AppContent(
    maxWidth: 1100,
    child: FutureBuilder<List<AdminInspiration>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          );
        }
        final items = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cat\u00E1logo de Inspiraci\u00F3n',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo contenido'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _refresh(reset: true),
                      decoration: const InputDecoration(
                        labelText: 'Buscar t\u00EDtulo o autor',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  DropdownButton<String?>(
                    value: _type,
                    hint: const Text('Tipo'),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Todos los tipos'),
                      ),
                      DropdownMenuItem(
                        value: 'articulo',
                        child: Text('Art\u00EDculo'),
                      ),
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                      DropdownMenuItem(value: 'audio', child: Text('Audio')),
                    ],
                    onChanged: (value) {
                      _type = value;
                      _refresh(reset: true);
                    },
                  ),
                  FilledButton.icon(
                    onPressed: () => _refresh(reset: true),
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Aplicar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No hay contenidos para estos filtros.'),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth >= 800
                      ? _ContentTable(items: items, onChanged: _refresh)
                      : Column(
                          children: items
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ContentCard(
                                    item: item,
                                    onChanged: _refresh,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              _Pager(
                hasPrevious: _offset > 0,
                hasNext: items.length == 50,
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

  Future<void> _openForm(BuildContext context, [AdminInspiration? item]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ContentForm(item: item),
    );
    if (data == null || !mounted) return;
    try {
      if (item == null) {
        await ref.read(adminRepositoryProvider).createInspiration(data);
      } else {
        await ref
            .read(adminRepositoryProvider)
            .updateInspiration(item.id, data);
      }
      _refresh(reset: item == null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contenido guardado.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
    }
  }
}

class _ContentTable extends StatelessWidget {
  const _ContentTable({required this.items, required this.onChanged});
  final List<AdminInspiration> items;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('T\u00EDtulo')),
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Autor')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(SizedBox(width: 280, child: Text(item.title))),
                  DataCell(Text(item.type)),
                  DataCell(Text(item.author)),
                  DataCell(Text(item.published ? 'Publicado' : 'Borrador')),
                  DataCell(_ContentActions(item: item, onChanged: onChanged)),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item, required this.onChanged});
  final AdminInspiration item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(item.title),
      subtitle: Text(
        '${item.type} \u00B7 ${item.author}\n${item.published ? 'Publicado' : 'Borrador'}${item.featured ? ' \u00B7 Destacado' : ''}',
      ),
      isThreeLine: true,
      trailing: _ContentActions(item: item, onChanged: onChanged),
    ),
  );
}

class _ContentActions extends StatelessWidget {
  const _ContentActions({required this.item, required this.onChanged});
  final AdminInspiration item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    children: [
      IconButton(
        tooltip: 'Editar contenido',
        onPressed: () => _edit(context),
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        tooltip: 'Eliminar contenido',
        onPressed: () => _delete(context),
        icon: const Icon(Icons.delete_outline),
      ),
    ],
  );

  Future<void> _edit(BuildContext context) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ContentForm(item: item),
    );
    if (data == null || !context.mounted) return;
    try {
      final scope = ProviderScope.containerOf(context, listen: false);
      await scope
          .read(adminRepositoryProvider)
          .updateInspiration(item.id, data);
      onChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar contenido'),
        content: Text('Se eliminar\u00E1 "${item.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final scope = ProviderScope.containerOf(context, listen: false);
      await scope.read(adminRepositoryProvider).deleteInspiration(item.id);
      onChanged();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
      }
    }
  }
}

class _ContentForm extends StatefulWidget {
  const _ContentForm({this.item});
  final AdminInspiration? item;
  @override
  State<_ContentForm> createState() => _ContentFormState();
}

class _ContentFormState extends State<_ContentForm> {
  late final TextEditingController _title = TextEditingController(
    text: widget.item?.title,
  );
  late final TextEditingController _summary = TextEditingController(
    text: widget.item?.summary,
  );
  late final TextEditingController _url = TextEditingController(
    text: widget.item?.url,
  );
  late final TextEditingController _image = TextEditingController(
    text: widget.item?.imageUrl,
  );
  late final TextEditingController _author = TextEditingController(
    text: widget.item?.author,
  );
  late String _type = widget.item?.type ?? 'articulo';
  late bool _published = widget.item?.published ?? true;
  late bool _featured = widget.item?.featured ?? false;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _url.dispose();
    _image.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Nuevo contenido' : 'Editar contenido'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                    value: 'articulo',
                    child: Text('Art\u00EDculo'),
                  ),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'audio', child: Text('Audio')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'T\u00EDtulo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Resumen'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _author,
                decoration: const InputDecoration(labelText: 'Autor'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'URL interna'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'URL de portada opcional',
                ),
              ),
              SwitchListTile(
                value: _published,
                onChanged: (value) => setState(() => _published = value),
                title: const Text('Publicado'),
              ),
              SwitchListTile(
                value: _featured,
                onChanged: (value) => setState(() => _featured = value),
                title: const Text('Destacado'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  void _save() {
    if (_title.text.trim().isEmpty ||
        _summary.text.trim().isEmpty ||
        _author.text.trim().isEmpty ||
        _url.text.trim().isEmpty) {
      return;
    }
    Navigator.pop(context, {
      'tipo': _type,
      'titulo': _title.text.trim(),
      'resumen': _summary.text.trim(),
      'autor': _author.text.trim(),
      'url': _url.text.trim(),
      'imagenUrl': _image.text.trim(),
      'publicado': _published,
      'destacado': _featured,
    });
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Row(
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
  );
}
