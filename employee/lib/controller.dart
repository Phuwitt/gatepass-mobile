import 'package:flutter/foundation.dart';
import 'data/api.dart';
import 'data/models.dart';

class AppController extends ChangeNotifier {
  final GatepassApi api;
  Workspace? workspace;
  bool starting = true, busy = false;
  String? error;
  AppController(this.api);
  bool get authenticated => api.session != null;
  Future<void> initialize() async {
    try {
      await api.restore();
      if (authenticated) await reload();
    } catch (e) {
      error = e.toString();
    }
    starting = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.login(email, password);
      await reload();
    } catch (e) {
      error = e.toString();
    }
    busy = false;
    notifyListeners();
  }

  Future<void> reload() async {
    error = null;
    try {
      workspace = Workspace.fromJson(await api.call('workspace'));
    } catch (e) {
      error = e.toString();
      if (e is ApiFailure && (e.status == 401 || e.status == 403)) {
        await api.clear();
        workspace = null;
      }
    }
    notifyListeners();
  }

  Future<Json> send(String resource, Json value) async {
    if (busy) throw const ApiFailure('กำลังส่งคำขอ กรุณารอสักครู่');
    busy = true;
    notifyListeners();
    try {
      final result = await api.call(resource, body: value);
      await reload();
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    busy = true;
    notifyListeners();
    try {
      await api.logout();
    } catch (_) {
      /* Local credentials are always removed by the API client. */
    } finally {
      workspace = null;
      busy = false;
      error = null;
      notifyListeners();
    }
  }
}
