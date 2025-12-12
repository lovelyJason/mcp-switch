// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mcp_switch/services/config_service.dart';

import 'package:mcp_switch/main.dart';
import 'package:mcp_switch/ui/components/editor_selector.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Build our app and trigger a frame.
    // Ensure ConfigService is provided
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ConfigService()),
        ],
        child: const McpSwitchApp(),
      ),
    );

    // Verify that our app title shows up.
    expect(find.text('MCP Switch'), findsOneWidget);
    // Verify default editor is selected or shown
    expect(find.byType(EditorSelector), findsOneWidget);
  });
}
