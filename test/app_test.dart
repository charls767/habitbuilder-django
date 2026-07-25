import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/app.dart';

void main() {
  testWidgets('app boots and shows the scaffold placeholder', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: HabitBuilderApp()),
    );

    expect(find.textContaining('HabitBuilder'), findsWidgets);
  });
}
