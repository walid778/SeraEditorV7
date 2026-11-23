import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seraeditor/screens/multibox_cropper_page.dart';

import 'package:seraeditor/services/card_ocr_service.dart';
import 'package:seraeditor/services/machine_ocr_service.dart';

import 'package:seraeditor/services/nationalid_service.dart';
import 'package:seraeditor/utils/app_theme.dart';

class ImageDataExtractorPage extends StatefulWidget {
  const ImageDataExtractorPage({super.key});

  @override
  State<ImageDataExtractorPage> createState() =>
      _ImageDataExtractorPageState();
}

class _ImageDataExtractorPageState
    extends State<ImageDataExtractorPage> {
  final ImagePicker _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _chassisController = TextEditingController();
  final _engineController = TextEditingController();

  final Map<String, Uint8List> _imageBytes = {};
  final Map<String, String> _rawTexts = {};

  List<String> _chassisCandidates = [];
  List<String> _engineCandidates = [];

  bool _busy = false;
  bool _requiresCardReview = false;

  String? _processingType;

  String _ocrStatus = 'أنظمة OCR جاهزة للاستخدام';

  bool get _hasData =>
      _nameController.text.trim().isNotEmpty ||
      _addressController.text.trim().isNotEmpty ||
      _nationalIdController.text.trim().isNotEmpty ||
      _chassisController.text.trim().isNotEmpty ||
      _engineController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    _nameController.addListener(_refresh);
    _addressController.addListener(_refresh);
    _nationalIdController.addListener(_refresh);
    _chassisController.addListener(_refresh);
    _engineController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _nationalIdController.dispose();
    _chassisController.dispose();
    _engineController.dispose();

    if (!kIsWeb) {
      NationalIdMlKitService.dispose();
    }

    super.dispose();
  }

  // =========================================================
  // USE EXTRACTED DATA
  // =========================================================

  void _useExtractedData() {
    Navigator.pop(
      context,
      <String, String>{
        'buyerName': _nameController.text.trim(),
        'buyerAddress': _addressController.text.trim(),
        'nationalId': CardOcrService.normalizeDigits(
          _nationalIdController.text.trim(),
        ),
        'chassisNumber':
            _chassisController.text.trim().toUpperCase(),
        'engineNumber':
            _engineController.text.trim().toUpperCase(),
      },
    );
  }

  // =========================================================
  // HELPER: READ CROPPED BYTES WITH TESSERACT
  // =========================================================

  Future<String> _readCroppedBytes(
    Uint8List bytes, {
    String psm = '6',
    String filePrefix = 'crop',
  }) async {
    if (kIsWeb) {
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      return CardOcrService.readImage(dataUrl, pageSegmentationMode: psm);
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      return CardOcrService.readImage(file.path, pageSegmentationMode: psm);
    }
  }

  // =========================================================
  // PICK AND PROCESS IMAGE
  // =========================================================

  Future<void> _pickImage(
    String type,
    ImageSource source,
  ) async {
    if (_busy) return;

    // ML Kit is not supported on Flutter Web.
    if (kIsWeb && type != 'card') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'قراءة الشاسيه والموتور باستخدام Google ML Kit '
            'تتطلب تشغيل التطبيق على Android أو iOS.',
          ),
        ),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 3000,
      );

      if (image == null || !mounted) return;

      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) return;

      // =====================================================
      // هنا مكان المستطيلات الثلاثة للبطاقة (الاسم - العنوان - الرقم القومي)
      // =====================================================
      if (type == 'card') {
        final cropResult = await Navigator.push<MultiBoxCropResult>(
          context,
          MaterialPageRoute(
            builder: (_) => MultiBoxCropperPage(imageBytes: bytes),
          ),
        );

        if (cropResult == null || !mounted) return;

        setState(() {
          _busy = true;
          _processingType = 'card';
          _imageBytes['card'] = bytes;
          _rawTexts.remove('card');
          _requiresCardReview = false;
          _ocrStatus = 'جارٍ قراءة الاسم والعنوان والرقم القومي من المستطيلات...';
        });

        String rawCombined = '';
        String nameVal = '';
        String addressVal = '';
        String idVal = '';

        if (cropResult.nameBytes != null) {
          final rawName = await _readCroppedBytes(
            cropResult.nameBytes!,
            psm: '6',
            filePrefix: 'name',
          );
          rawCombined += '[الاسم]\n$rawName\n---\n';
          nameVal = CardOcrService.extractNameFromCrop(rawName);
        }

        if (cropResult.addressBytes != null) {
          final rawAddress = await _readCroppedBytes(
            cropResult.addressBytes!,
            psm: '6',
            filePrefix: 'address',
          );
          rawCombined += '[العنوان]\n$rawAddress\n---\n';
          addressVal = CardOcrService.extractAddressFromCrop(rawAddress);
        }

        // قراءة مستطيل الرقم القومي فقط باستخدام Google ML Kit على الموبايل
        if (cropResult.nationalIdBytes != null) {
          String rawId = '';

          if (!kIsWeb) {
            final tempDir = await getTemporaryDirectory();
            final idFile = File(
              '${tempDir.path}/national_id_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await idFile.writeAsBytes(cropResult.nationalIdBytes!, flush: true);
            rawId = await NationalIdMlKitService.readNationalIdFromFile(
              idFile.path,
            );
          } else {
            rawId = await _readCroppedBytes(
              cropResult.nationalIdBytes!,
              psm: '7',
              filePrefix: 'national_id',
            );
          }

          rawCombined += '[الرقم القومي]\n$rawId';
          idVal = CardOcrService.extractNationalIdFromCrop(rawId);
        }

        if (!mounted) return;

        setState(() {
          _rawTexts['card'] = rawCombined.trim();
          _nameController.text = nameVal;
          _addressController.text = addressVal;
          _nationalIdController.text = CardOcrService.normalizeDigits(idVal);
          _requiresCardReview =
              nameVal.isEmpty || addressVal.isEmpty || idVal.length != 14;
          _ocrStatus = 'تم تحليل المستطيلات بنجاح';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استخراج البيانات من المستطيلات. راجع النتائج.'),
          ),
        );
        return;
      }

      // =====================================================
      // باقي الأنواع (الشاسيه والموتور) كما هي
      // =====================================================
      setState(() {
        _busy = true;
        _processingType = type;

        _imageBytes[type] = bytes;
        _rawTexts.remove(type);

        if (type == 'chassis') {
          _chassisCandidates.clear();
          _chassisController.clear();
        } else if (type == 'engine') {
          _engineCandidates.clear();
          _engineController.clear();
        }

        _ocrStatus = 'جارٍ قراءة الرقم باستخدام Google ML Kit...';
      });

      final String text = await MachineOcrService.readImage(
        image.path,
      );

      if (!mounted) return;

      debugPrint('========== OCR RESULT ==========');
      debugPrint('TYPE: $type');
      debugPrint('ENGINE: GOOGLE ML KIT');
      debugPrint('PLATFORM: ${kIsWeb ? 'WEB' : 'NATIVE'}');
      debugPrint(text);
      debugPrint('================================');

      setState(() {
        _rawTexts[type] = text;
      });

      switch (type) {
        case 'chassis':
          _processChassis(text);
          break;

        case 'engine':
          _processEngine(text);
          break;
      }

      if (!mounted) return;

      setState(() {
        _ocrStatus = 'تم تحليل الصورة بنجاح';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == 'chassis'
                ? 'تم تحليل صورة الشاسيه باستخدام Google ML Kit.'
                : 'تم تحليل صورة الموتور باستخدام Google ML Kit.',
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('OCR ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _ocrStatus = 'حدث خطأ أثناء قراءة الصورة';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذرت قراءة الصورة:\n$e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _processingType = null;
        });
      }
    }
  }

  // =========================================================
  // PROCESS CHASSIS - GOOGLE ML KIT
  // =========================================================

  void _processChassis(String text) {
    final starred =
        MachineOcrService.extractChassisFromStarredText(text);

    final candidates =
        MachineOcrService.extractCandidates(text);

    final uniqueCandidates = candidates.toSet().toList();

    final vinCandidates = uniqueCandidates
        .where(
          (candidate) =>
              RegExp(r'^[A-HJ-NPR-Z0-9]{17}$')
                  .hasMatch(candidate),
        )
        .toList();

    final bestCandidate =
        MachineOcrService.findBestChassisCandidate(text);

    final selected = starred.isNotEmpty
        ? starred
        : vinCandidates.isNotEmpty
            ? vinCandidates.first
            : bestCandidate;

    setState(() {
      _chassisCandidates = uniqueCandidates;

      if (selected.isNotEmpty) {
        _chassisController.text = selected.toUpperCase();

        _chassisCandidates.remove(selected);
        _chassisCandidates.insert(0, selected);
      }
    });
  }

  // =========================================================
  // PROCESS ENGINE - GOOGLE ML KIT
  // =========================================================

  void _processEngine(String text) {
    final candidates =
        MachineOcrService.extractCandidates(text);

    final uniqueCandidates = candidates.toSet().toList();

    final serialNumbers = uniqueCandidates
        .where(
          (candidate) =>
              RegExp(r'^\d{8,15}$').hasMatch(candidate),
        )
        .toList();

    final alphanumeric = uniqueCandidates.where((candidate) {
      final digits =
          RegExp(r'\d').allMatches(candidate).length;

      final letters =
          RegExp(r'[A-Za-z]').allMatches(candidate).length;

      return candidate.length >= 6 &&
          candidate.length <= 15 &&
          digits >= 3 &&
          letters >= 1;
    }).toList();

    String selected = '';

    if (serialNumbers.length == 1) {
      selected = serialNumbers.first;
    } else if (serialNumbers.isNotEmpty) {
      serialNumbers.sort(
        (a, b) => b.length.compareTo(a.length),
      );

      selected = serialNumbers.first;
    } else if (alphanumeric.length == 1) {
      selected = alphanumeric.first;
    } else if (alphanumeric.isNotEmpty) {
      alphanumeric.sort(
        (a, b) => b.length.compareTo(a.length),
      );

      selected = alphanumeric.first;
    } else if (uniqueCandidates.length == 1) {
      selected = uniqueCandidates.first;
    }

    setState(() {
      _engineCandidates = uniqueCandidates;

      if (selected.isNotEmpty) {
        _engineController.text = selected.toUpperCase();

        _engineCandidates.remove(selected);
        _engineCandidates.insert(0, selected);
      }
    });
  }

  // =========================================================
  // IMAGE OPTIONS
  // =========================================================

  Future<void> _showImageOptions(String type) async {
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
                    title: const Text(
                      'التقاط صورة بالكاميرا',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickImage(type, ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_rounded,
                      color: AppTheme.goldLight,
                    ),
                    title: const Text(
                      'اختيار صورة من المعرض',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickImage(type, ImageSource.gallery);
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

  // =========================================================
  // IMAGE CARD
  // =========================================================

  Widget _buildImageCard({
    required String type,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final bytes = _imageBytes[type];

    final processing =
        _busy && _processingType == type;

    final unsupportedOnWeb = kIsWeb && type != 'card';

    return Card(
      color: AppTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(
          color: AppTheme.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.button.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.goldLight,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.goldBright,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (bytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  bytes,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text('تعذر عرض الصورة'),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy || unsupportedOnWeb
                  ? null
                  : () => _showImageOptions(type),
              icon: processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      unsupportedOnWeb
                          ? Icons.phonelink_erase
                          : Icons.add_a_photo_outlined,
                    ),
              label: Text(
                processing
                    ? 'جارٍ قراءة الصورة...'
                    : unsupportedOnWeb
                        ? 'يتطلب Android أو iOS'
                        : bytes == null
                            ? 'اختيار صورة وبدء القراءة'
                            : 'تغيير الصورة وإعادة القراءة',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TEXT FIELDS
  // =========================================================

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        textDirection: TextDirection.rtl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          color: AppTheme.text,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: AppTheme.goldLight,
          ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  // =========================================================
  // CANDIDATES
  // =========================================================

  Widget _buildCandidates(
    List<String> candidates,
    TextEditingController controller,
  ) {
    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: candidates.map((candidate) {
          return ActionChip(
            label: Text(candidate),
            onPressed: () {
              controller.text = candidate.toUpperCase();
            },
          );
        }).toList(),
      ),
    );
  }

  // =========================================================
  // RAW OCR TEXT
  // =========================================================

  Widget _buildRawText(String type) {
    final text = _rawTexts[type];

    if (text == null || text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: const Text(
        'عرض النص المقروء من الصورة',
        style: TextStyle(
          color: AppTheme.goldLight,
          fontSize: 13,
        ),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            text,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: AppTheme.text,
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // REVIEW WARNING
  // =========================================================

  Widget _buildReviewWarning() {
    if (!_requiresCardReview) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.orange.withOpacity(.4),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'يرجى مراجعة بيانات البطاقة، '
              'خصوصًا الرقم القومي، قبل الاستخدام.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // OCR STATUS
  // =========================================================

  Widget _buildOcrStatus() {
    final color = _busy
        ? AppTheme.goldLight
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(.35),
        ),
      ),
      child: Row(
        children: [
          if (_busy)
            SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(
              Icons.document_scanner_outlined,
              color: color,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _ocrStatus,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CLEAR RESULTS
  // =========================================================

  void _clearResults() {
    if (_busy) return;

    setState(() {
      _nameController.clear();
      _addressController.clear();
      _nationalIdController.clear();
      _chassisController.clear();
      _engineController.clear();

      _imageBytes.clear();
      _rawTexts.clear();

      _chassisCandidates.clear();
      _engineCandidates.clear();

      _requiresCardReview = false;

      _ocrStatus = 'أنظمة OCR جاهزة للاستخدام';
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Material(
            color: AppTheme.background,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 850,
                ),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(context).viewPadding.bottom + 110,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOcrStatus(),

                      const Text(
                        'استخراج البيانات من الصور',
                        style: TextStyle(
                          color: AppTheme.goldBright,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'يمكنك مراجعة وتعديل النتائج قبل استخدامها.',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ID CARD
                      _buildImageCard(
                        type: 'card',
                        icon: Icons.credit_card,
                        title: 'البطاقة الشخصية',
                        description:
                            'استخراج الاسم والعنوان والرقم القومي',
                      ),

                      _buildRawText('card'),

                      const SizedBox(height: 12),

                      // CHASSIS
                      _buildImageCard(
                        type: 'chassis',
                        icon: Icons.two_wheeler,
                        title: 'رقم الشاسيه',
                        description:
                            'قراءة رقم الشاسيه',
                      ),

                      _buildRawText('chassis'),

                      const SizedBox(height: 12),

                      // ENGINE
                      _buildImageCard(
                        type: 'engine',
                        icon: Icons.settings,
                        title: 'رقم الموتور',
                        description:
                            'Google ML Kit - قراءة رقم الموتور',
                      ),

                      _buildRawText('engine'),

                      const SizedBox(height: 22),

                      const Text(
                        'البيانات المستخرجة',
                        style: TextStyle(
                          color: AppTheme.goldBright,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),

                      const SizedBox(height: 14),

                      _buildReviewWarning(),

                      _buildTextField(
                        label: 'اسم المشتري',
                        controller: _nameController,
                      ),

                      _buildTextField(
                        label: 'عنوان المشتري',
                        controller: _addressController,
                        maxLines: 3,
                      ),

                      _buildTextField(
                        label: 'الرقم القومي',
                        controller: _nationalIdController,
                        keyboardType: TextInputType.number,
                      ),

                      _buildTextField(
                        label: 'رقم الشاسيه',
                        controller: _chassisController,
                      ),

                      _buildCandidates(
                        _chassisCandidates,
                        _chassisController,
                      ),

                      _buildTextField(
                        label: 'رقم الموتور',
                        controller: _engineController,
                      ),

                      _buildCandidates(
                        _engineCandidates,
                        _engineController,
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton.icon(
                        onPressed: _busy || !_hasData
                            ? null
                            : _useExtractedData,
                        icon: const Icon(
                          Icons.check_circle_outline,
                        ),
                        label: const Text(
                          'استخدام البيانات في نموذج الموتوسيكل',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.button,
                          foregroundColor: AppTheme.goldBright,
                          minimumSize: const Size(
                            double.infinity,
                            50,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      OutlinedButton.icon(
                        onPressed: _busy ? null : _clearResults,
                        icon: const Icon(
                          Icons.refresh_rounded,
                        ),
                        label: const Text(
                          'مسح النتائج والبدء من جديد',
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}