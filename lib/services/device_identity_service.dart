
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceIdentityService instance =
      DeviceIdentityService._();

  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _storageKey =
      'sera_editor_device_identity_v1';

  String? _cachedId;

  Future<String> getDeviceId() async {
    final cached = _cachedId;
    if (cached != null) return cached;

    final savedId = await _storage.read(key: _storageKey);

    if (savedId != null && savedId.isNotEmpty) {
      _cachedId = savedId;
      return savedId;
    }

    final random = Random.secure();

    final bytes = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    );

    final deviceId = base64UrlEncode(bytes)
        .replaceAll('=', '');

    await _storage.write(
      key: _storageKey,
      value: deviceId,
    );

    _cachedId = deviceId;
    return deviceId;
  }
}
