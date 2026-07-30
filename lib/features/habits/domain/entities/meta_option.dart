/// Minimal goal projection used by the habit goal selector.
///
/// Goal CRUD and the complete goal model belong to HBM-12.
class MetaOption {
  const MetaOption({required this.id, required this.nombre});

  final String id;
  final String nombre;
}
