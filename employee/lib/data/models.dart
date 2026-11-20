typedef Json = Map<String, dynamic>;

const gatepassEmployeeApi = 'https://gatepass-employee-api.vercel.app';
const gatepassDoorOrigins = {
  'https://gatepass-prototype-rdb80jt2r-phuwitts-projects.vercel.app',
  'https://gatepass-prototype-prviwg81s-phuwitts-projects.vercel.app',
  'https://gatepass-prototype-c1wh0mlqr-phuwitts-projects.vercel.app',
};

class ApiFailure implements Exception {
  final String message;
  final int status;
  const ApiFailure(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

String methodName(String? method) => switch (method) {
  'card' => 'บัตร RFID',
  'nfc' => 'NFC / HCE',
  'qr' => 'QR Code',
  'face' => 'ใบหน้า',
  _ => 'ไม่ระบุ',
};
String statusName(String? status) => switch (status) {
  'allowed' => 'อนุญาต',
  'denied' => 'ปฏิเสธ',
  'pending' => 'รอพิจารณา',
  'approved' => 'อนุมัติ',
  'rejected' => 'ไม่อนุมัติ',
  _ => status ?? 'ไม่ระบุ',
};

class Workspace {
  final Json person;
  final List<Json> events,
      permissions,
      methods,
      leaves,
      adjustments,
      credentials;
  final Json capabilities;
  Workspace.fromJson(Json data)
    : person = Map<String, dynamic>.from(data['person'] as Map),
      events = rows(data['events']),
      permissions = rows(data['permissions']),
      methods = rows(data['methods']),
      leaves = rows(data['leaves']),
      adjustments = rows(data['adjustments']),
      credentials = rows(data['credentials']),
      capabilities = Map<String, dynamic>.from(
        data['capabilities'] as Map? ?? {},
      );
  static List<Json> rows(dynamic value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  bool enabled(String method) =>
      methods.any((m) => m['method'] == method && m['enabled'] == true);
}

String? parseQr(String value, Uri backend) {
  final raw = value.trim();
  if (RegExp(r'^[a-f0-9]{64}$').hasMatch(raw)) return raw;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  final ownOrigin = uri.origin == backend.origin;
  final gatepassDoor =
      backend.origin == gatepassEmployeeApi &&
      gatepassDoorOrigins.contains(uri.origin);
  if (!ownOrigin && !gatepassDoor) return null;
  final tokens = uri.queryParametersAll['qr'];
  if (tokens == null || tokens.length != 1) return null;
  final token = tokens.single;
  return RegExp(r'^[a-f0-9]{64}$').hasMatch(token) ? token : null;
}

DateTime bangkokTime(String iso) =>
    DateTime.parse(iso).toUtc().add(const Duration(hours: 7));
String hm(dynamic value) =>
    (value?.toString() ?? '').padRight(5, '-').substring(0, 5);
