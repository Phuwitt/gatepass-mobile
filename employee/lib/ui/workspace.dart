import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../controller.dart';
import '../data/employee_photo.dart';
import '../data/models.dart';
import 'common.dart';
import 'nfc_pass.dart';
import 'photo_crop.dart';
import 'requests.dart';
import 'scanner.dart';

class EmployeeHome extends StatefulWidget {
  final AppController controller;
  final int initialTab;
  const EmployeeHome({
    super.key,
    required this.controller,
    this.initialTab = 0,
  });
  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome>
    with WidgetsBindingObserver {
  int tab = 0;
  String filter = 'all';
  final tabScroll = List.generate(4, (_) => ScrollController());
  Map<String, dynamic>? nfc;
  late final _photoStore = EmployeePhotoStore(ctrl.api.store);
  Uint8List? _photo;
  String? _photoOwner;
  bool _photoBusy = false;

  bool get _canChoosePhoto =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String? get _photoKey {
    final employee = ctrl.workspace?.person['id'];
    final user = ctrl.api.session?['user']?['id'];
    if (employee is! String || user is! String) return null;
    return EmployeePhotoStore.key(ctrl.api.base, employee, user);
  }

  Uint8List? get _currentPhoto => _photoOwner == _photoKey ? _photo : null;
  AppController get ctrl => widget.controller;
  static const names = ['หน้าหลัก', 'ประวัติ', 'แจ้งเตือน', 'ฉัน'];
  static const icons = [
    Icons.home_outlined,
    Icons.history,
    Icons.notifications_none,
    Icons.person_outline,
  ];
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, 3);
    WidgetsBinding.instance.addObserver(this);
    _capability();
    ctrl.addListener(_loadPhoto);
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final key = _photoKey;
    if (!_canChoosePhoto || key == _photoOwner) return;
    setState(() {
      _photoOwner = key;
      _photo = null;
    });
    if (key == null) return;
    try {
      final photo = await _photoStore.load(key);
      if (mounted && _photoKey == key && !_photoBusy) {
        setState(() => _photo = photo);
      }
    } catch (_) {
      // The profile remains usable when the local thumbnail is unavailable.
    }
    if (!mounted || _photoKey != key || _photoBusy) return;
    try {
      final recovered = await _photoStore.recoverSelection(key);
      if (recovered != null && mounted && _photoKey == key && !_photoBusy) {
        await _changePhoto(recovered: recovered);
      }
    } catch (_) {
      // The employee can choose a new photo if recovery is unavailable.
    }
  }

  Future<void> _changePhoto({bool remove = false, Uint8List? recovered}) async {
    final key = _photoKey;
    if (key == null || _photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      Uint8List? photo;
      if (remove) {
        await _photoStore.remove(key);
      } else {
        final selected = recovered ?? await _photoStore.choose(key);
        if (selected == null || !mounted || _photoKey != key) return;
        photo = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(builder: (_) => PhotoCropScreen(photo: selected)),
        );
        if (photo == null || !mounted || _photoKey != key) return;
        await _photoStore.save(key, photo);
      }
      if (mounted && _photoKey == key) {
        setState(() => _photo = photo);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remove ? 'นำรูปพนักงานออกแล้ว' : 'บันทึกรูปพนักงานแล้ว',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted && _photoKey == key) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remove
                  ? 'นำรูปออกไม่สำเร็จ กรุณาลองอีกครั้ง'
                  : 'บันทึกรูปไม่สำเร็จ ลองเลือกไฟล์ภาพอื่น',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Widget _portrait(double size) {
    final color = Theme.of(context).colorScheme;
    final photo = _currentPhoto;
    final placeholder = Icon(
      Icons.person_outline,
      size: size * 0.46,
      color: color.primary,
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: color.surfaceContainerHigh,
          child: SizedBox.square(
            dimension: size,
            child: photo == null
                ? placeholder
                : Image.memory(
                    photo,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _capability() async {
    if (ThemeData().platform != TargetPlatform.android) return;
    try {
      final result = await const MethodChannel(
        'gatepass/device',
      ).invokeMapMethod<String, dynamic>('nfcCapability');
      if (mounted) setState(() => nfc = result);
    } on PlatformException catch (_) {
      /* Unsupported device. */
    } on MissingPluginException catch (_) {
      /* Web preview. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ctrl.reload();
      _capability();
    }
  }

  @override
  void dispose() {
    ctrl.removeListener(_loadPhoto);
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in tabScroll) {
      controller.dispose();
    }
    super.dispose();
  }

  void scanner() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ScannerScreen(controller: ctrl)),
    );
  }

  void request(bool leave) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RequestScreen(controller: ctrl, leave: leave),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final body = SafeArea(
      child: RefreshIndicator(
        onRefresh: ctrl.reload,
        child: ListView(
          controller: tabScroll[tab],
          key: PageStorageKey('employee-tab-$tab'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (ctrl.error != null) ...[
              Notice(ctrl.error!, error: true),
              OutlinedButton.icon(
                onPressed: ctrl.reload,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองเชื่อมต่ออีกครั้ง'),
              ),
            ],
            if (ctrl.workspace == null) ...[
              const EmptyState(
                'ยังโหลดข้อมูลไม่ได้',
                'ตรวจเซิร์ฟเวอร์และเครือข่าย แล้วกดลองอีกครั้ง',
                icon: Icons.cloud_off_outlined,
              ),
              OutlinedButton(
                onPressed: ctrl.busy ? null : ctrl.logout,
                child: const Text("ออกจากระบบ / ตั้งค่าเซิร์ฟเวอร์ใหม่"),
              ),
            ] else
              ...switch (tab) {
                0 => home(),
                1 => history(),
                2 => notifications(),
                _ => account(),
              },
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.door_front_door_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text('GATEPASS'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'แจ้งเตือน',
            onPressed: () => setState(() => tab = 2),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: tab,
                  onDestinationSelected: (i) => setState(() => tab = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: List.generate(
                    4,
                    (i) => NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(names[i]),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: body,
                    ),
                  ),
                ),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : ios
          ? CupertinoTabBar(
              currentIndex: tab,
              onTap: (i) => setState(() => tab = i),
              items: List.generate(
                4,
                (i) => BottomNavigationBarItem(
                  icon: Icon(icons[i]),
                  label: names[i],
                ),
              ),
            )
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: List.generate(
                4,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: names[i],
                ),
              ),
            ),
    );
  }

  String dayLabel(DateTime date) {
    const days = [
      'จันทร์',
      'อังคาร',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
      'อาทิตย์',
    ];
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  void openRights() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('สิทธิ์ประตูของฉัน')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: rights(),
          ),
        ),
      ),
    ),
  );

  void nfcInfo() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => NfcPassScreen(controller: ctrl)),
  );

  void accessMethods() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('เลือกวิธีเข้าอาคาร')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'เลือกวิธีเข้าอาคาร',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('ใช้สิทธิ์ของคุณกับเครื่อง GATEPASS'),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.contactless_outlined),
                title: const Text('แตะ NFC'),
                subtitle: const Text('แตะมือถือ Android ที่เครื่อง GATEPASS'),
                trailing: const Icon(Icons.chevron_right),
                onTap: nfcInfo,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('สแกน Dynamic QR'),
                subtitle: const Text('สแกน QR ที่แสดงบนเครื่อง'),
                trailing: const Icon(Icons.chevron_right),
                onTap: ctrl.workspace!.enabled('qr') ? scanner : null,
              ),
              const SizedBox(height: 20),
              const Notice(
                'มีบัตรพนักงาน? แตะบัตรจริงที่เครื่องได้โดยตรงตามสิทธิ์ที่ HR กำหนด',
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _employeeCard(Json person) {
    final text = Theme.of(context).textTheme;
    const foreground = Color(0xFFF0FFFB);
    const accent = Color(0xFFA8DBD1);
    final details = [
      if (person['id'] case final String id when id.isNotEmpty) id,
      if (person['department'] case final String department
          when department.isNotEmpty)
        department,
    ].join(' · ');

    return Material(
      elevation: 3,
      shadowColor: const Color(0x78102735),
      color: const Color(0xFF123244),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF123244), Color(0xFF075854)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: openRights,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 20, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'บัตรพนักงาน',
                        style: text.titleSmall?.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _portrait(88),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person['name'] as String? ?? '',
                            style: text.headlineSmall?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              details,
                              style: text.bodyMedium?.copyWith(color: accent),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Divider(height: 1, color: Color(0x408ED4C7)),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ดูสิทธิ์เข้าอาคาร',
                          style: text.labelLarge?.copyWith(color: foreground),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> home() {
    final w = ctrl.workspace!, p = w.person, c = Theme.of(context).colorScheme;
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return [
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 12),
        child: Text(
          dayLabel(now),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ),
      _employeeCard(p),
      SectionTitle(
        'เข้าอาคาร',
        action: TextButton(
          onPressed: accessMethods,
          child: const Text('ดูทุกวิธี'),
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final nfcButton = OutlinedButton.icon(
            onPressed: nfcInfo,
            icon: const Icon(Icons.contactless_outlined, size: 20),
            label: const Text('แตะ NFC'),
          );
          final qrButton = FilledButton.icon(
            key: const Key('scan-qr'),
            onPressed: ctrl.busy || !w.enabled('qr') ? null : scanner,
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            label: const Text('สแกน QR'),
          );
          if (MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
              constraints.maxWidth < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [nfcButton, const SizedBox(height: 10), qrButton],
            );
          }
          return Row(
            children: [
              Expanded(child: nfcButton),
              const SizedBox(width: 12),
              Expanded(child: qrButton),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      if (!w.enabled('qr'))
        Text(
          'ยังไม่ได้รับสิทธิ์ QR กรุณาติดต่อ HR',
          style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
        ),
      SectionTitle(
        'กิจกรรมล่าสุด',
        action: TextButton(
          onPressed: () => setState(() => tab = 1),
          child: const Text('ดูทั้งหมด'),
        ),
      ),
      if (w.events.isEmpty)
        const EmptyState('ยังไม่มีประวัติ', 'รายการจะแสดงหลังใช้งานที่ประตู')
      else
        eventTile(w.events.first),
      const SizedBox(height: 18),
    ];
  }

  List<Widget> notifications() {
    final w = ctrl.workspace!, c = Theme.of(context).colorScheme;
    return [
      Text('แจ้งเตือน', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text('รายการล่าสุดของคุณ', style: TextStyle(color: c.onSurfaceVariant)),
      const SizedBox(height: 20),
      if (w.events.isEmpty && w.leaves.isEmpty && w.adjustments.isEmpty)
        const EmptyState(
          'ยังไม่มีรายการอัปเดต',
          'กิจกรรมเข้า–ออกและผลคำขอของคุณจะแสดงที่นี่',
        ),
      for (final event in w.events.take(3)) eventTile(event),
      for (final leave in w.leaves.take(3))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_note_outlined),
          title: Text('คำขอลา · ${statusName(leave['status'])}'),
          subtitle: Text('${leave['starts']} – ${leave['ends']}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => request(true),
        ),
      for (final adjustment in w.adjustments.take(3))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.edit_calendar_outlined),
          title: Text('แก้เวลางาน · ${statusName(adjustment['status'])}'),
          subtitle: Text(adjustment['day'] ?? ''),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => request(false),
        ),
      const SizedBox(height: 20),
      Text(
        'อัปเดตจากประวัติและคำขอของคุณ แอปรุ่นนี้ยังไม่มีการแจ้งเตือนแบบพุช',
        style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
      ),
    ];
  }

  Widget eventTile(Json e) {
    final c = Theme.of(context).colorScheme, allowed = e['status'] == 'allowed';
    final date = bangkokTime(e['created_at']);
    final direction = e['direction'] == 'in'
        ? 'เข้า'
        : e['direction'] == 'out'
        ? 'ออก'
        : 'ไม่ระบุทิศทาง';
    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (context) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'รายละเอียดเหตุการณ์',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                StatusPill(statusName(e['status']), positive: allowed),
                const SizedBox(height: 18),
                Text(
                  '$direction · ${methodName(e['method'])}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${DateFormat('dd/MM/yyyy HH:mm:ss').format(date)} · เวลาไทย',
                ),
                const SizedBox(height: 12),
                Text(e['reason'] ?? ''),
                const SizedBox(height: 20),
                const Notice(
                  'ผลตรวจสิทธิ์ไม่ใช่หลักฐานว่ากลอนเปิดหรือมีคนเดินผ่านประตูแล้ว',
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ปิด'),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 280
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$direction · ${methodName(e['method'])}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd/MM/yyyy · HH:mm').format(date),
                            style: TextStyle(
                              color: c.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StatusPill(
                            statusName(e['status']),
                            positive: allowed,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              e['direction'] == 'out'
                                  ? Icons.logout
                                  : Icons.login,
                              color: c.primary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$direction · ${methodName(e['method'])}',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy · HH:mm').format(date),
                                  style: TextStyle(
                                    color: c.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            statusName(e['status']),
                            positive: allowed,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                e['reason'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> history() {
    final events = ctrl.workspace!.events
        .where((e) => filter == 'all' || e['status'] == filter)
        .toList();
    return [
      Text(
        'ประวัติการเข้าออก',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(
        'ล่าสุดไม่เกิน 200 รายการ · เวลาไทย',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final f in ['all', 'allowed', 'denied'])
            ChoiceChip(
              showCheckmark: false,
              label: Text(f == 'all' ? 'ทั้งหมด' : statusName(f)),
              selected: filter == f,
              onSelected: (_) => setState(() => filter = f),
            ),
        ],
      ),
      const SizedBox(height: 18),
      if (events.isEmpty)
        const EmptyState(
          'ไม่พบรายการ',
          'ลองเปลี่ยนตัวกรอง หรือใช้งานที่ประตูก่อน',
        )
      else
        SurfaceGroup(
          padding: EdgeInsets.zero,
          children: [
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              eventTile(events[i]),
            ],
          ],
        ),
    ];
  }

  Widget methodRow(String method, bool enabled, String description) {
    final c = Theme.of(context).colorScheme;
    final icon = switch (method) {
      'face' => Icons.face_outlined,
      'qr' => Icons.qr_code_scanner,
      'card' => Icons.credit_card,
      _ => Icons.contactless_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: c.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  methodName(method),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                enabled ? 'ได้รับสิทธิ์' : 'ยังไม่เปิด',
                positive: enabled ? true : null,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Widget> rights() {
    final w = ctrl.workspace!, c = Theme.of(context).colorScheme;
    return [
      Text(
        'สิทธิ์ที่องค์กรให้คุณ',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(
        'ดูสิทธิ์ของคุณได้ที่นี่ หากต้องการเปลี่ยนแปลงให้ติดต่อ HR',
        style: TextStyle(color: c.onSurfaceVariant),
      ),
      const SectionTitle('วิธียืนยันตัวตน'),
      SurfaceGroup(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          methodRow(
            'qr',
            w.enabled('qr'),
            'ใช้แอปนี้สแกน QR บนหน้าจอเครื่องประตู',
          ),
          const Divider(height: 1),
          methodRow(
            'card',
            w.enabled('card'),
            'ใช้บัตรจริงที่องค์กรผูกกับข้อมูลของคุณ',
          ),
          const Divider(height: 1),
          methodRow(
            'nfc',
            w.enabled('nfc'),
            'สิทธิ์ NFC ขององค์กรแยกจากความพร้อมของมือถือ',
          ),
        ],
      ),
      const SectionTitle('ประตูที่เข้าได้'),
      if (w.permissions.isEmpty)
        const EmptyState(
          'ยังไม่มีสิทธิ์ประตู',
          'ติดต่อ HR เพื่อกำหนดประตูและช่วงเวลา',
        )
      else
        SurfaceGroup(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: [
            for (final p in w.permissions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 12,
                leading: Icon(Icons.door_front_door_outlined, color: c.primary),
                title: Text(p['gp_doors']?['name'] ?? p['door_id']),
                subtitle: Text('${hm(p['starts'])}–${hm(p['ends'])} · เวลาไทย'),
              ),
          ],
        ),
      const SectionTitle('การแตะมือถือ'),
      Notice(
        Theme.of(context).platform == TargetPlatform.iOS
            ? 'การแตะ iPhone แทนบัตรยังไม่เปิดใช้งาน เลือกสแกน QR หรือใช้บัตรจริง'
            : nfc?['hce'] == true
            ? 'เครื่องนี้รองรับ HCE${nfc?['enabled'] == true ? ' และเปิด NFC อยู่' : ' แต่ยังปิด NFC อยู่'} · เลือกแตะ NFC เพื่อเตรียมบัตร'
            : 'การแตะมือถือยังไม่พร้อมบนอุปกรณ์นี้ เลือกสแกน QR หรือใช้บัตรจริง',
      ),
    ];
  }

  Future<void> revoke(Json card) async {
    if (!await confirm(
      context,
      'ระงับบัตรนี้?',
      'บัตร ${card['label']} จะใช้ไม่ได้ทันที หากต้องการใช้อีกครั้งให้ติดต่อ HR',
    )) {
      return;
    }
    try {
      await ctrl.send('revoke-credential', {'id': card['id']});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ระงับบัตรแล้ว')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget profileField(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );

  List<Widget> account() {
    final w = ctrl.workspace!, p = w.person, c = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: 12),
      Center(child: _portrait(84)),
      const SizedBox(height: 16),
      Text(
        p['name'] ?? '',
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 5),
      Text(
        '${p['id']} · ${p['department'] ?? 'ยังไม่ระบุแผนก'}',
        style: TextStyle(color: c.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
      if (_canChoosePhoto && _photoKey != null)
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _photoBusy ? null : () => _changePhoto(),
                icon: const Icon(Icons.photo_outlined, size: 19),
                label: Text(
                  _currentPhoto == null
                      ? 'เพิ่มรูปพนักงาน'
                      : 'เปลี่ยนรูปพนักงาน',
                ),
              ),
              if (_currentPhoto != null)
                TextButton(
                  onPressed: _photoBusy
                      ? null
                      : () => _changePhoto(remove: true),
                  child: const Text('นำรูปออก'),
                ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      SurfaceGroup(
        children: [
          profileField('สถานะบัญชี', 'ใช้งานได้'),
          const Divider(height: 1),
          profileField(
            'บัตรพนักงาน',
            w.credentials.any((card) => card['revoked'] != true)
                ? 'ผูกแล้ว'
                : 'ยังไม่มีบัตรที่ใช้งานได้',
          ),
        ],
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.shield_outlined, color: c.primary),
        title: const Text('สิทธิ์ประตูของฉัน'),
        subtitle: const Text('ประตู ช่วงเวลา และวิธียืนยันตัวตน'),
        trailing: const Icon(Icons.chevron_right),
        onTap: openRights,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.event_note_outlined, color: c.primary),
        title: const Text('คำขอลา'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => request(true),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.edit_calendar_outlined, color: c.primary),
        title: const Text('ขอแก้เวลางาน'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => request(false),
      ),
      const SectionTitle('ข้อมูลพนักงาน'),
      SurfaceGroup(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          profileField(
            'อีเมล',
            ctrl.api.session?['user']?['email'] ?? 'ยังไม่ระบุ',
          ),
          const Divider(height: 1),
          profileField('แผนก', p['department'] ?? 'ยังไม่ระบุ'),
          const Divider(height: 1),
          profileField('ตำแหน่งงาน', p['job_title'] ?? 'ยังไม่ระบุ'),
        ],
      ),
      const SectionTitle('บัตรที่ผูกกับคุณ'),
      if (w.credentials.isEmpty)
        const EmptyState(
          'ยังไม่มีบัตรที่ผูก',
          'HR จะจับคู่บัตรกับข้อมูลพนักงานของคุณ',
        ),
      for (final card in w.credentials)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SurfaceGroup(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.credit_card, color: c.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card['label'] ?? methodName(card['method']),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'เลขท้าย ${card['last_four']}',
                          style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    card['revoked'] == true ? 'ระงับแล้ว' : 'ใช้งานอยู่',
                    positive: card['revoked'] == true ? null : true,
                  ),
                ],
              ),
              if (card['revoked'] != true) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: c.error),
                  onPressed: ctrl.busy ? null : () => revoke(card),
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('บัตรหาย / ระงับบัตร'),
                ),
              ],
            ],
          ),
        ),
      const SectionTitle('การเชื่อมต่อและความเป็นส่วนตัว'),
      SurfaceGroup(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.dns_outlined, size: 20, color: c.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ctrl.api.base.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'กล้องมือถือใช้สแกน QR สำหรับเข้าประตู หากต้องการเปลี่ยนสิทธิ์ให้ติดต่อ HR',
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: ctrl.busy
            ? null
            : () async {
                if (await confirm(
                  context,
                  'ออกจากระบบ?',
                  'คุณจะต้องเข้าสู่ระบบอีกครั้งเมื่อกลับมาใช้งาน',
                )) {
                  await ctrl.logout();
                }
              },
        icon: const Icon(Icons.logout, size: 20),
        label: const Text('ออกจากระบบ'),
      ),
    ];
  }
}
