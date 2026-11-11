import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yes_app_demo/main.dart';

/// 登入頁的 UI 流程測試（不需要真實帳號，也不連外部伺服器）。
///
/// 登入頁有常駐動畫（機器人），所以一律用 `pump(Duration)`，不用 `pumpAndSettle`。
/// 每個關鍵畫面都用 takeScreenshot 存圖，由 test_driver/integration_test.dart 寫到
/// build/integration_screenshots/。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 點擊若沒打到目標（被其他元件擋住）就直接失敗，不要只印警告
  WidgetController.hitTestWarningShouldBeFatal = true;

  Future<void> settle(WidgetTester tester, [int ms = 600]) =>
      tester.pump(Duration(milliseconds: ms));

  testWidgets('登入頁完整 UI 流程', (tester) async {
    await tester.pumpWidget(const MyApp());
    await settle(tester);

    // 1. 初始畫面
    expect(find.text('我家環境通'), findsOneWidget);
    expect(find.text('登入'), findsOneWidget);
    await binding.takeScreenshot('01_login_initial');

    // 2. 切換環境：本機 → 測試機
    SegmentedButton<AppEnv> envButton() =>
        tester.widget(find.byType(SegmentedButton<AppEnv>));
    expect(envButton().selected.first, AppEnv.dev);
    await tester.tap(find.text('測試機'));
    await settle(tester);
    expect(envButton().selected.first, AppEnv.test);
    await binding.takeScreenshot('02_env_test');

    // 切回本機：後面的登入嘗試只打 localhost，不會送到任何真實伺服器
    await tester.tap(find.text('本機'));
    await settle(tester);
    expect(envButton().selected.first, AppEnv.dev);

    // 3. 帳號空白按登入 → 提示
    await tester.tap(find.text('登入'));
    await settle(tester);
    expect(find.text('請輸入電子郵件或帳號'), findsOneWidget);
    await binding.takeScreenshot('03_empty_account_toast');

    // 主動移除提示條。iOS 鍵盤彈出時提示條會被擠到密碼欄的眼睛圖示上，擋住點擊。
    // removeCurrentSnackBar 是立即移除（clearSnackBars 只是播退場動畫）；
    // 再輪詢到它真的消失，避免依賴固定等待時間。
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .removeCurrentSnackBar();
    for (var i = 0;
        i < 20 && find.text('請輸入電子郵件或帳號').evaluate().isNotEmpty;
        i++) {
      await settle(tester, 300);
    }
    expect(find.text('請輸入電子郵件或帳號'), findsNothing);

    // 4. 輸入假帳密 + 切換密碼可見
    await tester.enterText(find.byType(TextField).at(0), 'demo@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'not-a-real-password');
    await settle(tester);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility));
    await settle(tester);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    await binding.takeScreenshot('04_filled_password_visible');

    // 5. 按登入：localhost 沒有後端，應該顯示登入失敗並結束載入狀態
    await tester.tap(find.text('登入'));
    var failed = false;
    for (var i = 0; i < 20 && !failed; i++) {
      await settle(tester, 500);
      failed = find.textContaining('登入失敗').evaluate().isNotEmpty;
    }
    expect(failed, isTrue, reason: '連不到後端時應顯示「登入失敗」');
    await binding.takeScreenshot('05_login_failed_toast');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
