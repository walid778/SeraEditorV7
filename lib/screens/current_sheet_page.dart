
import 'package:flutter/material.dart';
import 'package:seraeditor/database/app_database.dart';
import 'package:seraeditor/services/excel_export_service.dart';
import 'package:seraeditor/utils/app_card.dart';
import 'package:seraeditor/utils/app_message.dart';
import 'package:seraeditor/utils/app_theme.dart';
import 'package:seraeditor/widgets/bike_record_form_dialog.dart';
import 'package:seraeditor/utils/app_buttons.dart';

class CurrentSheetPage extends StatefulWidget {
  final VoidCallback onChanged;

  const CurrentSheetPage({
    super.key,
    required this.onChanged,
  });

  @override
  State<CurrentSheetPage> createState() => _CurrentSheetPageState();
}

class _CurrentSheetPageState extends State<CurrentSheetPage> {
  final traderController = TextEditingController();

  bool busy = false;
  Future<Map<String, Object?>>? sheetFuture;
  Future<List<Map<String, Object?>>>? itemsFuture;

  @override
  void initState() {
    super.initState();
    sheetFuture = AppDatabase.instance.getCurrentSheet();
    itemsFuture = AppDatabase.instance.getCurrentSheetItems();
  }

  @override
  void dispose() {
    traderController.dispose();
    super.dispose();
  }

  void _reload() {
    sheetFuture = AppDatabase.instance.getCurrentSheet();
    itemsFuture = AppDatabase.instance.getCurrentSheetItems();

    if (mounted) setState(() {});
  }

Future<void> _addRecord() async {
  if (busy) return;

  try {
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BikeRecordFormDialog(),
    );

    if (result == null || !mounted) return;

    setState(() => busy = true);

    await AppDatabase.instance.addBikeToCurrentSheet(result);

    if (!mounted) return;

    _reload();
    widget.onChanged();

    AppMessage.success(
      context,
      'تمت إضافة السجل للشيت الحالي.',
    );
  } catch (e) {
    if (mounted) {
      AppMessage.error(
        context,
        'تعذرت إضافة السجل: $e',
      );
    }
  } finally {
    if (mounted) {
      setState(() => busy = false);
    }
  }
}

  Future<void> _exportCurrent() async {
    if (busy) return;

    setState(() => busy = true);

    try {
      final sheet = await AppDatabase.instance.getCurrentSheet();
      final items =
          await AppDatabase.instance.getCurrentSheetItems();

      final traderName = traderController.text.trim().isNotEmpty
          ? traderController.text.trim()
          : '${sheet['traderName'] ?? ''}';

      if (items.isEmpty) {
        throw StateError(
          'الشيت فاضي. أضف سجلًا واحدًا على الأقل.',
        );
      }

      await AppDatabase.instance.updateCurrentTraderName(traderName);

      final path = await ExcelExportService.instance.exportSheet(
        sheetId: sheet['id'] as int,
        records: items,
        traderName: traderName,
        isHistory: false,
      );

      if (path == null) {
        if (mounted) {
           AppMessage.info(context, 'تم إلغاء التصدير. بيانات الشيت لم تتغير.');
        }
        return;
      }

      await AppDatabase.instance.completeAndStartNextSheet(
        sheetId: sheet['id'] as int,
        exportedPath: path,
        traderName: traderName,
      );

      traderController.clear();
      _reload();
      widget.onChanged();

      if (mounted) {
         AppMessage.success(
  context,
  'تم حفظ الشيت وتصديره. الشيت التالي أصبح جاهزًا.',
);
      }
    } catch (e) {
      if (mounted) {
       AppMessage.error(
  context,
  'لم يتم إنهاء الشيت، وبياناته ما زالت محفوظة. $e',
);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

Future<void> _remove(Map<String, Object?> item) async {
  if (busy) return;

  final id = item['itemId'];
  if (id is! int) return;

  try {
    await AppDatabase.instance.removeCurrentSheetItem(id);

    if (!mounted) return;

    _reload();
    widget.onChanged();
  } catch (e) {
    if (mounted) {
      AppMessage.error(
        context,
        'تعذر حذف السجل: $e',
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>>(
      future: sheetFuture,
      builder: (context, sheetSnapshot) {
        final sheet = sheetSnapshot.data ?? {};

        if (traderController.text.isEmpty &&
            '${sheet['traderName'] ?? ''}'.isNotEmpty) {
          traderController.text = '${sheet['traderName']}';
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_document,
                          color: AppTheme.goldLight,
                          size: 25,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'الشيت الحالي ${sheet['id'] == null ? '' : '#${sheet['id']}'}',
                            style: const TextStyle(
                              color: AppTheme.goldBright,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                     AppButtons.primary(
  label: 'إضافة موتوسيكل',
  icon: Icons.add_rounded,
  onPressed: busy ? null : _addRecord,
  loading: busy,
),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: traderController,
                      onChanged: (value) => AppDatabase.instance
                          .updateCurrentTraderName(value),
                      decoration: const InputDecoration(
                        labelText: 'اسم التاجر للشيت (اختياري)',
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'عدد السجلات: ${sheet['recordCount'] ?? 0}',
                            style: const TextStyle(
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ),
                       AppButtons.primary(
  label: busy ? 'جارٍ التصدير...' : 'حفظ وتصدير',
  icon: Icons.file_download_outlined,
  onPressed: busy ? null : _exportCurrent,
  loading: busy,
),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: itemsFuture,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? [];

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('تعذر تحميل سجلات الشيت الحالي.'),
                    );
                  }

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'الشيت الحالي فاضي. اضغط «إضافة موتوسيكل» للبدء.',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppTheme.button.withOpacity(.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.two_wheeler_rounded,
                                color: AppTheme.goldLight,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['buyerName'] ?? 'بدون اسم'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'شاسيه: ${item['chassisNumber'] ?? '-'}  •  موتور: ${item['engineNumber'] ?? '-'}',
                                    style: const TextStyle(
                                      color: AppTheme.secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'كود العميل: ${item['customerCode'] ?? '-'}  •  الموديل: ${item['model'] ?? '-'}',
                                    style: const TextStyle(
                                      color: AppTheme.secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                     AppButtons.dangerIcon(
  tooltip: 'حذف من الشيت الحالي',
  onPressed: busy ? null : () => _remove(item),
),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

}
