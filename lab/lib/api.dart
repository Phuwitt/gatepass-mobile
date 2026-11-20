import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class LabFailure implements Exception {
  final String message;
  final int status;
  const LabFailure(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class LabApi {
  static const defaultBase = String.fromEnvironment('LAB_API_URL', defaultValue: 'https://gatepass-lab-phuwitt.vercel.app');
  final http.Client client;
  final FlutterSecureStorage storage;
  Uri base;
  String? token;
  LabApi({http.Client? client, FlutterSecureStorage? storage, Uri? base})
      : client = client ?? http.Client(),
        storage = storage ?? const FlutterSecureStorage(),
        base = base ?? Uri.parse(defaultBase);

  static String extractQr(String raw, Uri base, {required bool pairing}) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'https' || uri.host != base.host || uri.port != base.port || uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty || uri.path != (pairing ? '/join' : '/phone')) {
      throw const LabFailure('QR นี้ไม่ได้มาจากห้องทดลอง GATEPASS LAB ที่ตั้งไว้');
    }
    final value = uri.queryParameters[pairing ? 'pair' : 'token'] ?? '';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw const LabFailure('QR ไม่ครบหรือไม่ถูกต้อง กรุณาขอ QR ใหม่');
    }
    return value;
  }

  Future<Map<String, dynamic>> request(String action, [Map<String, dynamic> body = const {}]) async {
    try {
      final r = await client.post(base.resolve('/api/lab'), headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      }, body: jsonEncode({'action': action, ...body})).timeout(const Duration(seconds: 18));
      final value = jsonDecode(r.body);
      if (r.statusCode >= 400) throw LabFailure(value is Map ? value['error']?.toString() ?? 'ระบบทดสอบไม่พร้อม' : 'ระบบทดสอบไม่พร้อม', r.statusCode);
      if (value is! Map<String, dynamic>) throw const LabFailure('รูปแบบคำตอบจากระบบไม่ถูกต้อง');
      return value;
    } on LabFailure { rethrow; }
    catch (_) { throw const LabFailure('เชื่อมต่อห้องทดลองไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองใหม่'); }
  }

  Future<void> restore() async {
    token = await storage.read(key: 'lab_token');
    final savedBase = await storage.read(key: 'lab_base');
    if (savedBase == defaultBase) base = Uri.parse(savedBase!);
    if (savedBase != null && savedBase != defaultBase) { token = null; await disconnect(); }
  }

  Future<Map<String, dynamic>> pair(String raw) async {
    final value = extractQr(raw, base, pairing: true);
    final response = await request('pair-redeem', {'pair': value});
    final newToken = response['token'];
    if (newToken is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(newToken)) throw const LabFailure('จับคู่ไม่สำเร็จ กรุณาขอ QR ใหม่');
    token = newToken;
    await storage.write(key: 'lab_token', value: token);
    await storage.write(key: 'lab_base', value: base.origin);
    return response;
  }

  Future<void> disconnect() async {
    token = null;
    await storage.delete(key: 'lab_token');
    await storage.delete(key: 'lab_base');
  }
}
