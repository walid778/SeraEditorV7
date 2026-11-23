import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class MultiBoxCropResult {
  final Uint8List? nameBytes;
  final Uint8List? addressBytes;
  final Uint8List? nationalIdBytes;

  MultiBoxCropResult({
    this.nameBytes,
    this.addressBytes,
    this.nationalIdBytes,
  });
}

class MultiBoxCropperPage extends StatefulWidget {
  final Uint8List imageBytes;

  const MultiBoxCropperPage({
    super.key,
    required this.imageBytes,
  });

  @override
  State<MultiBoxCropperPage> createState() => _MultiBoxCropperPageState();
}

class _MultiBoxCropperPageState extends State<MultiBoxCropperPage> {
  static const double _canvasHeight = 420.0;
  static const double _minWidth = 70.0;
  static const double _minHeight = 32.0;

  final GlobalKey _imageKey = GlobalKey();
  ui.Image? _decodedUiImage;
  bool _isCropping = false;

  // الاسم أكبر - العنوان أصغر - الرقم القومي أطول
  Rect nameRect = const Rect.fromLTWH(130, 100, 240, 85);
  Rect addressRect = const Rect.fromLTWH(175, 195, 175, 55);
  Rect nationalIdRect = const Rect.fromLTWH(75, 290, 295, 52);

  @override
  void initState() {
    super.initState();
    _loadUiImage();
  }

  Future<void> _loadUiImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _decodedUiImage = frame.image;
      });
    }
  }

  Future<Uint8List?> _cropRectFromImage(
    Rect boxOnScreen, {
    bool isNationalId = false,
  }) async {
    if (_decodedUiImage == null) return null;

    final renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final displaySize = renderBox.size;
    final imgWidth = _decodedUiImage!.width.toDouble();
    final imgHeight = _decodedUiImage!.height.toDouble();

    final scaleX = imgWidth / displaySize.width;
    final scaleY = imgHeight / displaySize.height;

    final int cropX = (boxOnScreen.left * scaleX)
        .round()
        .clamp(0, _decodedUiImage!.width - 1);
    final int cropY = (boxOnScreen.top * scaleY)
        .round()
        .clamp(0, _decodedUiImage!.height - 1);
    final int cropW = (boxOnScreen.width * scaleX)
        .round()
        .clamp(1, _decodedUiImage!.width - cropX);
    final int cropH = (boxOnScreen.height * scaleY)
        .round()
        .clamp(1, _decodedUiImage!.height - cropY);

    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) return null;

    var cropped = img.copyCrop(
      decoded,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    if (isNationalId) {
      cropped = img.copyResize(
        cropped,
        width: (cropped.width * 1.5).round(),
      );
      cropped = img.grayscale(cropped);
      cropped = img.contrast(cropped, contrast: 150);
    } else {
      cropped = img.contrast(cropped, contrast: 120);
    }

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  Future<void> _confirmAndCropAll() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);

    try {
      final nameCropped = await _cropRectFromImage(nameRect);
      final addressCropped = await _cropRectFromImage(addressRect);
      final idCropped = await _cropRectFromImage(
        nationalIdRect,
        isNationalId: true,
      );

      if (!mounted) return;
      Navigator.pop(
        context,
        MultiBoxCropResult(
          nameBytes: nameCropped,
          addressBytes: addressCropped,
          nationalIdBytes: idCropped,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  Widget _buildResizableDraggableBox({
    required String label,
    required Color color,
    required Rect rect,
    required double canvasWidth,
    required ValueChanged<Rect> onChanged,
  }) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Stack(
        children: [
          // سحب المستطيل بالكامل
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                final maxLeft = (canvasWidth - rect.width).clamp(0.0, canvasWidth);
                final maxTop = (_canvasHeight - rect.height).clamp(0.0, _canvasHeight);

                final nextLeft = (rect.left + details.delta.dx).clamp(0.0, maxLeft);
                final nextTop = (rect.top + details.delta.dy).clamp(0.0, maxTop);

                onChanged(
                  Rect.fromLTWH(
                    nextLeft,
                    nextTop,
                    rect.width,
                    rect.height,
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  border: Border.all(color: color, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: color,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // مقبض التكبير والتصغير في الزاوية السفلية اليسرى
          Positioned(
            left: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                // في RTL: تحريك لليسار (-dx) يزيد العرض، ولليمين (+dx) يقلله
                final maxW = (canvasWidth - rect.left).clamp(_minWidth, canvasWidth);
                final maxH = (_canvasHeight - rect.top).clamp(_minHeight, _canvasHeight);

                final nextWidth = (rect.width - details.delta.dx).clamp(_minWidth, maxW);
                final nextHeight = (rect.height + details.delta.dy).clamp(_minHeight, maxH);

                onChanged(
                  Rect.fromLTWH(
                    rect.left,
                    rect.top,
                    nextWidth,
                    nextHeight,
                  ),
                );
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: const Icon(
                  Icons.open_in_full,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double canvasWidth = MediaQuery.of(context).size.width;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحديد الاسم والعنوان والرقم القومي'),
          actions: [
            TextButton(
              onPressed: _isCropping ? null : _confirmAndCropAll,
              child: _isCropping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'استخراج',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'اسحب المستطيل لتحريكه، واسحب علامة ⤢ بالزاوية لتكبيره أو تصغيره',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                SizedBox(
                  key: _imageKey,
                  width: canvasWidth,
                  height: _canvasHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.fill,
                        ),
                      ),
                      _buildResizableDraggableBox(
                        label: 'الاسم',
                        color: Colors.green,
                        rect: nameRect,
                        canvasWidth: canvasWidth,
                        onChanged: (r) => setState(() => nameRect = r),
                      ),
                      _buildResizableDraggableBox(
                        label: 'العنوان',
                        color: Colors.blue,
                        rect: addressRect,
                        canvasWidth: canvasWidth,
                        onChanged: (r) => setState(() => addressRect = r),
                      ),
                      _buildResizableDraggableBox(
                        label: 'الرقم القومي',
                        color: Colors.red,
                        rect: nationalIdRect,
                        canvasWidth: canvasWidth,
                        onChanged: (r) => setState(() => nationalIdRect = r),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}