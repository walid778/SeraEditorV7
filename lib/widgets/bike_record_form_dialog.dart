import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:seraeditor/constants/area_governorates.dart';
import 'package:seraeditor/constants/bike_form_config.dart';
import 'package:seraeditor/database/app_database.dart';
import 'package:seraeditor/screens/image_data_extractor_page.dart';
import 'package:seraeditor/services/machine_ocr_service.dart';
import 'package:seraeditor/utils/app_message.dart';
import 'package:seraeditor/utils/app_theme.dart';

class BikeRecordFormDialog extends StatefulWidget {
  final Map<String, Object?>? record;
  final Map<String, String>? extractedData;

  const BikeRecordFormDialog({
    super.key,
    this.record,
    this.extractedData,
  });

  @override
  State<BikeRecordFormDialog> createState() =>
      _BikeRecordFormDialogState();
}

class _BikeRecordFormDialogState
    extends State<BikeRecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late final Map<String, TextEditingController> controllers;

  // حقلا عنوان المشتري.
  late final TextEditingController centerController;
  late final TextEditingController governorateController;

  List<String> chassisPrefixes = [];

  bool loadingPrefixes = true;
  bool _updatingFromChassis = false;
  bool _scanningMachineField = false;

  int _chassisRequestId = 0;

  bool get isEditing => widget.record != null;

  int? get buyerAge {
    return BikeFormConfig.getAgeFromNationalId(
      controllers['nationalId']?.text ?? '',
    );
  }

  bool get needsGuardianship {
    final age = buyerAge;
    return age != null && age < 21;
  }

  @override
  void initState() {
    super.initState();

    controllers = {
      for (final key in BikeFormConfig.fields.keys)
        key: TextEditingController(
          text: '${widget.record?[key] ??
              widget.extractedData?[key] ??
              (key == 'cylinder' ? '1' : '')}',
        ),
    };

    // تجهيز حقلي المركز والمحافظة من العنوان القديم.
    _initializeAddress();

    // عرض السعة بدون الوحدة.
    final capacityController = controllers['capacity'];

    if (capacityController != null) {
      capacityController.text =
          BikeFormConfig.removeCapacityUnit(
        capacityController.text,
      );
    }

    // استخراج سنة الموديل من رقم الشاسيه.
    final chassisController = controllers['chassisNumber'];
    final modelController = controllers['model'];

    if (modelController != null &&
        modelController.text.trim().isEmpty &&
        chassisController != null) {
      final year =
          BikeFormConfig.getModelYearFromChassis(
        chassisController.text,
      );

      if (year.isNotEmpty) {
        modelController.text = year;
      }
    }

    chassisController?.addListener(_onChassisChanged);

    _loadChassisPrefixes();
  }

  @override
  void dispose() {
    controllers['chassisNumber']?.removeListener(
      _onChassisChanged,
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }

    centerController.dispose();
    governorateController.dispose();

    super.dispose();
  }

  // تقسيم العنوان المحفوظ إلى مركز ومحافظة.
  void _initializeAddress() {
    final savedAddress =
        controllers['buyerAddress']!.text.trim();

    String center = savedAddress;
    String governorate = '';

    final separatorIndex = savedAddress.lastIndexOf(' - ');

    if (separatorIndex != -1) {
      center = savedAddress
          .substring(0, separatorIndex)
          .trim();

      governorate = savedAddress
          .substring(separatorIndex + 3)
          .trim();
    }

    centerController = TextEditingController(
      text: center,
    );

    governorateController = TextEditingController(
      text: governorate,
    );

    // لو العنوان القديم يحتوي على مركز فقط.
    if (governorate.isEmpty && center.isNotEmpty) {
      _updateGovernorate(center);
    }
  }

  // تحديث المحافظة تلقائياً من المركز.
  void _updateGovernorate(String center) {
    final governorate =
        AreaGovernorates.getGovernorate(center);

    // لو المركز معروف، حدد المحافظة تلقائياً.
    // لو غير معروف، اترك المحافظة للكتابة اليدوية.
    if (governorate != null) {
      governorateController.text = governorate;
    }
  }

  // التحقق من صحة المركز والمحافظة.
  String? _validateCenter(String? value) {
    final center = value?.trim() ?? '';

    if (center.isEmpty) {
      return 'من فضلك اكتب المركز';
    }

    // لا يشترط وجود المركز في القائمة.
    return null;
  }

  // استخراج البيانات من الصور.
  Future<void> _openImageExtractor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImageDataExtractorPage(),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      for (final entry in result.entries) {
        final controller = controllers[entry.key];

        if (controller == null) continue;

        final value = entry.value.trim();

        if (value.isNotEmpty) {
          controller.text = value;
        }
      }

      // لو تم استخراج عنوان المشتري.
      if (result.containsKey('buyerAddress')) {
        _initializeExtractedAddress();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نقل البيانات إلى النموذج'),
      ),
    );
  }

  // تحديث حقلي العنوان بعد استخراج البيانات.
  void _initializeExtractedAddress() {
    final address = controllers['buyerAddress']!.text.trim();

    final separatorIndex = address.lastIndexOf(' - ');

    if (separatorIndex != -1) {
      centerController.text =
          address.substring(0, separatorIndex).trim();

      governorateController.text =
          address.substring(separatorIndex + 3).trim();
    } else {
      centerController.text = address;
      _updateGovernorate(address);
    }
  }

  // التحقق من الحقول المخفية.
  bool _isHiddenField(MapEntry<String, String> entry) {
    return BikeFormConfig.hiddenKeys.contains(entry.key);
  }

  // تحميل بادئات الشاسيه.
  Future<void> _loadChassisPrefixes() async {
    try {
      final rows =
          await AppDatabase.instance.getChassisPrefixItems();

      if (!mounted) return;

      final prefixes = rows
          .map((row) => '${row['Prefix'] ?? ''}'.trim())
          .where((prefix) => prefix.isNotEmpty)
          .toSet()
          .toList();

      setState(() {
        chassisPrefixes = prefixes;
        loadingPrefixes = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingPrefixes = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل بادئات الشاسيه: $e'),
        ),
      );
    }
  }

  // متابعة تغيير رقم الشاسيه.
  Future<void> _onChassisChanged() async {
    if (_updatingFromChassis) return;

    final chassis =
        controllers['chassisNumber']?.text.trim() ?? '';

    final requestId = ++_chassisRequestId;

    // استخراج سنة الموديل.
    final year =
        BikeFormConfig.getModelYearFromChassis(chassis);

    final modelController = controllers['model'];

    if (modelController != null && year.isNotEmpty) {
      if (modelController.text != year) {
        modelController.value = TextEditingValue(
          text: year,
          selection: TextSelection.collapsed(
            offset: year.length,
          ),
        );
      }
    }

    if (chassis.isEmpty) return;

    try {
      final capacity =
          await AppDatabase.instance.getCapacityForChassis(
        chassis,
      );

      if (!mounted ||
          requestId != _chassisRequestId ||
          capacity.trim().isEmpty) {
        return;
      }

      final currentChassis =
          controllers['chassisNumber']?.text.trim() ?? '';

      if (currentChassis.toUpperCase() !=
          chassis.toUpperCase()) {
        return;
      }

      final capacityController = controllers['capacity'];

      if (capacityController != null) {
        _updatingFromChassis = true;

        capacityController.text =
            BikeFormConfig.removeCapacityUnit(capacity);

        _updatingFromChassis = false;
      }
    } catch (_) {
      _updatingFromChassis = false;
    }
  }

  // =========================================================
  // DIRECT MACHINE OCR (CHASSIS / ENGINE)
  // =========================================================

  Future<void> _showMachineSourceSheet(String fieldKey) async {
    if (_scanningMachineField) return;

    if (kIsWeb) {
      AppMessage.warning(
        context,
        'قراءة الشاسيه والموتور باستخدام Google ML Kit تتطلب Android أو iOS.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppTheme.goldLight,
                    ),
                    title: const Text('التقاط صورة بالكاميرا'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _scanMachineFieldDirect(
                        fieldKey,
                        ImageSource.camera,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_rounded,
                      color: AppTheme.goldLight,
                    ),
                    title: const Text('اختيار صورة من المعرض'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _scanMachineFieldDirect(
                        fieldKey,
                        ImageSource.gallery,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _scanMachineFieldDirect(
    String fieldKey,
    ImageSource source,
  ) async {
    if (_scanningMachineField) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 3000,
      );

      if (image == null || !mounted) return;

      setState(() => _scanningMachineField = true);

      final String text = await MachineOcrService.readImage(image.path);
      if (!mounted) return;

      final String extracted = fieldKey == 'chassisNumber'
          ? _extractChassisValue(text)
          : _extractEngineValue(text);

      if (extracted.isNotEmpty && controllers[fieldKey] != null) {
        controllers[fieldKey]!.text = extracted.toUpperCase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fieldKey == 'chassisNumber'
                  ? 'تم سحب رقم الشاسيه: $extracted'
                  : 'تم سحب رقم الموتور: $extracted',
            ),
          ),
        );
      } else {
        AppMessage.warning(
          context,
          'لم يتم التعرف على رقم واضح، جرّب صورة أوضح.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessage.warning(context, 'تعذرت قراءة الصورة: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _scanningMachineField = false);
      }
    }
  }

  String _extractChassisValue(String text) {
    final starred = MachineOcrService.extractChassisFromStarredText(text);
    if (starred.isNotEmpty) return starred;

    final candidates =
        MachineOcrService.extractCandidates(text).toSet().toList();
    final vinCandidates = candidates
        .where((c) => RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(c))
        .toList();
    if (vinCandidates.isNotEmpty) return vinCandidates.first;

    return MachineOcrService.findBestChassisCandidate(text);
  }

  String _extractEngineValue(String text) {
    final candidates =
        MachineOcrService.extractCandidates(text).toSet().toList();

    final serialNumbers = candidates
        .where((c) => RegExp(r'^\d{8,15}$').hasMatch(c))
        .toList();

    final alphanumeric = candidates.where((c) {
      final digits = RegExp(r'\d').allMatches(c).length;
      final letters = RegExp(r'[A-Za-z]').allMatches(c).length;
      return c.length >= 6 &&
          c.length <= 15 &&
          digits >= 3 &&
          letters >= 1;
    }).toList();

    if (serialNumbers.isNotEmpty) {
      serialNumbers.sort((a, b) => b.length.compareTo(a.length));
      return serialNumbers.first;
    }
    if (alphanumeric.isNotEmpty) {
      alphanumeric.sort((a, b) => b.length.compareTo(a.length));
      return alphanumeric.first;
    }
    if (candidates.length == 1) {
      return candidates.first;
    }
    return '';
  }

  // التحقق من الحقول.
  String? _validateField(String key, String? value) {
    final text = value?.trim() ?? '';

    if (BikeFormConfig.requiredKeys.contains(key) &&
        text.isEmpty) {
      return 'هذا الحقل مطلوب';
    }

    if (key == 'nationalId' && text.isNotEmpty) {
      if (BikeFormConfig.getAgeFromNationalId(text) == null) {
        return 'الرقم القومي أو تاريخ الميلاد غير صحيح';
      }
    }

    return null;
  }

  // تجهيز البيانات للحفظ.
  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final center = centerController.text.trim();
    final governorate = governorateController.text.trim();

    if (center.isEmpty || governorate.isEmpty) {
      AppMessage.warning(
        context,
        'من فضلك اكتب المركز والمحافظة',
      );
      return;
    }

    final values = <String, String>{
      for (final entry in BikeFormConfig.fields.entries)
        entry.key: _isHiddenField(entry)
            ? ''
            : controllers[entry.key]!.text.trim(),
    };

    values['chassisNumber'] =
        values['chassisNumber']!.toUpperCase();

    values['capacity'] =
        BikeFormConfig.normalizeCapacity(
      values['capacity'] ?? '',
    );

    // حفظ المركز والمحافظة في نفس المتغير.
    values['buyerAddress'] = '$center - $governorate';

    Navigator.pop(context, values);
  }


