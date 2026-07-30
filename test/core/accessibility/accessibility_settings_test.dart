import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/accessibility/accessibility_settings.dart';

void main() {
  test('preserves the operating system text scale by default', () {
    final scaler = effectiveTextScaler(
      systemScaler: const TextScaler.linear(1.5),
      preferenceFactor: 1,
    );

    expect(scaler.scale(16), 24);
  });

  test('combines the system scale with the profile preference', () {
    final scaler = effectiveTextScaler(
      systemScaler: const TextScaler.linear(1.4),
      preferenceFactor: 1.15,
    );

    expect(scaler.scale(16), closeTo(25.76, 0.001));
  });

  test('clamps extreme scales to a usable supported range', () {
    final minimum = effectiveTextScaler(
      systemScaler: const TextScaler.linear(0.5),
      preferenceFactor: 0.9,
    );
    final maximum = effectiveTextScaler(
      systemScaler: const TextScaler.linear(3),
      preferenceFactor: 1.15,
    );

    expect(minimum.scale(10), 8);
    expect(maximum.scale(10), 20);
  });
}
