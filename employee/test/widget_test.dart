import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gatepass_employee/ui/nfc_pass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gatepass_employee/main.dart';
import 'package:gatepass_employee/controller.dart';
import 'package:gatepass_employee/data/api.dart';
import 'package:gatepass_employee/data/employee_photo.dart';

class MemoryStore implements SessionStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

AppController controller({required bool signedIn, bool nfc = false}) {
  final store = MemoryStore();
  final session = {
    'access_token': 'test-access-token',
    'refresh_token': 'test-refresh-token',
    'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    'user': {'id': 'test-user', 'email': 'employee@example.test'},
  };
  if (signedIn) store.values['session'] = jsonEncode(session);
  return AppController(
    GatepassApi(
      store: store,
      client: MockClient((request) async {
        if (request.url.path == '/api/mobile/login') {
          expect(jsonDecode(request.body)['email'], 'employee@example.test');
          return http.Response(jsonEncode(session), 200);
        }
        expect(request.url.path, '/api/employee/workspace');
        expect(request.headers['Authorization'], 'Bearer test-access-token');
        return http.Response(
          jsonEncode({
            'person': {'id': 'T01', 'name': 'พนักงานทดสอบ', 'department': 'QA'},
            'methods': [
              {'method': 'qr', 'enabled': true},
              if (nfc) {'method': 'nfc', 'enabled': true},
            ],
            'credentials': [
              if (nfc) {'method': 'nfc', 'revoked': false, 'last_four': '9999'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    ),
  );
}

void main() {
  testWidgets('NFC checks credential suffix and shows delivery status', (
    tester,
  ) async {
    const device = MethodChannel('gatepass/device');
    final calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(device, (call) async {
      calls.add(call);
      return switch (call.method) {
        'nfcCapability' => {'nfc': true, 'hce': true, 'enabled': true},
        'armNfc' => true,
        'nfcPassStatus' => 'sent',
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(device, null));
    final c = controller(signedIn: true, nfc: true);
    await c.initialize();
    expect(c.workspace?.enabled('nfc'), isTrue, reason: c.error);
    await tester.pumpWidget(MaterialApp(home: NfcPassScreen(controller: c)));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    final submit = find.text('บันทึกรหัสและพร้อมแตะ');

    expect(calls.map((call) => call.method), contains('nfcCapability'));
    expect(
      field,
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .join(' | '),
    );
    await tester.enterText(field, '1' * 64);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'armNfc'), isEmpty);

    final code = '1' * 60 + '9999';
    await tester.enterText(field, code);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      calls.singleWhere((call) => call.method == 'armNfc').arguments,
      code,
    );
    expect(find.textContaining('แตะด้านหลังมือถือ'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('มือถือส่งรหัสแล้ว'), findsOneWidget);
  });

  testWidgets(
    'Saved profile photo follows the employee card and can be removed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = controller(signedIn: true);
      final key = EmployeePhotoStore.key(c.api.base, 'T01', 'test-user');
      await c.api.store.write(
        key,
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(GatepassApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('ดูสิทธิ์เข้าอาคาร'));
      await tester.pumpAndSettle();
      expect(find.text('สิทธิ์ประตูของฉัน'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('ฉัน').last);
      await tester.pumpAndSettle();
      expect(find.text('เปลี่ยนรูปพนักงาน'), findsOneWidget);
      await tester.tap(find.text('นำรูปออก'));
      await tester.pumpAndSettle();
      expect(find.text('เพิ่มรูปพนักงาน'), findsOneWidget);
      expect(await c.api.store.read(key), isNull);
    },
  );

  testWidgets('Workspace only appears after authenticated API login', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final c = controller(signedIn: false);
    await tester.pumpWidget(GatepassApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('ดูตัวอย่างด้วยข้อมูลสมมติ'), findsNothing);
    expect(find.text('พนักงานทดสอบ'), findsNothing);
    await c.login('employee@example.test', 'employee-test-password');
    await tester.pumpAndSettle();
    expect(find.textContaining('พนักงานทดสอบ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact screen layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpWidget(
      GatepassApp(
        controller: controller(signedIn: true),
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thai text at 150 percent fits all destinations in dark mode', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      GatepassApp(
        controller: controller(signedIn: true),
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['หน้าหลัก', 'ประวัติ', 'แจ้งเตือน', 'ฉัน']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      final error = tester.takeException();
      expect(error, isNull, reason: error?.toString());
    }
  });
}
