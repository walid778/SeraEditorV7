import 'package:flutter/material.dart';
import 'package:seraeditor/database/app_database.dart';
import 'package:seraeditor/services/excel_export_service.dart';
import 'package:seraeditor/utils/app_card.dart';
import 'package:seraeditor/utils/app_message.dart';
import 'package:seraeditor/utils/app_theme.dart';
import 'package:seraeditor/widgets/bike_record_form_dialog.dart';

class EditHistoricalSheetPage extends StatefulWidget {
  final Map<String, Object?> sheet;

  const EditHistoricalSheetPage({
    super.key,
    required this.sheet,
  });

  @override
  State<EditHistoricalSheetPage> createState() =>
      _EditHistoricalSheetPageState();
}

class _EditHistoricalSheetPageState
    extends State<EditHistoricalSheetPage> {
  late final int sheetId =
      (widget.sheet['id'] as num).toInt();

  late final TextEditingController traderController =
      TextEditingController(
    text: '${widget.sheet['traderName'] ?? ''}',
  );

  late Future<List<Map<String, Object?>>> future =
      AppDatabase.instance.getSheetSnapshots(sheetId);

  bool busy = false;


  void _reload() {
    if (!mounted) return;

    setState(() {
      future = AppDatabase.instance.getSheetSnapshots(sheetId);
    });
  }

Future<Map<String, String>?> _showRecordForm({
  Map<String, Object?>? record,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BikeRecordFormDialog(
      record: record,
    ),
  );
}
  
  
  Future<void> _addRecord() async {
    if (busy) return;

    try {
      final values = await _showRecordForm();

      if (values == null || !mounted) return;

      setState(() => busy = true);

      // يجب أن تضيف هذه الدالة السجل إلى قاعدة البيانات
      // مع ربطه بالشيت التاريخي الحالي.
      await AppDatabase.instance.addSheetItem(
        sheetId: sheetId,
        fields: values,
      );

      if (!mounted) return;

      _reload();
      AppMessage.success(context, 'تمت إضافة الموتوسيكل إلى الشيت.');
    } catch (e) {
      if (mounted) {
        AppMessage.error(context, 'تعذرت إضافة السجل: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }


  Future<void> _editRecord(
    Map<String, Object?> record,
  ) async {
    if (busy) return;

    try {
      final values = await _showRecordForm(record: record);

      if (values == null || !mounted) return;

      final itemIdValue = record['itemId'];

      if (itemIdValue is! num) {
        throw StateError('رقم السجل غير موجود.');
      }

      setState(() => busy = true);

      await AppDatabase.instance.updateSheetItem(
        sheetId: sheetId,
        itemId: itemIdValue.toInt(),
        fields: values,
      );

      if (!mounted) return;

      _reload();
      AppMessage.success(context, 'تم حفظ تعديلات السجل.');
    } catch (e) {
      if (mounted) {
        AppMessage.error(context, 'تعذر تعديل السجل: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteRecord(
    Map<String, Object?> record,
  ) async {
    if (busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('حذف السجل'),
        content: const Text(
          'هل تريد حذف هذا السجل من الشيت القديم؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final itemIdValue = record['itemId'];

      if (itemIdValue is! num) {
        throw StateError('رقم السجل غير موجود.');
      }

      setState(() => busy = true);

      await AppDatabase.instance.removeSheetItem(
        sheetId: sheetId,
        itemId: itemIdValue.toInt(),
      );

      if (!mounted) return;

      _reload();
      AppMessage.success(context, 'تم حذف السجل.');
    } catch (e) {
      if (mounted) {
        AppMessage.error(context, 'تعذر حذف السجل: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export() async {
    if (busy) return;

    setState(() => busy = true);

    try {
      final traderName = traderController.text.trim();

      if (traderName.isEmpty) {
        throw StateError('من فضلك أدخل اسم التاجر.');
      }

      final records =
          await AppDatabase.instance.getSheetSnapshots(sheetId);

      if (records.isEmpty) {
        throw StateError('لا يمكن تصدير شيت فارغ.');
      }

      final path = await ExcelExportService.instance.exportSheet(
        sheetId: sheetId,
        records: records,
        traderName: traderName,
        isHistory: true,
      );

      if (path == null || !mounted) return;

      await AppDatabase.instance.updateHistoricalSheet(
        sheetId: sheetId,
        traderName: traderName,
        exportedPath: path,
      );

      if (!mounted) return;

      AppMessage.success(
        context,
        'تم حفظ الشيت وتصديره بالتعديلات الجديدة.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppMessage.error(context, 'تعذر تصدير الشيت: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    traderController.dispose();
    super.dispose();
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.background,
    appBar: AppBar(
      title: Text(
        'تعديل ${widget.sheet['title'] ?? 'الشيت القديم'}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppTheme.background,
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          final horizontalPadding = isDesktop ? 24.0 : 12.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: traderController,
                            decoration: const InputDecoration(
                              labelText: 'اسم التاجر',
                              prefixIcon: Icon(
                                Icons.store_outlined,
                                color: AppTheme.goldLight,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        busy ? null : _addRecord,
                                    icon: const Icon(Icons.add),
                                    label: const Text(
                                      'إضافة موتوسيكل',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: busy ? null : _export,
                                    icon: busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.file_download_outlined,
                                          ),
                                    label: Text(
                                      busy
                                          ? 'جارٍ التنفيذ...'
                                          : 'حفظ وتصدير التعديلات',
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      busy ? null : _addRecord,
                                  icon: const Icon(Icons.add),
                                  label: const Text(
                                    'إضافة موتوسيكل',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: busy ? null : _export,
                                  icon: busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.file_download_outlined,
                                        ),
                                  label: Text(
                                    busy
                                        ? 'جارٍ التنفيذ...'
                                        : 'حفظ وتصدير التعديلات',
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: FutureBuilder<
                        List<Map<String, Object?>>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 42,
                                  color: AppTheme.error,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'تعذر تحميل سجلات الشيت.',
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _reload,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          );
                        }

                        final records = snapshot.data ?? [];

                        if (records.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 48,
                                    color: AppTheme.goldLight,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'لا توجد سجلات في هذا الشيت.',
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed:
                                        busy ? null : _addRecord,
                                    icon: const Icon(Icons.add),
                                    label: const Text(
                                      'إضافة أول موتوسيكل',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            20,
                          ),
                          itemCount: records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final record = records[index];

                            return AppCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: isDesktop ? 46 : 38,
                                    height: isDesktop ? 46 : 38,
                                    decoration: BoxDecoration(
                                      color: AppTheme.button
                                          .withOpacity(.12),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.two_wheeler,
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
                                          '${record['buyerName'] ?? '-'}',
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.goldBright,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'شاسيه: ${record['chassisNumber'] ?? '-'}',
                                          style: const TextStyle(
                                            color:
                                                AppTheme.secondaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'موتور: ${record['engineNumber'] ?? '-'}',
                                          style: const TextStyle(
                                            color:
                                                AppTheme.secondaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (isDesktop)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'تعديل',
                                          onPressed: busy
                                              ? null
                                              : () => _editRecord(record),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: AppTheme.goldLight,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'حذف',
                                          onPressed: busy
                                              ? null
                                              : () =>
                                                  _deleteRecord(record),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: AppTheme.error,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    PopupMenuButton<String>(
                                      enabled: !busy,
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editRecord(record);
                                        } else if (value == 'delete') {
                                          _deleteRecord(record);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: ListTile(
                                            dense: true,
                                            leading: Icon(
                                              Icons.edit_outlined,
                                            ),
                                            title: Text('تعديل'),
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            dense: true,
                                            leading: Icon(
                                              Icons.delete_outline,
                                              color: AppTheme.error,
                                            ),
                                            title: Text('حذف'),
                                          ),
                                        ),
                                      ],
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
              ),
            ),
          );
        },
      ),
    ),
  );
}

}