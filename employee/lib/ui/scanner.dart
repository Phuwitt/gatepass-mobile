import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controller.dart';
import '../data/models.dart';
import 'common.dart';

class ScannerScreen extends StatefulWidget {
  final AppController controller;
  const ScannerScreen({super.key, required this.controller});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final camera = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final manual = TextEditingController();
  bool submitting = false,
      processing = false,
      torch = false,
      manualEntry = false;
  String? error;
  Future<void> startCamera() async {
    try {
      await camera.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'เปิดกล้องไม่ได้ ตรวจสิทธิ์กล้องในการตั้งค่าของเครื่อง แล้วลองอีกครั้ง',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !processing && !manualEntry) {
      startCamera();
    } else {
      camera.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    camera.dispose();
    manual.dispose();
    super.dispose();
  }

  Future<void> consume(String value) async {
    if (processing) return;
    final token = parseQr(value, widget.controller.api.base);
    if (token == null) {
      setState(() => error = 'QR นี้ไม่ใช่ของเซิร์ฟเวอร์องค์กรที่ตั้งค่าไว้');
      return;
    }
    setState(() {
      processing = true;
      error = null;
    });
    await camera.stop();
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยืนยันการใช้ QR'),
        content: const Text(
          'ใช้บัญชีของคุณตรวจสิทธิ์ที่ประตูนี้ รหัสมีอายุสั้นและใช้ได้ครั้งเดียว',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (proceed != true) {
      if (mounted) setState(() => processing = false);
      if (!manualEntry) await startCamera();
      return;
    }
    setState(() => submitting = true);
    try {
      final result = await widget.controller.send('qr', {'token': token});
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => AccessResult(result: result)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e\nหากส่งไปแล้วแต่ไม่เห็นผล ให้ตรวจประวัติก่อนสแกนใหม่';
          processing = false;
          submitting = false;
        });
      }
      if (!manualEntry) await startCamera();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('สแกน QR ที่ประตู'),
      actions: [
        IconButton(
          tooltip: 'เปิดหรือปิดไฟฉาย',
          onPressed: processing
              ? null
              : () async {
                  await camera.toggleTorch();
                  setState(() => torch = !torch);
                },
          icon: Icon(torch ? Icons.flash_on : Icons.flash_off),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('เล็งกล้องไปที่ QR บนหน้าจอเครื่องประตู'),
          const SizedBox(height: 16),
          if (!manualEntry)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 320,
                child: MobileScanner(
                  controller: camera,
                  onDetect: (capture) {
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code != null) consume(code);
                  },
                  errorBuilder: (c, e) => ColoredBox(
                    color: const Color(0xff061c2c),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.no_photography_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'เปิดกล้องไม่ได้\nอนุญาตกล้องให้ GATEPASS ในการตั้งค่าของเครื่อง แล้วกลับมาลองใหม่',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: () => camera.start(),
                              child: const Text('ลองเปิดกล้องอีกครั้ง'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (error != null) Notice(error!, error: true),
          if (submitting) const Center(child: CircularProgressIndicator()),
          TextButton(
            onPressed: processing
                ? null
                : () async {
                    setState(() => manualEntry = !manualEntry);
                    if (manualEntry) {
                      await camera.stop();
                    } else {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) startCamera();
                      });
                    }
                  },
            child: Text(
              manualEntry ? 'กลับไปใช้กล้อง' : 'มีลิงก์ QR อยู่แล้ว?',
            ),
          ),
          if (manualEntry) ...[
            TextField(
              controller: manual,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'วางลิงก์ QR จากเครื่องประตู',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: processing ? null : () => consume(manual.text),
              child: const Text('ตรวจ QR'),
            ),
          ],
          const SizedBox(height: 16),
          const Text('สแกน QR ที่เครื่องประตู แล้วรอระบบตรวจสิทธิ์'),
        ],
      ),
    ),
  );
}

class AccessResult extends StatelessWidget {
  final Json result;
  const AccessResult({super.key, required this.result});
  @override
  Widget build(BuildContext context) {
    final allowed = result['allowed'] == true,
        c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ผลตรวจสิทธิ์')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Icon(
                    allowed ? Icons.verified_outlined : Icons.block,
                    size: 88,
                    color: allowed ? c.primary : c.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    allowed ? 'ตรวจสิทธิ์ผ่าน' : 'ไม่อนุญาต',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result['reason']?.toString() ?? '',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Notice(
                    result['actuation_enabled'] == true
                        ? 'รอผลตอบรับจากเครื่องประตู การตรวจสิทธิ์ผ่านยังไม่ยืนยันว่ากลอนเปิดแล้ว'
                        : 'ระบบยังไม่เปิดใช้งานสั่งกลอนจริง ผลนี้เป็นการตรวจสิทธิ์เท่านั้น',
                  ),
                  if (result['request_id'] != null)
                    SelectableText(
                      'หมายเลขคำขอ\n${result['request_id']}',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('กลับหน้าหลัก'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
