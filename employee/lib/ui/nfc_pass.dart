import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller.dart';
import '../data/models.dart';

class NfcPassScreen extends StatefulWidget {
  final AppController controller;

  const NfcPassScreen({super.key, required this.controller});

  @override
  State<NfcPassScreen> createState() => _NfcPassScreenState();
}

class _NfcPassScreenState extends State<NfcPassScreen>
    with WidgetsBindingObserver {
  static const device = MethodChannel('gatepass/device');
  static final codePattern = RegExp(r'^[0-9a-f]{64}$');
  final input = TextEditingController();
  Map<String, dynamic>? capability;
  Timer? poll;
  DateTime? countdown;
  bool loading = true;
  bool linked = false;
  bool busy = false;
  String? message;

  AppController get ctrl => widget.controller;
  bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  String? get storageKey {
    final user = ctrl.api.session?['user']?['id'];
    final employee = ctrl.workspace?.person['id'];
    if (user == null || employee == null) return null;
    return 'nfc:${ctrl.api.base.origin}:$user:$employee';
  }

  bool canUseCode(String? code) =>
      code != null &&
      codePattern.hasMatch(code) &&
      ctrl.workspace?.credentials.any(
            (card) =>
                card['method'] == 'nfc' &&
                card['revoked'] == false &&
                card['last_four']?.toString().toLowerCase() ==
                    code.substring(60),
          ) ==
          true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  Future<void> refresh() async {
    final key = storageKey;
    try {
      final result = android
          ? await device.invokeMapMethod<String, dynamic>('nfcCapability')
          : null;
      final saved = key == null ? null : await ctrl.api.store.read(key);
      if (!mounted) return;
      setState(() {
        capability = result;
        linked = canUseCode(saved);
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          message = 'อ่านความพร้อมของ NFC ไม่สำเร็จ';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    } else if (countdown != null) {
      poll?.cancel();
      setState(() => countdown = null);
    }
  }

  Future<void> prepare() async {
    final key = storageKey;
    if (key == null) return;
    final entered = input.text.trim().toLowerCase();
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await ctrl.reload();
      if (!mounted || key != storageKey) return;
      if (ctrl.error != null) {
        throw const ApiFailure('เช็กสิทธิ์กับเซิร์ฟเวอร์ไม่สำเร็จ ลองอีกครั้ง');
      }
      if (ctrl.workspace?.enabled('nfc') != true) {
        throw const ApiFailure('บัญชีนี้ยังไม่ได้รับสิทธิ์ NFC');
      }
      final code = linked ? await ctrl.api.store.read(key) : entered;
      if (!mounted || key != storageKey) return;
      if (code == null || !codePattern.hasMatch(code)) {
        throw const ApiFailure('กรอกรหัส NFC 64 ตัวจากผู้ดูแล');
      }
      if (!canUseCode(code)) {
        setState(() => linked = false);
        throw const ApiFailure('รหัสนี้ไม่ตรงกับบัตร NFC ที่ใช้งานอยู่ในบัญชี');
      }
      if (!linked) {
        await ctrl.api.store.write(key, code);
      }
      if (!mounted || key != storageKey) return;
      input.clear();
      setState(() => linked = true);
      final armed = await device.invokeMethod<bool>('armNfc', code);
      if (!mounted) {
        await device.invokeMethod<void>('disarmNfc');
        return;
      }
      if (armed != true) {
        throw const ApiFailure('เปิด NFC และปลดล็อกมือถือก่อนลองอีกครั้ง');
      }
      setState(
        () => countdown = DateTime.now().add(const Duration(seconds: 30)),
      );
      poll = Timer.periodic(const Duration(seconds: 1), (_) => readStatus());
    } on ApiFailure catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => message = 'เตรียมแตะ NFC ไม่สำเร็จ ลองอีกครั้ง');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> readStatus() async {
    final active = countdown;
    String? status;
    try {
      status = await device.invokeMethod<String>('nfcPassStatus');
    } on PlatformException {
      status = null;
    } on MissingPluginException {
      status = null;
    }
    if (!mounted || active == null || active != countdown) return;
    if (status == 'ready') {
      setState(() {});
      return;
    }
    poll?.cancel();
    setState(() {
      countdown = null;
      message = switch (status) {
        'sent' => 'มือถือส่งรหัสแล้ว ดูผลอนุญาตที่เครื่องหรือในประวัติ',
        'idle' => 'หมดเวลารอแตะ กดพร้อมแตะเพื่อเริ่มใหม่',
        _ => 'อ่านสถานะ NFC ไม่สำเร็จ ลองอีกครั้ง',
      };
    });
  }

  Future<void> unlink() async {
    final key = storageKey;
    if (key == null) return;
    setState(() => busy = true);
    try {
      await ctrl.api.store.delete(key);
      if (mounted) setState(() => linked = false);
    } catch (_) {
      if (mounted) setState(() => message = 'ลบรหัสที่บันทึกไว้ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openSettings() async {
    try {
      await device.invokeMethod<void>('openNfcSettings');
    } catch (_) {
      if (mounted) setState(() => message = 'เปิด NFC จากการตั้งค่ามือถือ');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poll?.cancel();
    if (android && countdown != null) {
      unawaited(
        device.invokeMethod<void>('disarmNfc').catchError((Object _) {}),
      );
    }
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = countdown?.difference(DateTime.now()).inSeconds;
    return Scaffold(
      appBar: AppBar(title: const Text('บัตร NFC')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.contactless_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (capability?['hce'] != true || capability?['nfc'] != true)
              const Text('การแตะต้องใช้ Android ที่รองรับ NFC และ HCE')
            else if (ctrl.workspace?.enabled('nfc') != true)
              const Text('ขอให้ผู้ดูแลเปิดสิทธิ์ NFC และออกรหัสให้บัญชีนี้')
            else if (capability?['enabled'] != true)
              FilledButton(
                onPressed: openSettings,
                child: const Text('ไปเปิด NFC ในการตั้งค่า'),
              )
            else if (remaining != null)
              Text(
                'แตะด้านหลังมือถือกับเครื่อง GATEPASS ภายใน ${(remaining + 1).clamp(0, 30)} วินาที',
                style: Theme.of(context).textTheme.titleLarge,
              )
            else ...[
              if (!linked) ...[
                const Text(
                  'นำรหัส NFC ที่ผู้ดูแลออกให้มากรอกเพื่อผูกกับเครื่องนี้',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: input,
                  enabled: !busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'รหัส NFC 64 ตัว',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: busy ? null : prepare,
                child: Text(linked ? 'พร้อมแตะ' : 'บันทึกรหัสและพร้อมแตะ'),
              ),
              if (linked)
                TextButton(
                  onPressed: busy ? null : unlink,
                  child: const Text('เปลี่ยนรหัส NFC ในมือถือเครื่องนี้'),
                ),
            ],
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!),
            ],
          ],
        ),
      ),
    );
  }
}
