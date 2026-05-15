// 应用基础冒烟测试
//
// 验证应用能够正常启动

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:family_work_ledger/main.dart';
import 'package:family_work_ledger/services/auth_provider.dart';

void main() {
  testWidgets('App smoke test - app starts without crash', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const FamilyLedgerApp(),
      ),
    );

    // 等待构建完成
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 验证应用启动 - 应该显示登录页面（因为未登录）
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
