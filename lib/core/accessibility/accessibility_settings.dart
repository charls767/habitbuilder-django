import 'package:flutter/widgets.dart';

TextScaler effectiveTextScaler({
  required TextScaler systemScaler,
  required double preferenceFactor,
}) {
  final systemFactor = systemScaler.scale(16) / 16;
  final combined = (systemFactor * preferenceFactor).clamp(0.8, 2.0);
  return TextScaler.linear(combined);
}
