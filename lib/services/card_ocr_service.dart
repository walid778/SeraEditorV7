import 'dart:async';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

class CardOcrService {
  CardOcrService._();

  static Future<void> _processingQueue = Future<void>.value();

  static Future<String> readImage(
    String imagePath, {
    String pageSegmentationMode = '6',
  }) async {
    final completer = Completer<String>();

    _processingQueue = _processingQueue.then((_) async {
      try {
        final result = await FlutterTesseractOcr.extractText(
          imagePath,
          language: 'ara+eng',
          args: {
            'psm': pageSegmentationMode,
            'preserve_interword_spaces': '1',
          },
        );

        completer.complete(cleanText(normalizeOCRText(result)));
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
    });

    return completer.future;
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

  static String normalizeOCRText(String text) {
    var result = normalizeDigits(text);

    const stars = [
      '☆', '★', '＊', '✱', '✳', '✲',
      '﹡', '⁎', '✴', '✵', '❋', '※',
    ];

    for (final star in stars) {
      result = result.replaceAll(star, '*');
    }

    result = result
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ى', 'ي');

    // تصحيح أخطاء OCR الشائعة في العنوان عند وجود "اول ... - استراق"
    result = result.replaceAllMapped(
      RegExp(r'(اول\s+[^\-\n]+?)\s*[-–—]+\s*استراق'),
      (m) => '${m.group(1)} - اسوان',
    );

    return result;
  }

  static String cleanText(String text) {
    return text
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll('\u0640', '')
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }

  static String cleanArabicField(String value) {
    return value
        .replaceAll(
          RegExp(r'[^\u0621-\u064A\u064B-\u065F\u0670\s\-]'),
          ' ',
        )
        .replaceAll(RegExp(r'[\s\-]+$'), '')
        .replaceAll(RegExp(r'^[\s\-]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _containsArabic(String value) {
    return RegExp(r'[\u0621-\u064A]').hasMatch(value);
  }

  static int _arabicCharacterCount(String value) {
    return RegExp(r'[\u0621-\u064A]').allMatches(value).length;
  }

  static List<String> _getLines(String text) {
    return cleanText(text)
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  // ---------------- NATIONAL ID ----------------

  static String extractNationalId(String text) {
    final normalized = normalizeDigits(text);

    final matches = RegExp(
      r'(?<!\d)\d(?:[\s.\-]?\d){13}(?!\d)',
    ).allMatches(normalized);

    for (final match in matches) {
      final id = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (id.length != 14) continue;

      final century = id[0];
      if (century != '2' && century != '3') continue;

      final year = int.parse(id.substring(1, 3));
      final month = int.parse(id.substring(3, 5));
      final day = int.parse(id.substring(5, 7));

      final fullYear = (century == '2' ? 1900 : 2000) + year;
      if (month < 1 || month > 12 || day < 1 || day > 31) continue;

      final date = DateTime.utc(fullYear, month, day);
      if (date.year == fullYear &&
          date.month == month &&
          date.day == day) {
        return id;
      }
    }

    final looseMatches =
        RegExp(r'[23][0-9\s.\-]{13,25}').allMatches(normalized);
    for (final m in looseMatches) {
      final digitsOnly = (m.group(0) ?? '').replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length >= 14) {
        final candidate = digitsOnly.substring(0, 14);
        if (candidate.startsWith('2') || candidate.startsWith('3')) {
          return candidate;
        }
      }
    }

    return '';
  }

  // ---------------- LABELED FIELDS ----------------

  static String extractLabeledValue(
    String text,
    List<String> labels,
  ) {
    final lines = cleanText(text)
        .split(RegExp(r'[\r\n]+'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      for (final label in labels) {
        final index = line.indexOf(label);
        if (index == -1) continue;

        final rawValue = line
            .substring(index + label.length)
            .replaceFirst(RegExp(r'^[\s:：\-]+'), '')
            .trim();

        if (rawValue.isNotEmpty) {
          return cleanArabicField(rawValue);
        }

        if (i + 1 < lines.length) {
          return cleanArabicField(lines[i + 1]);
        }
      }
    }

    return '';
  }

  // ---------------- NAME / ADDRESS ----------------

  static bool _isHeading(String line) {
    const headingWords = [
      'جمهوريه',
      'مصر',
      'العربيه',
      'بطاقه',
      'تحقيق',
      'الشخصيه',
      'وزاره',
      'الداخليه',
    ];

    return headingWords.any(line.contains);
  }

  static bool _isAddressLine(String line) {
    const addressWords = [
      'شارع',
      'ش.',
      'حاره',
      'زقاق',
      'عطفه',
      'منطقه',
      'قريه',
      'نجع',
      'مركز',
      'قسم',
      'محافظه',
      'مدينه',
      'اول',
      'ثان',
      'ثالث',
      'كفر',
      'اسوان',
      'كسرالحجر',
      'كسر الحجر',
    ];

    return addressWords.any(line.contains);
  }

  static bool _looksLikeNoiseLine(String originalLine) {
    final words = originalLine
        .replaceAll(RegExp(r'[^\u0621-\u064A\s]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return true;

    final singleLetterWords = words.where((w) => w.length == 1).length;
    if (words.length >= 3 && singleLetterWords >= 2) {
      return true;
    }

    final meaningfulWords = words.where((w) => w.length >= 3).length;
    if (meaningfulWords == 0) {
      return true;
    }

    return false;
  }

  static String _extractUnlabeledName(List<String> lines) {
    final nameParts = <String>[];

    for (final original in lines) {
      if (_looksLikeNoiseLine(original)) continue;

      final line = cleanArabicField(original);
      if (line.isEmpty ||
          _isHeading(line) ||
          _isAddressLine(line) ||
          !_containsArabic(line)) {
        continue;
      }

      final words = line
          .split(RegExp(r'\s+'))
          .where((w) => RegExp(r'^[\u0621-\u064A]{2,}$').hasMatch(w))
          .toList();

      if (words.isEmpty || words.length > 4) continue;
      if (_arabicCharacterCount(line) < 4) continue;

      nameParts.add(words.join(' '));
      if (nameParts.join(' ').split(RegExp(r'\s+')).length >= 4) {
        break;
      }
    }

    return nameParts.join(' ').trim();
  }

  static String _extractUnlabeledAddress(
    List<String> lines,
    String buyerName,
    String nationalId,
  ) {
    final addressLines = <String>[];

    for (final original in lines) {
      if (original.trim().isEmpty || _looksLikeNoiseLine(original)) {
        continue;
      }

      final digits = normalizeDigits(original).replaceAll(RegExp(r'\D'), '');
      if (nationalId.isNotEmpty && digits.contains(nationalId)) {
        continue;
      }

      final line = cleanArabicField(original);
      if (line.isEmpty ||
          _isHeading(line) ||
          line == cleanArabicField(buyerName) ||
          _arabicCharacterCount(line) < 4) {
        continue;
      }

      if (_isAddressLine(line)) {
        final words = line.split(RegExp(r'\s+'));
        if (words.length <= 12) {
          addressLines.add(line);
        }
      }
    }

    return addressLines.join(' ').trim();
  }

  // ---------------- EXTRACT CARD DATA ----------------

  static Map<String, String> extractCardData(String text) {
    final cleaned = cleanText(normalizeOCRText(text));
    final lines = _getLines(cleaned);

    final nationalId = extractNationalId(cleaned);

    var buyerName = extractLabeledValue(
      cleaned,
      [
        'اسم صاحب البطاقه',
        'اسم حامل البطاقه',
        'الاسم بالكامل',
        'الاسم',
      ],
    );

    if (buyerName.isEmpty) {
      buyerName = _extractUnlabeledName(lines);
    }

    var buyerAddress = extractLabeledValue(
      cleaned,
      [
        'محل الاقامه',
        'عنوان الاقامه',
        'العنوان',
      ],
    );

    if (buyerAddress.isEmpty) {
      buyerAddress = _extractUnlabeledAddress(
        lines,
        buyerName,
        nationalId,
      );
    }

    return {
      'buyerName': formatNameOutput(buyerName),
      'buyerAddress': formatAddressOutput(buyerAddress),
      'nationalId': nationalId,
    };
  }

  // ---------------- CROP EXTRACTORS ----------------

  static String extractNameFromCrop(String text) {
    final cleaned = cleanText(normalizeOCRText(text));
    final lines = _getLines(cleaned);
    final parts = <String>[];

    for (final line in lines) {
      final clean = cleanArabicField(line);
      if (clean.isEmpty || _isHeading(clean) || !_containsArabic(clean)) {
        continue;
      }
      final words = clean
          .split(RegExp(r'\s+'))
          .where((w) => RegExp(r'^[\u0621-\u064A]{2,}$').hasMatch(w))
          .toList();
      if (words.isNotEmpty) {
        parts.add(words.join(' '));
      }
    }

    return formatNameOutput(parts.join(' '));
  }

  static String extractAddressFromCrop(String text) {
    final cleaned = cleanText(normalizeOCRText(text));
    final lines = _getLines(cleaned);
    final parts = <String>[];

    for (final line in lines) {
      final clean = cleanArabicField(line);
      if (clean.isEmpty || _isHeading(clean) || !_containsArabic(clean)) {
        continue;
      }
      if (_arabicCharacterCount(clean) >= 3) {
        parts.add(clean);
      }
    }

    return formatAddressOutput(parts.join(' '));
  }

  static String _coerceLookalikeDigits(String input) {
    var s = normalizeDigits(input);
    s = s
        .replaceAll(RegExp(r'[oO]'), '0')
        .replaceAll(RegExp(r'[lI|]'), '1')
        .replaceAll(RegExp(r'[zZ]'), '2')
        .replaceAll(RegExp(r'[sS]'), '5')
        .replaceAll(RegExp(r'[bBG]'), '6')
        .replaceAll(RegExp(r'[tT]'), '7')
        .replaceAll(RegExp(r'[qQg]'), '9');
    return s;
  }

  static String extractNationalIdFromCrop(String text) {
    final strict = extractNationalId(text);
    if (strict.isNotEmpty) return strict;

    final coerced = _coerceLookalikeDigits(text);
    final strictCoerced = extractNationalId(coerced);
    if (strictCoerced.isNotEmpty) return strictCoerced;

    final digitsOnly = coerced.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 14) {
      final match14 = RegExp(r'[23]\d{13}').firstMatch(digitsOnly);
      if (match14 != null) return match14.group(0)!;
      return digitsOnly.substring(0, 14);
    }
    return digitsOnly;
  }

  // ---------------- OUTPUT FORMATTERS ----------------

  static String formatNameOutput(String name) {
    return cleanArabicField(name)
        .replaceAll('ّ', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String formatAddressOutput(String address) {
    var formatted = cleanArabicField(address)
        .replaceAll('ّ', '')
        .replaceAll(RegExp(r'\s*[-–—]+\s*'), ' - ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    formatted = formatted
        .replaceAll(RegExp(r'اسي\s*ان'), 'اسوان')
        .replaceAll(RegExp(r'اسو+ان'), 'اسوان')
        .replaceAll('استراق', 'اسوان');

    return formatted;
  }
}