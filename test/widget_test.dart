import 'package:flutter_test/flutter_test.dart';
import 'package:yes_app_demo/main.dart';

void main() {
  testWidgets('登入頁顯示標題、環境切換與登入按鈕', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('我家環境通'), findsOneWidget);
    expect(find.text('本機'), findsOneWidget);
    expect(find.text('測試機'), findsOneWidget);
    expect(find.text('登入'), findsOneWidget);
  });

  test('AppEnv：cookie domain 取自 WebView 網址', () {
    expect(AppEnv.dev.cookieDomain, 'localhost');
    expect(AppEnv.test.cookieDomain, 'testyesme.pst.com.tw');
    expect(AppEnv.test.webUrl, 'https://testyesme.pst.com.tw/?m=1');
  });
}
