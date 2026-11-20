import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';

class EmployeePhotoStore {
  EmployeePhotoStore(this.storage);

  final SessionStore storage;
  final _picker = ImagePicker();
  static const _pendingKey = 'employee-photo:pending';

  static String key(Uri backend, String employee, String user) =>
      'employee-photo:${backend.origin}:$employee:$user';

  Future<Uint8List?> load(String key) async {
    final saved = await storage.read(key);
    return saved == null ? null : base64Decode(saved);
  }

  Future<Uint8List?> recoverSelection(String key) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        await storage.read(_pendingKey) != key) {
      return null;
    }
    try {
      final result = await _picker.retrieveLostData();
      final files = result.files;
      return files == null || files.isEmpty ? null : await _read(files.first);
    } finally {
      await storage.delete(_pendingKey);
    }
  }

  Future<Uint8List?> choose(String key) async {
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (android) await storage.write(_pendingKey, key);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      return file == null ? null : await _read(file);
    } finally {
      if (android) await storage.delete(_pendingKey);
    }
  }

  Future<void> save(String key, Uint8List croppedPhoto) =>
      storage.write(key, base64Encode(croppedPhoto));

  Future<void> remove(String key) => storage.delete(key);

  Future<Uint8List> _read(XFile file) async {
    if (await file.length() > 12 * 1024 * 1024) {
      throw const FormatException('Profile photo is too large');
    }
    return file.readAsBytes();
  }
}
