
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MachineOcrService {
  MachineOcrService._();

  static final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  static bool _closed = false;

  // قراءة الشاسيه والموتور باستخدام Google ML Kit فقط.
  static Future<String> readImage(String imagePath) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Google ML Kit غير مدعوم على Flutter Web. '
        'شغّل التطبيق على Android أو iOS.',
      );
    }

    if (_closed) {
      throw StateError(
        'MachineOcrService has been closed.',
      );
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);

    final result = cleanText(
      normalizeDigits(recognizedText.text),
    );

    debugPrint('========== GOOGLE ML KIT ==========');
    debugPrint(result);
    debugPrint('===================================');

    return result;
  }

  static Future<void> close() async {
    if (_closed) return;

    await _recognizer.close();
    _closed = true;
  }

  // ---------------- NORMALIZATION ----------------

  static String normalizeDigits(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const english = '0123456789';

    var result = text;

    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], english[i]);
      result = result.replaceAll(persian[i], english[i]);
    }

    return result;
  }

  static String cleanText(String text) {
    return text
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }

  static String cleanCode(String value) {
    return normalizeDigits(value)
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
  }

  // ---------------- CHASSIS ----------------

  static bool isGoodChassisNumber(String value) {
    if (value.length < 7 || value.length > 20) {
      return false;
    }

    final digits = RegExp(r'\d').allMatches(value).length;
    return digits >= 4;
  }

  static String extractChassisFromStarredText(String text) {
    final normalized = normalizeDigits(text);

    final matches = RegExp(
      r'\*([^*]{5,40})\*',
      dotAll: true,
    ).allMatches(normalized);

    for (final match in matches) {
      final value = cleanCode(match.group(1) ?? '');

      if (isGoodChassisNumber(value)) {
        return value;
      }
    }

    // في حالة قراءة نجمة واحدة فقط.
    final firstStar = normalized.indexOf('*');
    if (firstStar == -1) return '';

    final raw = normalized.substring(firstStar + 1);
    final firstLine = raw.split('\n').first;
    final value = cleanCode(firstLine);

    return isGoodChassisNumber(value) ? value : '';
  }

  static bool _isLikelyEngineCode(String value) {
    final digits = RegExp(r'\d').allMatches(value).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(value).length;

    return value.length <= 10 &&
        letters >= 3 &&
        digits <= 4;
  }

  static int _calculateChassisScore(String value) {
    var score = 0;

    final digits = RegExp(r'\d').allMatches(value).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(value).length;

    score += digits * 10;

    if (value.length >= 9) score += 20;
    if (value.length >= 12) score += 15;
    if (digits >= 6) score += 30;
    if (letters > digits * 2) score -= 30;

    return score;
  }

  static String findBestChassisCandidate(String text) {
    final normalized = normalizeDigits(text);
    final candidates = <String, int>{};

    final matches = RegExp(
      r'[A-Za-z0-9]{7,20}',
    ).allMatches(normalized);

    for (final match in matches) {
      final value = cleanCode(match.group(0) ?? '');

      if (!isGoodChassisNumber(value)) continue;
      if (_isLikelyEngineCode(value)) continue;

      candidates[value] = _calculateChassisScore(value);
    }

    if (candidates.isEmpty) return '';

    final sorted = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  // ---------------- CANDIDATES ----------------

  static List<String> extractCandidates(String text) {
    final normalized = normalizeDigits(text);

    final candidates = <String>[];
    final seen = <String>{};

    final starred = extractChassisFromStarredText(normalized);

    if (starred.isNotEmpty) {
      candidates.add(starred);
      seen.add(starred);
    }

    final matches = RegExp(
      r'[A-Za-z0-9][A-Za-z0-9\s\-]{4,30}',
    ).allMatches(normalized);

    for (final match in matches) {
      final value = cleanCode(match.group(0) ?? '');

      if (value.length < 5 || value.length > 20) continue;
      if (!RegExp(r'\d').hasMatch(value)) continue;

      if (seen.add(value)) {
        candidates.add(value);
      }
    }

    return candidates;
  }
}
