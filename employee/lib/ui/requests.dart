import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controller.dart';
import '../data/models.dart';
import 'common.dart';

class RequestScreen extends StatefulWidget {
  final AppController controller;
  final bool leave;
  const RequestScreen({
    super.key,
    required this.controller,
    required this.leave,
  });
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final form = GlobalKey<FormState>(), reason = TextEditingController();
  DateTime start = DateTime.now(), end = DateTime.now();
  TimeOfDay arrival = const TimeOfDay(hour: 9, minute: 0),
      departure = const TimeOfDay(hour: 18, minute: 0);
  String kind = 'personal';
  String? error;
  bool busy = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  String time(TimeOfDay v) =>
      '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  Future<void> pickDate(bool first) async {
    final result = await showDatePicker(
      context: context,
      initialDate: first ? start : end,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (result != null) {
      setState(() {
        if (first) {
          start = result;
          if (end.isBefore(start)) end = start;
        } else {
          end = result;
        }
      });
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (widget.leave && end.isBefore(start)) {
      setState(() => error = 'วันสิ้นสุดต้องไม่ก่อนวันเริ่ม');
      return;
    }
    if (!widget.leave &&
        arrival.hour * 60 + arrival.minute >=
            departure.hour * 60 + departure.minute) {
      setState(() => error = 'เวลาเข้าต้องก่อนเวลาออก ยังไม่รองรับกะข้ามวัน');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final date = DateFormat('yyyy-MM-dd');
    try {
      await widget.controller.send(
        widget.leave ? 'leave' : 'adjustment',
        widget.leave
            ? {
                'starts': date.format(start),
                'ends': date.format(end),
                'kind': kind,
                'reason': reason.text.trim(),
              }
            : {
                'day': date.format(start),
                'requested_in': time(arrival),
                'requested_out': time(departure),
                'reason': reason.text.trim(),
              },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งคำขอแล้ว รอ HR พิจารณา')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.workspace;
    final rows = widget.leave ? data?.leaves : data?.adjustments;
    return Scaffold(
      appBar: AppBar(title: Text(widget.leave ? 'คำขอลา' : 'ขอแก้เวลางาน')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('ส่งให้ HR พิจารณา การส่งคำขอยังไม่เปลี่ยนผลเวลางาน'),
            const SizedBox(height: 20),
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.leave) ...[
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      decoration: const InputDecoration(
                        labelText: 'ประเภทการลา',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'personal',
                          child: Text('ลากิจ'),
                        ),
                        DropdownMenuItem(value: 'sick', child: Text('ลาป่วย')),
                        DropdownMenuItem(
                          value: 'annual',
                          child: Text('ลาพักร้อน'),
                        ),
                      ],
                      onChanged: busy ? null : (v) => setState(() => kind = v!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => pickDate(true),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      '${widget.leave ? 'วันเริ่ม' : 'วันที่'}: ${DateFormat('dd/MM/yyyy').format(start)}',
                    ),
                  ),
                  if (widget.leave)
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => pickDate(false),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        'วันสิ้นสุด: ${DateFormat('dd/MM/yyyy').format(end)}',
                      ),
                    ),
                  if (!widget.leave) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final v = await showTimePicker(
                                context: context,
                                initialTime: arrival,
                              );
                              if (v != null) setState(() => arrival = v);
                            },
                      child: Text('เวลาเข้า ${time(arrival)}'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final v = await showTimePicker(
                                context: context,
                                initialTime: departure,
                              );
                              if (v != null) setState(() => departure = v);
                            },
                      child: Text('เวลาออก ${time(departure)}'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reason,
                    enabled: !busy,
                    maxLength: 1000,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'เหตุผล'),
                    validator: (v) => (v?.trim().length ?? 0) < 3
                        ? 'ระบุเหตุผลอย่างน้อย 3 ตัวอักษร'
                        : null,
                  ),
                  if (error != null) Notice(error!, error: true),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy ? 'กำลังส่ง…' : 'ส่งคำขอ'),
                  ),
                ],
              ),
            ),
            const SectionTitle('คำขอที่ผ่านมา'),
            if (rows == null || rows.isEmpty)
              const EmptyState(
                'ยังไม่มีคำขอ',
                'คำขอของคุณและผลพิจารณาจะแสดงที่นี่',
              ),
            for (final r in rows ?? <Json>[])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  widget.leave
                      ? '${r['starts']} – ${r['ends']}'
                      : '${r['day']} · ${hm(r['requested_in'])}–${hm(r['requested_out'])}',
                ),
                subtitle: Text(r['reason']?.toString() ?? ''),
                trailing: Text(statusName(r['status'])),
              ),
          ],
        ),
      ),
    );
  }
}