Widget _buildAutocompleteField({
  required String key,
  required String label,
  required List<String> options,
  required String hint,
}) {
  return Autocomplete<String>(
    key: ValueKey('autocomplete_$key'),

    initialValue: TextEditingValue(
      text: controllers[key]!.text,
    ),

    optionsBuilder: (TextEditingValue value) {
      final query = value.text.trim().toLowerCase();

      if (query.isEmpty) {
        return options;
      }

      return options.where(
        (option) => option.toLowerCase().contains(query),
      );
    },

    displayStringForOption: (option) => option,

    onSelected: (selection) {
      final value = key == 'chassisNumber'
          ? selection.toUpperCase()
          : selection;

      controllers[key]!.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(
          offset: value.length,
        ),
        composing: TextRange.empty,
      );
    },

    fieldViewBuilder: (
      context,
      textController,
      focusNode,
      onFieldSubmitted,
    ) {
      return TextFormField(
        controller: textController,
        focusNode: focusNode,
        textDirection: TextDirection.rtl,

        textCapitalization: key == 'chassisNumber'
            ? TextCapitalization.characters
            : TextCapitalization.none,

        inputFormatters: key == 'chassisNumber'
            ? [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) {
                    return newValue.copyWith(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                      composing: TextRange.empty,
                    );
                  },
                ),
              ]
            : [],

        onChanged: (value) {
          controllers[key]!.value = textController.value;
        },

        validator: (value) => _validateField(key, value),

        decoration: InputDecoration(
          labelText:
              '$label${BikeFormConfig.requiredKeys.contains(key) ? ' *' : ''}',
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,

          suffixIcon: IconButton(
            icon: const Icon(
              Icons.arrow_drop_down,
              color: AppTheme.goldLight,
            ),
            onPressed: () {
              focusNode.requestFocus();

              // المسافة تجعل optionsBuilder يعرض جميع الاختيارات.
              textController.value = const TextEditingValue(
                text: ' ',
                selection: TextSelection.collapsed(
                  offset: 1,
                ),
                composing: TextRange.empty,
              );
            },
          ),
        ),
      );
    },

    optionsViewBuilder: (
      context,
      onSelected,
      availableOptions,
    ) {
      return Align(
        alignment: Alignment.topRight,
        child: Material(
          elevation: 6,
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 220,
              maxWidth: 400,
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: availableOptions.length,
              itemBuilder: (context, index) {
                final option = availableOptions.elementAt(index);

                return ListTile(
                  dense: true,
                  selected: false,
                  title: Text(
                    option,
                    textDirection: TextDirection.rtl,
                  ),
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

 
  // حقل المركز والمحافظة.
  Widget _buildAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(
            text: centerController.text,
          ),
          optionsBuilder: (value) {
            final query =
                AreaGovernorates.normalizeName(value.text);

            if (query.isEmpty) {
              return AreaGovernorates.areas;
            }

            return AreaGovernorates.areas.where(
              (center) => AreaGovernorates
                  .normalizeName(center)
                  .contains(query),
            );
          },
          displayStringForOption: (option) => option,
          onSelected: (selection) {
            centerController.text = selection;
            _updateGovernorate(selection);
          },
          fieldViewBuilder: (
            context,
            textEditingController,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              textDirection: TextDirection.rtl,
              onChanged: (value) {
                centerController.text = value;
                _updateGovernorate(value);
              },
              validator: _validateCenter,
              decoration: const InputDecoration(
                labelText: 'المركز *',
                hintText: 'اكتب اسم المركز أو اختر من القائمة',
                border: OutlineInputBorder(),
                isDense: true,
                suffixIcon: Icon(
                  Icons.arrow_drop_down,
                  color: AppTheme.goldLight,
                ),
              ),
            );
          },
          optionsViewBuilder: (
            context,
            onSelected,
            options,
          ) {
            return Align(
              alignment: Alignment.topRight,
              child: Material(
                elevation: 6,
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 220,
                    maxWidth: 400,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);

                      return ListTile(
                        dense: true,
                        title: Text(
                          option,
                          textDirection: TextDirection.rtl,
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: governorateController,
          textDirection: TextDirection.rtl,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'المحافظة',
            hintText: 'اكتب المحافظة أو اتركها تُحدد تلقائياً',
            border: OutlineInputBorder(),
            isDense: true,
            suffixIcon: Icon(
              Icons.location_city,
              color: AppTheme.goldLight,
            ),
          ),
        ),
      ],
    );
  }

  // تحذير الولاية أو الوصاية.
  Widget _buildAgeWarning() {
    if (!needsGuardianship) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.orange.withOpacity(0.6),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 22,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'يرجى إضافة الولاية أو الوصاية لأن المشتري أقل من 21 عامًا.',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء الحقول.
  Widget _buildField(MapEntry<String, String> entry) {
    final key = entry.key;
    final label = entry.value;

    if (key == 'buyerAddress') {
      return _buildAddressFields();
    }

    if (key == 'bikeType') {
      return _buildAutocompleteField(
        key: key,
        label: label,
        options: BikeFormConfig.bikeTypes,
        hint: 'اكتب اسم النوع أو اختر من الاقتراحات',
      );
    }

    if (key == 'bikeShape') {
      return _buildAutocompleteField(
        key: key,
        label: label,
        options: BikeFormConfig.bikeShapes,
        hint: 'اختر شكل الدراجة',
      );
    }

    if (key == 'chassisNumber') {
      if (loadingPrefixes) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildAutocompleteField(
              key: key,
              label: label,
              options: chassisPrefixes,
              hint: 'اكتب رقم الشاسيه أو اختر بادئة',
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'سحب رقم الشاسيه من صورة',
            onPressed: _scanningMachineField
                ? null
                : () => _showMachineSourceSheet('chassisNumber'),
            icon: _scanningMachineField
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.document_scanner_outlined,
                    color: AppTheme.goldLight,
                  ),
          ),
        ],
      );
    }

    if (key == 'nationalId') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: ValueKey(key),
            controller: controllers[key],
            validator: (value) =>
                _validateField(key, value),
            keyboardType: TextInputType.number,
            inputFormatters: [
              NationalIdInputFormatter(),
            ],
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              labelText:
                  '$label${BikeFormConfig.requiredKeys.contains(key) ? ' *' : ''}',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          _buildAgeWarning(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            key: ValueKey(key),
            controller: controllers[key],
            validator: (value) => _validateField(key, value),
            keyboardType: key == 'capacity'
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                  )
                : TextInputType.text,
            maxLines: key == 'notes' || key == 'buyerAddress'
                ? 2
                : 1,
            decoration: InputDecoration(
              labelText:
                  '$label${BikeFormConfig.requiredKeys.contains(key) ? ' *' : ''}',
              border: const OutlineInputBorder(),
              isDense: true,
              helperText: key == 'capacity'
                  ? 'تُحفظ الوحدة تلقائيًا بصيغة سم3'
                  : key == 'model'
                      ? 'تُستخرج سنة الموديل من رقم الشاسيه'
                      : null,
            ),
          ),
        ),
        if (key == 'engineNumber') ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'سحب رقم الموتور من صورة',
            onPressed: _scanningMachineField
                ? null
                : () => _showMachineSourceSheet('engineNumber'),
            icon: _scanningMachineField
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.document_scanner_outlined,
                    color: AppTheme.goldLight,
                  ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    final dialogWidth = (screenSize.width * 0.92)
        .clamp(0.0, 680.0)
        .toDouble();

    final maxDialogHeight = screenSize.height * 0.70;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppTheme.surface,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 20,
        ),
        title: Text(
          isEditing
              ? 'تعديل بيانات الموتوسيكل'
              : 'إضافة موتوسيكل جديد',
          style: const TextStyle(
            color: AppTheme.goldBright,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxDialogHeight,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context)
                          .viewPadding
                          .bottom +
                      30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openImageExtractor,
                      icon: const Icon(
                        Icons.document_scanner_outlined,
                      ),
                      label: const Text(
                        'استخراج البيانات من الصور',
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns =
                            constraints.maxWidth > 500;

                        final entries =
                            BikeFormConfig.fields.entries
                                .where(
                                  (entry) =>
                                      !_isHiddenField(entry),
                                )
                                .toList();

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final entry in entries)
                              SizedBox(
                                width: twoColumns
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth,
                                child: _buildField(entry),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: _submit,
            icon: Icon(
              isEditing
                  ? Icons.save_outlined
                  : Icons.add_rounded,
            ),
            label: Text(
              isEditing
                  ? 'حفظ التعديلات'
                  : 'إضافة السجل',
            ),
          ),
        ],
      ),
    );
  }
}

// Formatter الرقم القومي.
class NationalIdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();

    int digitCount = 0;
    int selectionOffset = 0;

    for (int i = 0; i < newValue.text.length; i++) {
      final char = newValue.text[i];

      if (!RegExp(r'[0-9-]').hasMatch(char)) {
        continue;
      }

      if (RegExp(r'[0-9]').hasMatch(char)) {
        if (digitCount >= 14) continue;
        digitCount++;
      }

      buffer.write(char);

      if (i < newValue.selection.extentOffset) {
        selectionOffset = buffer.length;
      }
    }

    final result = buffer.toString();

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(
        offset: selectionOffset.clamp(0, result.length),
      ),
      composing: TextRange.empty,
    );
  }
}