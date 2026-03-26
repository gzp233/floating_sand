import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:floating_sand/app.dart';
import 'package:floating_sand/services/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppDatabase.instance.usePreferencesStoreForTesting();
  });

  testWidgets('app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PersonalRecordApp());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('想法记录'), findsWidgets);
  });
}
