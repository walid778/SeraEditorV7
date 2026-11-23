
import 'package:flutter/services.dart';

class DeviceCapabilityService {
  static const _channel = MethodChannel('smart_ocr/device');

  static Future<Map<String, dynamic>> getInfo() async {
    final result = await _channel.invokeMethod('getMemoryInfo');

    if (result == null) {
      throw Exception('Native memory information is empty');
    }

    return Map<String, dynamic>.from(result);
  }

  static Future<bool> canRunAi() async {
    try {
      final info = await getInfo();

      final totalRam =
          (info['totalRamMb'] as num).toInt();

      final availableRam =
          (info['availableRamMb'] as num).toInt();

      final storage =
          (info['freeStorageMb'] as num).toInt();

      print('Total RAM: $totalRam MB');
      print('Available RAM: $availableRam MB');
      print('Free storage: $storage MB');

      return totalRam >= 5500 &&
          availableRam >= 2200 &&
          storage >= 4000;
    } catch (e) {
      print('Device capability error: $e');
      return false;
    }
  }
}
