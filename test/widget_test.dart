import 'package:flutter_test/flutter_test.dart';

import 'package:kulkuri_mobile/main.dart';

void main() {
  testWidgets('App builds and shows the map screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KulkuriApp());
    expect(find.byType(MapScreen), findsOneWidget);
  });
}
