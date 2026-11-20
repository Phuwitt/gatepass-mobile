import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

abstract interface class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage storage;
  const SecureSessionStore([this.storage = const FlutterSecureStorage()]);
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class GatepassApi {
  final http.Client client;
  final SessionStore store;
  Uri base;
  Json? session;
  Future<void>? _refreshing;
  GatepassApi({http.Client? client, SessionStore? store, Uri? base})
    : client = client ?? http.Client(),
      store = store ?? const SecureSessionStore(),
      base =
          base ??
          Uri.parse(
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: gatepassEmployeeApi,
            ),
          );

  static Uri validateBase(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ApiFailure(
        'ใส่ URL เซิร์ฟเวอร์ เช่น https://gatepass.example.com',
      );
    }
    final host = uri.host;
    final parts = host.split('.').map(int.tryParse).toList();
    final ipv4 =
        parts.length == 4 &&
        parts.every((v) => v != null && v >= 0 && v <= 255);
    final local =
        host == 'localhost' ||
        host == '127.0.0.1' ||
        (ipv4 &&
            (parts[0] == 10 ||
                (parts[0] == 192 && parts[1] == 168) ||
                (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31)));
    if (uri.scheme != 'https' &&
        !(kDebugMode && uri.scheme == 'http' && local)) {
      throw const ApiFailure(
        'ใช้ HTTPS สำหรับแอปจริง; HTTP เครือข่ายภายในใช้ได้เฉพาะ debug',
      );
    }
    return uri.replace(path: '', query: null, fragment: null);
  }

  Future<void> restore() async {
    final savedBase = await store.read('backend');
    if (savedBase != null) {
      try {
        final saved = validateBase(savedBase);
        if (base.origin == gatepassEmployeeApi &&
            gatepassDoorOrigins.contains(saved.origin)) {
          await configure(base.toString());
        } else {
          base = saved;
        }
      } on ApiFailure {
        await store.delete('backend');
        await clear();
      }
    }
    final raw = await store.read('session');
    if (raw != null) {
      try {
        session = jsonDecode(raw) as Json;
      } catch (_) {
        await clear();
      }
    }
  }

  Future<void> configure(String value) async {
    final uri = validateBase(value);
    if (uri.toString() != base.toString()) await clear();
    base = uri;
    await store.write('backend', base.toString());
  }

  Future<void> _save(Json value) async {
    session = value;
    await store.write('session', jsonEncode(value));
  }

  Future<void> clear() async {
    session = null;
    await store.delete('session');
  }

  Future<Json> _request(String path, {Json? body, String? token}) async {
    validateBase(base.toString());
    try {
      final request = http.Request(
        body == null ? 'GET' : 'POST',
        base.resolve(path),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (body != null) request.body = jsonEncode(body);
      // Credentials must never follow an HTTP redirect to another host.
      request.followRedirects = false;
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(const Duration(seconds: 20));
      Json data;
      try {
        data = jsonDecode(response.body) as Json;
      } catch (_) {
        throw const ApiFailure(
          'เซิร์ฟเวอร์ตอบข้อมูลไม่ถูกต้อง ตรวจ URL ที่ตั้งค่า',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiFailure(
          data['error']?.toString() ?? 'เชื่อมต่อไม่สำเร็จ',
          response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiFailure('เซิร์ฟเวอร์ไม่ตอบกลับ กรุณาลองใหม่');
    } on http.ClientException {
      throw const ApiFailure('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจ Wi-Fi และ URL');
    }
  }

  Future<void> login(String email, String password) async {
    await _save(
      await _request(
        '/api/mobile/login',
        body: {'email': email.trim(), 'password': password},
      ),
    );
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    if (session?['refresh_token'] == null) {
      throw const ApiFailure('กรุณาเข้าสู่ระบบใหม่', 401);
    }
    try {
      await _save(
        await _request(
          '/api/mobile/refresh',
          body: {'refresh_token': session!['refresh_token']},
        ),
      );
    } on ApiFailure catch (error) {
      if (error.status == 401 || error.status == 403) await clear();
      rethrow;
    }
  }

  Future<Json> call(String resource, {Json? body}) async {
    if (session == null) throw const ApiFailure('กรุณาเข้าสู่ระบบ', 401);
    if ((session!['expires_at'] as num? ?? 0) * 1000 <
        DateTime.now().millisecondsSinceEpoch + 30000) {
      await refresh();
    }
    try {
      return await _request(
        '/api/employee/$resource',
        body: body,
        token: session!['access_token'],
      );
    } on ApiFailure catch (error) {
      if (error.status != 401) rethrow;
      // Refresh only on authentication failure. Never replay an uncertain QR timeout.
      await refresh();
      return _request(
        '/api/employee/$resource',
        body: body,
        token: session!['access_token'],
      );
    }
  }

  Future<void> logout() async {
    try {
      if (session != null) {
        if ((session!['expires_at'] as num? ?? 0) * 1000 <
            DateTime.now().millisecondsSinceEpoch) {
          await refresh();
        }
        await _request(
          '/api/mobile/logout',
          body: {},
          token: session!['access_token'],
        );
      }
    } finally {
      await clear();
    }
  }
}
