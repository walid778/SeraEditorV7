
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device_identity_service.dart';

class LicenseService {
  LicenseService._();

  static final LicenseService instance = LicenseService._();

  static const String _storageKey = 'sera_editor_license_v1';

  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _publicKeyBase64 =
      'Fls8zbdVT5zAath+QS6m/0VsTyd6nPDYLDLZwMrEtBg=';

  final Ed25519 _algorithm = Ed25519();

  Future<bool> validateLicense() async {
    try {
      final savedCode = await _storage.read(
        key: _storageKey,
      );

      if (savedCode == null || savedCode.trim().isEmpty) {
        return false;
      }

      return await _isValidLicense(savedCode);
    } catch (_) {
      return false;
    }
  }

  Future<bool> activate(String code) async {
    final normalizedCode = code.trim();

    if (normalizedCode.isEmpty) return false;

    try {
      final isValid = await _isValidLicense(normalizedCode);

      if (!isValid) return false;

      await _storage.write(
        key: _storageKey,
        value: normalizedCode,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeLicense() async {
    await _storage.delete(key: _storageKey);
  }

  Future<bool> _isValidLicense(String code) async {
    try {
      final parts = code.split('.');

      if (parts.length != 2) return false;

      final payloadBytes = base64Url.decode(
        base64Url.normalize(parts[0]),
      );

      final signatureBytes = base64Url.decode(
        base64Url.normalize(parts[1]),
      );

      final decoded = jsonDecode(
        utf8.decode(payloadBytes),
      );

      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final payload = decoded;

      // التحقق من المنتج.
      if (payload['product'] != 'sera_editor') {
        return false;
      }

      // التحقق من تاريخ انتهاء الترخيص.
      final expiresAt = payload['exp'];

      if (expiresAt is! int) return false;

      final now =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (now >= expiresAt) return false;

      // التحقق من معرّف الجهاز الموجود في الترخيص.
      final licensedDeviceId = payload['deviceId'];

      if (licensedDeviceId is! String ||
          licensedDeviceId.isEmpty) {
        return false;
      }

      // الحصول على معرّف التثبيت الحالي.
      final currentDeviceId =
          await DeviceIdentityService.instance.getDeviceId();

      if (licensedDeviceId != currentDeviceId) {
        return false;
      }

      // التحقق من التوقيع الرقمي باستخدام المفتاح العام.
      final publicKey = SimplePublicKey(
        base64Decode(_publicKeyBase64),
        type: KeyPairType.ed25519,
      );

      final signature = Signature(
        signatureBytes,
        publicKey: publicKey,
      );

      return await _algorithm.verify(
        payloadBytes,
        signature: signature,
      );
    } catch (_) {
      return false;
    }
  }
}
