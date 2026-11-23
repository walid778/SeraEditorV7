
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seraeditor/database/app_database.dart';
import 'package:seraeditor/screens/edit_historical_sheet_page.dart';
import 'package:seraeditor/services/excel_export_service.dart';
import 'package:seraeditor/utils/app_buttons.dart';
import 'package:seraeditor/utils/app_card.dart';
import 'package:seraeditor/utils/app_message.dart';
import 'package:seraeditor/utils/app_theme.dart';

class HistoryPage extends StatefulWidget {
  final VoidCallback onChanged;

  const HistoryPage({
    super.key,
    required this.onChanged,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, Object?>>> future =
      AppDatabase.instance.getSheetHistory();

  bool busy = false;

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  Map<String, Set<String>> _traderCodesByName = {};

  @override
  void initState() {
    super.initState();
    _loadTraderCodes();
  }

  Future<void> _loadTraderCodes() async {
    try {
      final traders = await AppDatabase.instance.getTraders();

      final codes = <String, Set<String>>{};

      for (final trader in traders) {
        final name = '${trader['tradername'] ?? ''}'
            .trim()
            .toLowerCase();

        final code = '${trader['traderid'] ?? ''}'
            .trim()
            .toLowerCase();

        if (name.isNotEmpty && code.isNotEmpty) {
          codes.putIfAbsent(name, () => <String>{}).add(code);
        }
      }

      if (!mounted) return;

      setState(() {
        _traderCodesByName = codes;
      });
    } catch (_) {
      // تظل الصفحة قابلة للاستخدام.
    }
  }

  bool _matchesSearch(Map<String, Object?> sheet) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    final title =
        '${sheet['title'] ?? ''}'.toLowerCase();

    final traderName =
        '${sheet['traderName'] ?? ''}'.trim().toLowerCase();

    final codes =
        _traderCodesByName[traderName] ?? <String>{};

    return title.contains(query) ||
        traderName.contains(query) ||
        codes.any((code) => code.contains(query));
  }

  String _date(Object? value) {
    if (value == null) return '-';

    try {
      return DateFormat('yyyy/MM/dd  HH:mm')
          .format(DateTime.parse('$value').toLocal());
    } catch (_) {
      return '$value';
    }
  }

  String _traderCode(String traderName) {
    final codes = _traderCodesByName[
          traderName.trim().toLowerCase()
        ] ??
        <String>{};

    if (codes.isEmpty) return '';

    return codes.join(' - ');
  }

  Future<void> _refreshHistory() async {
    setState(() {
      future = AppDatabase.instance.getSheetHistory();
    });
  }

  // حذف شيت واحد.
  Future<void> _deleteSheet(
    Map<String, Object?> sheet,
  ) async {
    if (busy) return;

    final idValue = sheet['id'];

    if (idValue is! num) {
      AppMessage.error(context, 'رقم الشيت غير صحيح.');
      return;
    }

    final sheetId = idValue.toInt();

    final sheetTitle =
        '${sheet['title'] ?? 'الشيت القديم'}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'تأكيد حذف الشيت',
          style: TextStyle(
            color: AppTheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف "$sheetTitle"؟\n\n'
          'سيتم حذف الشيت وجميع سجلاته. '
          'لا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(color: AppTheme.text),
        ),
        actions: [
          AppButtons.secondary(
            label: 'إلغاء',
            icon: Icons.close_rounded,
            onPressed: () =>
                Navigator.pop(dialogContext, false),
          ),
          AppButtons.danger(
            label: 'حذف نهائي',
            icon: Icons.delete_outline_rounded,
            onPressed: () =>
                Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => busy = true);

    try {
      await AppDatabase.instance.deleteHistoricalSheet(sheetId);

      if (!mounted) return;

      setState(() {
        future = AppDatabase.instance.getSheetHistory();
      });

      widget.onChanged();

      AppMessage.success(
        context,
        'تم حذف الشيت "$sheetTitle" بنجاح.',
      );
    } catch (e) {
      if (mounted) {
        AppMessage.error(
          context,
          'تعذر حذف الشيت: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // حذف جميع الشيتات.
  Future<void> _deleteAllSheets() async {
    if (busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'حذف كل الشيتات القديمة',
          style: TextStyle(
            color: AppTheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'هل أنت متأكد من حذف جميع الشيتات القديمة؟\n\n'
          'سيتم حذف الشيتات وسجلاتها نهائيًا. '
          'لن يتم حذف الشيت الحالي أو بيانات الموتوسيكلات الأصلية.',
          style: TextStyle(color: AppTheme.text),
        ),
        actions: [
          AppButtons.secondary(
            label: 'إلغاء',
            icon: Icons.close_rounded,
            onPressed: () =>
                Navigator.pop(dialogContext, false),
          ),
          AppButtons.danger(
            label: 'حذف الكل',
            icon: Icons.delete_forever_rounded,
            onPressed: () =>
                Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => busy = true);

    try {
      final deletedCount =
          await AppDatabase.instance.deleteAllHistoricalSheets();

      if (!mounted) return;

      setState(() {
        future = AppDatabase.instance.getSheetHistory();
      });

      widget.onChanged();

      AppMessage.success(
        context,
        'تم حذف $deletedCount شيت قديم بنجاح.',
      );
    } catch (e) {
      if (mounted) {
        AppMessage.error(
          context,
          'تعذر حذف الشيتات القديمة: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // إعادة تصدير الشيت.
  Future<void> _reExport(
    Map<String, Object?> sheet,
  ) async {
    if (busy) return;

    final idValue = sheet['id'];

    if (idValue is! num) {
      AppMessage.error(context, 'رقم الشيت غير صحيح.');
      return;
    }

    final id = idValue.toInt();

    setState(() => busy = true);

    try {
      final records =
          await AppDatabase.instance.getSheetSnapshots(id);

      final path =
          await ExcelExportService.instance.exportSheet(
        sheetId: id,
        records: records,
        traderName: '${sheet['traderName'] ?? ''}',
        isHistory: true,
      );

      if (path != null) {
        await AppDatabase.instance.updateReExportPath(id, path);

        if (!mounted) return;

        setState(() {
          future = AppDatabase.instance.getSheetHistory();
        });

        widget.onChanged();

        AppMessage.success(
          context,
          'تمت إعادة تصدير الشيت القديم.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessage.error(
          context,
          'تعذرت إعادة التصدير: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // فتح الشيت للتعديل.
  Future<void> _editHistorySheet(
    Map<String, Object?> sheet,
  ) async {
    if (busy) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditHistoricalSheetPage(
          sheet: sheet,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {
        future = AppDatabase.instance.getSheetHistory();
      });

      widget.onChanged();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // صف بيانات داخل الكارت.
  Widget _historyInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: AppTheme.goldLight,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 88,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: AppTheme.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: Directionality.of(context),
            softWrap: true,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  // تصميم كارت الشيت.
  Widget _buildHistoryCard(
    Map<String, Object?> sheet,
  ) {
    final title =
        '${sheet['title'] ?? 'شيت بدون اسم'}';

    final traderName =
        '${sheet['traderName'] ?? ''}'.trim();

    final traderCode = _traderCode(traderName);

    final recordCount =
        '${sheet['recordCount'] ?? 0}';

    final date = _date(
      sheet['completedAt'] ?? sheet['createdAt'],
    );

    final exportedPath =
        '${sheet['exportedPath'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        onTap: busy
            ? null
            : () => _editHistorySheet(sheet),
        padding: const EdgeInsets.all(16),
        borderRadius: 18,
        elevation: 2,
        borderColor: AppTheme.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // رأس الكارت.
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.goldLight.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppTheme.goldLight,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.goldBright,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: AppTheme.mutedText,
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(
              color: AppTheme.border,
              height: 1,
            ),

            const SizedBox(height: 14),

            // التاريخ.
            _historyInfoRow(
              icon: Icons.calendar_month_rounded,
              label: 'التاريخ',
              value: date,
            ),

            const SizedBox(height: 12),

            // التاجر.
            _historyInfoRow(
              icon: Icons.storefront_rounded,
              label: 'التاجر',
              value: traderName.isEmpty
                  ? 'غير محدد'
                  : traderName,
            ),

            if (traderCode.isNotEmpty) ...[
              const SizedBox(height: 12),
              _historyInfoRow(
                icon: Icons.qr_code_rounded,
                label: 'كود التاجر',
                value: traderCode,
              ),
            ],

            const SizedBox(height: 12),

            // عدد السجلات.
            _historyInfoRow(
              icon: Icons.motorcycle_rounded,
              label: 'السجلات',
              value: recordCount,
            ),

                       // مسار ملف التصدير.
            if (exportedPath.isNotEmpty) ...[
              const SizedBox(height: 12),
              _historyInfoRow(
                icon: Icons.description_outlined,
                label: 'ملف التصدير',
                value: exportedPath,
              ),
            ],

            const SizedBox(height: 16),

            const Divider(
              color: AppTheme.border,
              height: 1,
            ),

            const SizedBox(height: 10),

            // الإجراءات.
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'اضغط على الكارت للتعديل',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 11,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'إعادة التصدير',
                  onPressed: busy
                      ? null
                      : () => _reExport(sheet),
                  icon: const Icon(
                    Icons.file_download_outlined,
                    color: AppTheme.goldLight,
                  ),
                ),

                AppButtons.dangerIcon(
                  tooltip: 'حذف الشيت نهائيًا',
                  onPressed: busy
                      ? null
                      : () => _deleteSheet(sheet),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snapshot) {
        final sheets = snapshot.data ?? [];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل الشيتات.'),
                const SizedBox(height: 8),
                AppButtons.primary(
                  label: 'إعادة المحاولة',
                  icon: Icons.refresh_rounded,
                  onPressed: _refreshHistory,
                ),
              ],
            ),
          );
        }

        final filteredSheets =
            sheets.where(_matchesSearch).toList();

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(context).viewPadding.bottom + 110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'عدد الشيتات (${sheets.length})',
                      style: const TextStyle(
                        color: AppTheme.goldBright,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  AppButtons.danger(
                    label: 'حذف الكل',
                    icon: Icons.delete_sweep_outlined,
                    onPressed: busy || sheets.isEmpty
                        ? null
                        : _deleteAllSheets,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: const TextStyle(
                  color: AppTheme.text,
                ),
                decoration: InputDecoration(
                  hintText:
                      'ابحث بكود التاجر أو اسمه أو اسم الشيت...',
                  hintStyle: const TextStyle(
                    color: AppTheme.mutedText,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.goldLight,
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.border,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (sheets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'لسه مفيش شيتات مكتملة. بعد تصدير أول شيت هتلاقيه هنا.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ),
                )
              else if (filteredSheets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'لا توجد نتائج مطابقة للبحث.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ),
                )
              else
                ...filteredSheets.map(_buildHistoryCard),
            ],
          ),
        );
      },
    );
  }
}