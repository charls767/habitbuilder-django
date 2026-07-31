class AdminUsage {
  const AdminUsage({
    required this.registeredUsers,
    required this.activeUsers,
    required this.habits,
    required this.records,
    required this.publications,
    required this.from,
    required this.to,
  });

  factory AdminUsage.fromJson(Map<String, dynamic> json) => AdminUsage(
    registeredUsers: (json['usuariosRegistrados'] as num?)?.toInt() ?? 0,
    activeUsers: (json['usuariosActivos'] as num?)?.toInt() ?? 0,
    habits: (json['habitosCreados'] as num?)?.toInt() ?? 0,
    records: (json['registrosCreados'] as num?)?.toInt() ?? 0,
    publications: (json['publicaciones'] as num?)?.toInt() ?? 0,
    from:
        DateTime.tryParse(json['periodoDesde'] as String? ?? '') ??
        DateTime.now(),
    to:
        DateTime.tryParse(json['periodoHasta'] as String? ?? '') ??
        DateTime.now(),
  );

  final int registeredUsers;
  final int activeUsers;
  final int habits;
  final int records;
  final int publications;
  final DateTime from;
  final DateTime to;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });
  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] as String,
    name: json['nombre'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['rol'] as String? ?? 'regular',
    status: json['estado'] as String? ?? 'activo',
  );
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
}

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.publicationId,
    required this.reason,
    required this.detail,
    required this.status,
    required this.createdAt,
  });
  factory ModerationReport.fromJson(Map<String, dynamic> json) =>
      ModerationReport(
        id: json['id'] as String,
        publicationId: json['publicacionId'] as String? ?? '',
        reason: json['motivo'] as String? ?? '',
        detail: json['detalle'] as String? ?? '',
        status: json['estado'] as String? ?? 'pendiente',
        createdAt:
            DateTime.tryParse(json['creadoEn'] as String? ?? '') ??
            DateTime.now(),
      );
  final String id;
  final String publicationId;
  final String reason;
  final String detail;
  final String status;
  final DateTime createdAt;
}
