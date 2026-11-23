
class BikeFormConfig {
  BikeFormConfig._();

  // جميع حقول النموذج.
  static const Map<String, String> fields = {
    'engineNumber': 'رقم الموتور',
    'chassisNumber': 'رقم الشاسيه',
    'customerCode': 'كود العميل',
    'buyerName': 'اسم المشتري',
    'buyerAddress': 'عنوان المشتري',
    'nationalId': 'الرقم القومي',
    'model': 'الموديل',
    'cylinder': 'السيلندر',
    'bikeType': 'نوع الدراجة',
    'capacity': 'السعة',
    'trafficUnit': 'وحدة المرور',
    'governorate': 'المحافظة',
    'subTrader': 'التاجر الفرعي',
    'bikeShape': 'شكل الدراجة',
    'color': 'اللون',
    'notes': 'ملاحظات',
    'electricityLetter': 'جواب كهرباء',
    'paymentMethod': 'طريقة الدفع',
  };

  // الحقول المطلوبة.
  static const Set<String> requiredKeys = {
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
  };

  // أنواع الدراجات.
  static const List<String> bikeTypes = [
    'دايون',
    'هاوجيانج',
    'سى ام سى',
    'حوا',
    'ويانج',
    'دايون بصندوق خلفى وثلاث عجلات',
    'Keeway',
    'LML-HAWA',
    'حوا مجهزة طبيا',
    'فيسبا-LML',
    'سكوتر',
    'BENELLI',
    'بصندوق خلفى وثلاث عجلات GMC حوا',
    'ZONTES',
    'HAWA GMC',
    'VIGOREY',
    'SRM',
    'HAWA PNE',
    'SCOOTER-DAYUN',
    'SCOOTER-HAOJIANG',
    'CMG-TIGER',
    'سكوتر كهرباء',
    'سكوتر كهرباء حوا',
    'SCOOTER-ARIC',
  ];

// استخراج المركز من العنوان المحفوظ.
static String getCenterFromAddress(String address) {
  final parts = address.split(' - ');
  return parts.isNotEmpty ? parts.first.trim() : address.trim();
}

// استخراج المحافظة من العنوان المحفوظ.
static String getGovernorateFromAddress(String address) {
  final parts = address.split(' - ');
  return parts.length > 1 ? parts.last.trim() : '';
}

  // أشكال الدراجات.
  static const List<String> bikeShapes = [
    'موتوسيكل',
    'تروسيكل بصندوق خلفى وثلاث عجلات',
    'سكوتر',
    'بيتش باجى',
  ];

  // التحقق من الرقم القومي.
  static bool isValidNationalId(String value) {
    final id = value.replaceAll('-', '').trim();

    if (!RegExp(r'^\d{14}$').hasMatch(id)) {
      return false;
    }

    return getBirthDateFromNationalId(id) != null;
  }

  // استخراج تاريخ الميلاد.
  static DateTime? getBirthDateFromNationalId(
    String nationalId,
  ) {
    final id = nationalId.replaceAll('-', '').trim();

    if (!RegExp(r'^\d{14}$').hasMatch(id)) {
      return null;
    }

    final centuryCode = int.parse(id.substring(0, 1));
    final yearPart = int.parse(id.substring(1, 3));
    final month = int.parse(id.substring(3, 5));
    final day = int.parse(id.substring(5, 7));

    int year;

    if (centuryCode == 2) {
      year = 1900 + yearPart;
    } else if (centuryCode == 3) {
      year = 2000 + yearPart;
    } else {
      return null;
    }

    final birthDate = DateTime(year, month, day);

    // التأكد من صحة التاريخ.
    if (birthDate.year != year ||
        birthDate.month != month ||
        birthDate.day != day) {
      return null;
    }

    if (birthDate.isAfter(DateTime.now())) {
      return null;
    }

    return birthDate;
  }

  // استخراج العمر من الرقم القومي.
  static int? getAgeFromNationalId(String nationalId) {
    final birthDate = getBirthDateFromNationalId(
      nationalId,
    );

    if (birthDate == null) return null;

    final today = DateTime.now();

    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month &&
            today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  // تحديد الحاجة إلى ولاية أو وصاية.
  static bool needsGuardianship(String nationalId) {
    final age = getAgeFromNationalId(nationalId);

    return age != null && age < 21;
  }

  // استخراج سنة الموديل من رقم الشاسيه.
  // حرف السنة يسبق آخر 7 أرقام.
  static String getModelYearFromChassis(
    String chassisNumber,
  ) {
    final chassis = chassisNumber.trim().toUpperCase();

    if (chassis.length < 8) return '';

    final lastSevenDigits = chassis.substring(
      chassis.length - 7,
    );

    if (!RegExp(r'^\d{7}$').hasMatch(lastSevenDigits)) {
      return '';
    }

    final yearCode = chassis[chassis.length - 8];

    switch (yearCode) {
      case 'V':
        return '2027';
      case 'T':
        return '2026';
      case 'S':
        return '2025';
      case 'R':
        return '2024';
      case 'P':
        return '2023';
      case 'N':
        return '2022';
      case 'M':
        return '2021';
      case 'L':
        return '2020';
      default:
        return '';
    }
  }

  // توحيد تنسيق السعة.
  static String normalizeCapacity(String value) {
    final text = value.trim();

    if (text.isEmpty) return '';

    final number = text
        .replaceFirst(
          RegExp(
            r'\s*(سم\s*3|سم³)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (number.isEmpty) return text;

   return '$numberسم3';
  }

    // الحقول التي لا تظهر في النموذج.
  static const Set<String> hiddenKeys = {
    'trafficUnit',
    'trafficPolice',
    'trafficDepartment',
    'governorate',
    'paymentMethod',
    'electricityLetter',
  };

  // إزالة وحدة السعة عند عرضها في النموذج.
  static String removeCapacityUnit(String value) {
    return value
        .replaceFirst(
          RegExp(
            r'\s*(سم\s*3|سم³)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }
  
}
