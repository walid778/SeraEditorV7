import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ExcelExportService {
  ExcelExportService._();
  static final ExcelExportService instance = ExcelExportService._();

  static const String _templateAsset = 'assets/templates/JawabatTemplate.xlsx';

  // Columns A:R in the supplied template. Column S contains its original formula.
  static const List<String> _fieldKeys = [
    'engineNumber',
    'chassisNumber',
    'customerCode',
    'buyerName',
    'buyerAddress',
    'nationalId',
    'model',
    'cylinder',
    'bikeType',
    'capacity',
    'trafficUnit',
    'governorate',
    'subTrader',
    'bikeShape',
    'color',
    'notes',
    'electricityLetter',
    'paymentMethod',
  ];

  Future<String?> exportSheet({
    required int sheetId,
    required List<Map<String, Object?>> records,
    required String traderName,
    required bool isHistory,
  }) async {
    if (records.isEmpty) {
      throw StateError('الشيت فاضي. أضف سجلًا واحدًا على الأقل قبل التصدير.');
    }
    if (records.length > 4929) {
      throw StateError(
          'قالب Excel الحالي يستوعب 4929 سجلًا كحد أقصى في الشيت الواحد.');
    }
    final template = await rootBundle.load(_templateAsset);
    final output = _fillTemplate(
      Uint8List.sublistView(template),
      records,
    );

    final fileName = 'Jawabat_Sheet_${sheetId.toString().padLeft(4, '0')}.xlsx';
    
    final path = await FilePicker.platform.saveFile(
  dialogTitle: 'حفظ وتصدير الشيت',
  fileName: fileName,
  type: FileType.custom,
  allowedExtensions: const ['xlsx'],
  bytes: output,
);

    if (kIsWeb) {
  return path ?? fileName;
}
    return path;
  }

 
Uint8List _fillTemplate(
  Uint8List templateBytes,
  List<Map<String, Object?>> records,
) {
  final archive = ZipDecoder().decodeBytes(templateBytes);

  final worksheetIndex = archive.files.indexWhere(
    (file) => file.name == 'xl/worksheets/sheet1.xml',
  );

  if (worksheetIndex == -1) {
    throw StateError('قالب Excel غير صالح: ورقة الجواب غير موجودة.');
  }

  final worksheetFile = archive.files[worksheetIndex];
  var xml = utf8.decode(worksheetFile.content);

  for (var index = 0; index < records.length; index++) {
    final rowNumber = index + 2;
    final record = records[index];

    for (var column = 0; column < _fieldKeys.length; column++) {
      final cellRef = '${_columnName(column + 1)}$rowNumber';
      final value = (record[_fieldKeys[column]] ?? '').toString();

      xml = _replaceCell(xml, cellRef, value);
    }
  }

  
final worksheetBytes = Uint8List.fromList(utf8.encode(xml));

// إنشاء Archive جديد بدل تعديل قائمة الملفات الأصلية.
final updatedArchive = Archive();

for (final file in archive.files) {
  if (file.name == 'xl/worksheets/sheet1.xml') {
    updatedArchive.addFile(
      ArchiveFile(
        file.name,
        worksheetBytes.length,
        worksheetBytes,
      ),
    );
  } else {
    updatedArchive.addFile(file);
  }
}

final encoded = ZipEncoder().encode(updatedArchive);

if (encoded == null) {
  throw StateError('تعذر إنشاء ملف Excel.');
}

return Uint8List.fromList(encoded);

}

  String _replaceCell(String xml, String cellRef, String value) {
    final escaped = _xmlEscape(value);

    final pattern = RegExp(
      '<c\\s+r="$cellRef"([^>]*)\\s*/>|<c\\s+r="$cellRef"([^>]*)>.*?</c>',
      dotAll: true,
    );

    final match = pattern.firstMatch(xml);

    if (match != null) {
      final attrs = match.group(1) ?? match.group(2) ?? '';

      final styleMatch = RegExp(r'\bs="([^"]+)"').firstMatch(attrs);
      final style = styleMatch == null ? '' : ' s="${styleMatch.group(1)}"';

      final replacement = value.isEmpty
          ? '<c r="$cellRef"$style/>'
          : '<c r="$cellRef"$style t="inlineStr"><is><t xml:space="preserve">$escaped</t></is></c>';

      return xml.replaceRange(
        match.start,
        match.end,
        replacement,
      );
    }

    // الخلايا الفارغة K:R قد لا تكون موجودة في XML.
    if (value.isEmpty) return xml;

    final rowNumber = RegExp(r'\d+$').firstMatch(cellRef)!.group(0)!;

    final rowPattern = RegExp(
      '(<row\\b[^>]*\\br="$rowNumber"[^>]*>)(.*?)(</row>)',
      dotAll: true,
    );

    final rowMatch = rowPattern.firstMatch(xml);

    if (rowMatch == null) {
      throw StateError(
        'لم يتم العثور على الصف $rowNumber في قالب Excel.',
      );
    }

    final cell =
        '<c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">$escaped</t></is></c>';

    var rowContent = rowMatch.group(2)!;
    final statusCell = '<c r="S$rowNumber"';

    if (rowContent.contains(statusCell)) {
      rowContent = rowContent.replaceFirst(
        statusCell,
        '$cell$statusCell',
      );
    } else {
      rowContent += cell;
    }

    return xml.replaceRange(
      rowMatch.start,
      rowMatch.end,
      '${rowMatch.group(1)}$rowContent${rowMatch.group(3)}',
    );
  }

  String _columnName(int number) {
    var n = number;
    var result = '';
    while (n > 0) {
      final remainder = (n - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      n = (n - 1) ~/ 26;
    }
    return result;
  }

 
String _xmlEscape(String value) {
  final validXml = value.replaceAll(
    RegExp(
      r'[\x00-\x08\x0B\x0C\x0E-\x1F]',
    ),
    '',
  );

  return validXml
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}


}
