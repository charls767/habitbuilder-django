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

class AdminInspiration {
  const AdminInspiration({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.url,
    required this.author,
    required this.featured,
    required this.published,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
  });

  factory AdminInspiration.fromJson(Map<String, dynamic> json) =>
      AdminInspiration(
        id: json['id'] as String,
        type: json['tipo'] as String? ?? 'articulo',
        title: json['titulo'] as String? ?? '',
        summary: json['resumen'] as String? ?? '',
        url: json['url'] as String? ?? '',
        author: json['autor'] as String? ?? '',
        featured: json['destacado'] as bool? ?? false,
        published: json['publicado'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['creadoEn'] as String? ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['actualizadoEn'] as String? ?? '') ??
            DateTime.now(),
        imageUrl: json['imagenUrl'] as String?,
      );

  final String id;
  final String type;
  final String title;
  final String summary;
  final String url;
  final String author;
  final bool featured;
  final bool published;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
}

class AdminAccessRequest {
  const AdminAccessRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.decisionReason,
    this.reviewedAt,
  });

  factory AdminAccessRequest.fromJson(Map<String, dynamic> json) =>
      AdminAccessRequest(
        id: json['id'] as String? ?? '',
        userId: json['usuarioId'] as String? ?? '',
        userName: json['usuarioNombre'] as String? ?? '',
        userEmail: json['usuarioEmail'] as String? ?? '',
        reason: json['motivo'] as String? ?? '',
        status: json['estado'] as String? ?? 'pendiente',
        decisionReason: json['razonDecision'] as String?,
        createdAt:
            DateTime.tryParse(json['creadoEn'] as String? ?? '') ??
            DateTime.now(),
        reviewedAt: DateTime.tryParse(json['revisadoEn'] as String? ?? ''),
      );

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? decisionReason;
  final DateTime? reviewedAt;
}
