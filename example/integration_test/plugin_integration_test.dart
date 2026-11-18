import 'package:fafa_torch/fafa_torch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('torch state is readable', (WidgetTester tester) async {
    final torch = Torch();

    expect(await torch.isAvailable(), isA<bool>());
    expect(await torch.isOn(), isA<bool>());
    expect(await torch.supportsLevel(), isA<bool>());
    if (await torch.supportsLevel()) {
      expect(await torch.level(), inInclusiveRange(0.0, 1.0));
    }
  });
}
