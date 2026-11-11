import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// flutter drive 的驅動程式：把 takeScreenshot 的圖片存到 build/integration_screenshots/
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('build/integration_screenshots/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
