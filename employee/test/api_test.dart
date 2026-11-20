import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gatepass_employee/data/api.dart';
import 'package:gatepass_employee/data/models.dart';
import 'widget_test.dart' show MemoryStore;

void main() {
  test(
    'Backend URL rejects public cleartext and disguised private hostnames',
    () {
      expect(
        GatepassApi.validateBase('https://gatepass.example.com').scheme,
        'https',
      );
      for (final value in [
        'http://public.example.com',
        'http://10.evil.example',
        'https://user:password@example.com',
        'https://example.com/nested',
      ]) {
        expect(
          () => GatepassApi.validateBase(value),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );
  test('QR rejects foreign origin and malformed or duplicate tokens', () {
    final base = Uri.parse('https://gatepass.example.com');
    final token = 'a' * 64;
    expect(parseQr('https://gatepass.example.com/?qr=$token', base), token);
    expect(parseQr('https://evil.example/?qr=$token', base), null);
    expect(parseQr('http://gatepass.example.com/?qr=$token', base), null);
    expect(
      parseQr('https://gatepass.example.com/?qr=$token&qr=$token', base),
      null,
    );
    expect(parseQr('javascript:alert(1)', base), null);
  });
  test(
    'Concurrent calls share session refresh and use the new token',
    () async {
      var refreshes = 0, workspaces = 0;
      final client = MockClient((r) async {
        if (r.url.path == '/api/mobile/refresh') {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            jsonEncode({
              'access_token': 'new',
              'refresh_token': 'new-refresh-token',
              'expires_at':
                  DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            }),
            200,
          );
        }
        workspaces++;
        expect(r.headers['Authorization'], 'Bearer new');
        return http.Response('{}', 200);
      });
      final api = GatepassApi(
        client: client,
        store: MemoryStore(),
        base: Uri.parse('https://gatepass.example.com'),
      );
      api.session = {
        'access_token': 'old',
        'refresh_token': 'old-refresh-token',
        'expires_at': 1,
      };
      await Future.wait([api.call('workspace'), api.call('workspace')]);
      expect(refreshes, 1);
      expect(workspaces, 2);
    },
  );
  test('Rejected refresh deletes local credentials', () async {
    final store = MemoryStore();
    await store.write('session', 'sensitive');
    final api = GatepassApi(
      store: store,
      client: MockClient(
        (_) async => http.Response('{"error":"expired"}', 401),
      ),
    );
    api.session = {'refresh_token': 'expired-refresh-token', 'expires_at': 1};
    await expectLater(api.call('workspace'), throwsA(isA<ApiFailure>()));
    expect(api.session, isNull);
    expect(await store.read('session'), isNull);
  });
  test('Offline logout still removes credentials', () async {
    final store = MemoryStore();
    await store.write('session', 'sensitive');
    final api = GatepassApi(
      store: store,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    api.session = {
      'access_token': 'secret',
      'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    };
    await expectLater(api.logout(), throwsA(isA<ApiFailure>()));
    expect(api.session, isNull);
    expect(await store.read('session'), isNull);
  });
}
