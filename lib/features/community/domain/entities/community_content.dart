enum InspirationType {
  all('todos', 'Todos'),
  article('articulo', 'Artículos'),
  video('video', 'Videos'),
  audio('audio', 'Audio');

  const InspirationType(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.reactions,
    required this.comments,
    required this.reacted,
    this.habitId,
  });

  final String id;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int reactions;
  final int comments;
  final bool reacted;
  final String? habitId;
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorName;
  final String content;
  final DateTime createdAt;
}

class InspirationItem {
  const InspirationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.url,
    required this.author,
    required this.featured,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
  });

  final String id;
  final InspirationType type;
  final String title;
  final String summary;
  final String url;
  final String author;
  final bool featured;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
}
