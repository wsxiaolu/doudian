// 抖店订单管理系统 —— 基础冒烟测试
//
// 默认模板的计数器测试已废弃（本应用无计数器）。这里仅做一个可编译、可运行的
// 冒烟测试，验证 Flutter 测试框架与基础控件可用；接入真实页面后请替换为业务测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('应用可构建冒烟测试', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('ok')),
        ),
      ),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
