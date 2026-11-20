import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Rect squarePhotoCrop(Size source, double zoom, Offset center) {
  final side = source.shortestSide / zoom;
  return Rect.fromLTWH(
    (center.dx - side / 2).clamp(0.0, source.width - side),
    (center.dy - side / 2).clamp(0.0, source.height - side),
    side,
    side,
  );
}

Future<Uint8List> encodeProfileCrop(ui.Image source, Rect crop) async {
  const pixels = 320;
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    crop,
    const Rect.fromLTWH(0, 0, 320, 320),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  try {
    final thumbnail = await picture.toImage(pixels, pixels);
    try {
      final encoded = await thumbnail.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (encoded == null) {
        throw const FormatException('Could not encode photo');
      }
      return encoded.buffer.asUint8List(
        encoded.offsetInBytes,
        encoded.lengthInBytes,
      );
    } finally {
      thumbnail.dispose();
    }
  } finally {
    picture.dispose();
  }
}

class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.photo});

  final Uint8List photo;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  static const _maxZoom = 4.0;
  ui.Image? _image;
  Rect _crop = Rect.zero;
  double _zoom = 1;
  double _gestureZoom = 1;
  Offset _gestureAnchor = Offset.zero;
  bool _loadFailed = false;
  bool _saving = false;

  Size get _source => Size(_image!.width.toDouble(), _image!.height.toDouble());

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(widget.photo);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          final ratio = math.min(
            1.0,
            1024 / math.max(descriptor.width, descriptor.height),
          );
          final codec = await descriptor.instantiateCodec(
            targetWidth: math.max(1, (descriptor.width * ratio).round()),
            targetHeight: math.max(1, (descriptor.height * ratio).round()),
          );
          try {
            final image = (await codec.getNextFrame()).image;
            if (!mounted) {
              image.dispose();
              return;
            }
            setState(() {
              _image = image;
              _crop = squarePhotoCrop(_source, 1, _source.center(Offset.zero));
            });
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _adjust(double zoom, Offset center) => setState(() {
    _zoom = zoom;
    _crop = squarePhotoCrop(_source, _zoom, center);
  });

  Future<void> _save() async {
    final image = _image!.clone();
    final crop = _crop;
    setState(() => _saving = true);
    try {
      final bytes = await encodeProfileCrop(image, crop);
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ครอปรูปไม่สำเร็จ ลองอีกครั้ง')),
      );
    } finally {
      image.dispose();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final image = _image;
    return Scaffold(
      appBar: AppBar(title: const Text('ครอปรูปพนักงาน')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _loadFailed
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'เปิดรูปนี้ไม่ได้ ย้อนกลับแล้วเลือกไฟล์ภาพอื่น',
                    ),
                  )
                : image == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ลากรูปเพื่อจัดตำแหน่ง และใช้สองนิ้วหรือแถบด้านล่างเพื่อซูม',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final edge = constraints.biggest.shortestSide;
                              return Center(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: (details) {
                                    _gestureZoom = _zoom;
                                    _gestureAnchor =
                                        _crop.topLeft +
                                        details.localFocalPoint *
                                            (_crop.width / edge);
                                  },
                                  onScaleUpdate: (details) {
                                    if (_saving) return;
                                    final zoom = (_gestureZoom * details.scale)
                                        .clamp(1.0, _maxZoom);
                                    final side = _source.shortestSide / zoom;
                                    _adjust(
                                      zoom,
                                      _gestureAnchor +
                                          (Offset(edge / 2, edge / 2) -
                                                  details.localFocalPoint) *
                                              (side / edge),
                                    );
                                  },
                                  child: Semantics(
                                    label: 'ตัวอย่างรูปหลังครอป',
                                    image: true,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CustomPaint(
                                        size: Size.square(edge),
                                        painter: _CropPreview(image, _crop),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.zoom_out, color: color.onSurfaceVariant),
                            Expanded(
                              child: Slider(
                                value: _zoom,
                                min: 1,
                                max: _maxZoom,
                                onChanged: _saving
                                    ? null
                                    : (value) => _adjust(value, _crop.center),
                                semanticFormatterCallback: (value) =>
                                    'ซูม ${(value * 100).round()} เปอร์เซ็นต์',
                              ),
                            ),
                            Icon(Icons.zoom_in, color: color.onSurfaceVariant),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'กำลังบันทึก…' : 'ใช้รูปนี้'),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => _adjust(1, _source.center(Offset.zero)),
                          child: const Text('จัดกึ่งกลางใหม่'),
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

class _CropPreview extends CustomPainter {
  const _CropPreview(this.image, this.crop);

  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      crop,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final shadow = Paint()
      ..color = Colors.black26
      ..strokeWidth = 2;
    final line = Paint()
      ..color = Colors.white54
      ..strokeWidth = 0.8;
    for (final part in [1 / 3, 2 / 3]) {
      final x = size.width * part;
      final y = size.height * part;
      for (final paint in [shadow, line]) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CropPreview oldDelegate) =>
      image != oldDelegate.image || crop != oldDelegate.crop;
}
