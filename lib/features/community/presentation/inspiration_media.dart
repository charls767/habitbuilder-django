import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/entities/community_content.dart';

class InspirationCover extends StatelessWidget {
  const InspirationCover({required this.item, this.height = 168, super.key});

  final InspirationItem item;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return _fallback(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _fallback(context, progress: progress);
          },
          errorBuilder: (context, error, stackTrace) => _fallback(context),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context, {ImageChunkEvent? progress}) {
    final value = progress?.expectedTotalBytes == null
        ? null
        : progress!.cumulativeBytesLoaded / progress.expectedTotalBytes!;
    return Container(
      height: height,
      width: double.infinity,
      color: _backgroundFor(item.type),
      alignment: Alignment.center,
      child: progress == null
          ? Icon(
              inspirationIcon(item.type),
              size: 48,
              color: AppColors.primaryDark,
            )
          : CircularProgressIndicator(value: value),
    );
  }
}

IconData inspirationIcon(InspirationType type) => switch (type) {
  InspirationType.video => Icons.play_circle_outline,
  InspirationType.audio => Icons.headphones_outlined,
  _ => Icons.article_outlined,
};

Color _backgroundFor(InspirationType type) => switch (type) {
  InspirationType.video => const Color(0xFFE7F0FF),
  InspirationType.audio => const Color(0xFFFFF0E5),
  _ => AppColors.mint,
};
