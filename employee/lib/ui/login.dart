import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller.dart';
import 'common.dart';

class LoginScreen extends StatefulWidget {
  final AppController controller;
  const LoginScreen({super.key, required this.controller});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!form.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    await widget.controller.login(email.text, password.text);
    password.clear();
  }

  Future<void> configure() async {
    final url = TextEditingController(
      text: widget.controller.api.base.toString(),
    );
    String? error;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('เชื่อมต่อองค์กร'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'มือถือจริงใช้ IP ของ Mac ใน Wi-Fi เดียวกัน เช่น http://192.168.2.40:3000\nAndroid Emulator ใช้ http://10.0.2.2:3000',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'URL เซิร์ฟเวอร์',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.controller.api.configure(url.text);
                  if (c.mounted) Navigator.pop(c);
                  if (mounted) setState(() {});
                } catch (e) {
                  update(() => error = e.toString());
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    // Dialog route may still animate out; avoid disposing its controller early.
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller, c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.door_front_door_outlined, size: 22, color: c.primary),
            const SizedBox(width: 8),
            const Text('GATEPASS'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'เข้าสู่ระบบ',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: c.surfaceContainerHigh,
                          child: Icon(
                            Icons.verified_user_outlined,
                            size: 36,
                            color: c.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (ctrl.error != null) Notice(ctrl.error!, error: true),
                      Text(
                        'อีเมลพนักงาน',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: email,
                        enabled: !ctrl.busy,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'name@company.com',
                        ),
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : 'กรอกอีเมลให้ถูกต้อง',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'รหัสผ่าน',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: password,
                        enabled: !ctrl.busy,
                        autofillHints: const [AutofillHints.password],
                        obscureText: obscure,
                        onFieldSubmitted: (_) => ctrl.busy ? null : login(),
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            tooltip: obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 21,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'กรอกรหัสผ่าน' : null,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: ctrl.busy ? null : login,
                        child: ctrl.busy
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.onPrimary,
                                ),
                              )
                            : const Text('เข้าสู่ระบบ'),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'บัญชีของคุณออกให้โดย HR\nต้องการความช่วยเหลือ? ติดต่อผู้ดูแล',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          useSafeArea: true,
                          showDragHandle: true,
                          builder: (context) => const Padding(
                            padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
                            child: Text(
                              'หากลืมรหัสผ่าน ให้ติดต่อ HR หรือผู้ดูแลเพื่อยืนยันตัวตนและตั้งรหัสใหม่ บัญชีนี้ใช้ร่วมกับเว็บ GATEPASS',
                            ),
                          ),
                        ),
                        child: const Text('ลืมรหัสผ่าน?'),
                      ),
                      const Divider(),
                      TextButton.icon(
                        onPressed: ctrl.busy ? null : configure,
                        icon: const Icon(Icons.dns_outlined, size: 18),
                        label: const Text('ตั้งค่าเซิร์ฟเวอร์ขององค์กร'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
