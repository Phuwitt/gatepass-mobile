import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gatepass_employee/ui/photo_crop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Square crop can move to the top and stays inside the photo', () {
    const source = ui.Size(400, 800);
    expect(
      squarePhotoCrop(source, 1, const ui.Offset(200, 400)),
      const ui.Rect.fromLTWH(0, 200, 400, 400),
    );
    expect(
      squarePhotoCrop(source, 1, const ui.Offset(200, -50)),
      const ui.Rect.fromLTWH(0, 0, 400, 400),
    );
    expect(
      squarePhotoCrop(source, 2, const ui.Offset(480, 890)),
      const ui.Rect.fromLTWH(200, 600, 200, 200),
    );
  });

  test(
    'Encoded portrait contains the chosen region and excludes the rest',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 80, 80),
        ui.Paint()..color = const ui.Color(0xFFFF0000),
      );
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 80, 80, 80),
        ui.Paint()..color = const ui.Color(0xFF0000FF),
      );
      final picture = recorder.endRecording();
      final source = picture.toImageSync(80, 160);
      addTearDown(picture.dispose);
      addTearDown(source.dispose);

      final bytes = await encodeProfileCrop(
        source,
        squarePhotoCrop(const ui.Size(80, 160), 1, const ui.Offset(40, 40)),
      );
      final codec = await ui.instantiateImageCodec(bytes);
      final cropped = (await codec.getNextFrame()).image;
      addTearDown(codec.dispose);
      addTearDown(cropped.dispose);
      expect(cropped.width, 320);
      expect(cropped.height, 320);
      final rgba = (await cropped.toByteData())!.buffer.asUint8List();
      final center = (160 * 320 + 160) * 4;
      expect(rgba.sublist(center, center + 4), [255, 0, 0, 255]);
    },
  );
}
