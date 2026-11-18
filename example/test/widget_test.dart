import 'package:fafa_torch_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders the torch page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Torch Example'), findsOneWidget);
    expect(find.text('Torch'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });
}
