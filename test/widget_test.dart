import 'package:flutter_test/flutter_test.dart';

import 'package:file_hub/main.dart';

void main() {
  testWidgets('App smoke test - renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FileHubApp());

    // 验证首页渲染了 AppBar 标题
    expect(find.text('File Hub'), findsOneWidget);
  });

  testWidgets('Bottom navigation bar exists', (WidgetTester tester) async {
    await tester.pumpWidget(const FileHubApp());

    // 验证底部导航栏存在（Wi-Fi传输、文件、分类、快速访问）
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('快速访问'), findsOneWidget);
  });
}
