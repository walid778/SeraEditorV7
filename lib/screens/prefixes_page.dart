import 'package:flutter/material.dart';
import 'package:seraeditor/utils/app_message.dart';
import 'package:seraeditor/utils/app_theme.dart';
import 'package:seraeditor/utils/app_buttons.dart';
import 'package:seraeditor/database/app_database.dart';

class PrefixesPage extends StatefulWidget {
  const PrefixesPage({super.key});

  @override
  State<PrefixesPage> createState() => _PrefixesPageState();
}

class _PrefixesPageState extends State<PrefixesPage> {
  final AppDatabase _db = AppDatabase.instance;

  List<Map<String, Object?>> _prefixes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefixes();
  }

  Future<void> _loadPrefixes() async {
    try {
      final items = await _db.getChassisPrefixItems();

      if (!mounted) return;

      setState(() {
        _prefixes = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      AppMessage.error(
        context,
        'فشل تحميل البادئات: $e',
      );
    }
  }

  Future<void> _showPrefixDialog({
    Map<String, Object?>? item,
  }) async {
    final isEditing = item != null;

    final prefixController = TextEditingController(
      text: item == null ? '' : '${item['Prefix']}',
    );

    final capacityController = TextEditingController(
      text: item == null ? '' : '${item['Capacity'] ?? ''}',
    );

    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          bool saving = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: AppTheme.surface,
                title: Text(
                  isEditing
                      ? 'تعديل بادئة الشاسيه'
                      : 'إضافة بادئة جديدة',
                  style: const TextStyle(
                    color: AppTheme.goldBright,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: prefixController,
                          textCapitalization:
                              TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'بادئة الشاسيه',
                            hintText: 'مثال: LD3PCK4JXT',
                            prefixIcon: Icon(Icons.tag),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';

                            if (text.isEmpty) {
                              return 'اكتب بادئة الشاسيه';
                            }

                            if (text.contains(RegExp(r'\s'))) {
                              return 'البادئة لا تقبل المسافات';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'السعة (CC)',
                            hintText: 'مثال: 150',
                            prefixIcon: Icon(Icons.speed),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';

                            if (text.isNotEmpty &&
                                !RegExp(r'^\d+$').hasMatch(text)) {
                              return 'أدخل السعة بالأرقام فقط';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  AppButtons.secondary(
                    label: 'إلغاء',
                    icon: Icons.close_rounded,
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                  ),
                  AppButtons.primary(
                    label: saving ? 'جارٍ الحفظ...' : 'حفظ',
                    icon: Icons.save_outlined,
                    loading: saving,
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            setDialogState(() => saving = true);

                            try {
                              final prefix = prefixController.text
                                  .trim()
                                  .toUpperCase();

                              final capacity =
                                  capacityController.text.trim();

                              if (isEditing) {
                                await _db.updateChassisPrefix(
                                  oldPrefix: '${item['Prefix']}',
                                  newPrefix: prefix,
                                  capacity: capacity,
                                );
                              } else {
                                await _db.saveChassisPrefix(
                                  prefix: prefix,
                                  capacity: capacity,
                                );
                              }

                              if (!dialogContext.mounted) return;

                              Navigator.pop(dialogContext, true);
                            } catch (e) {
                              if (!dialogContext.mounted) return;

                              setDialogState(() => saving = false);

                              AppMessage.error(
                                dialogContext,
                                e.toString().contains(
                                  'البادئة موجودة بالفعل',
                                )
                                    ? 'البادئة موجودة بالفعل'
                                    : 'تعذر حفظ البادئة: $e',
                              );
                            }
                          },
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true && mounted) {
        await _loadPrefixes();

        if (!mounted) return;

        AppMessage.success(
          context,
          isEditing ? 'تم تعديل البادئة' : 'تم حفظ البادئة',
        );
      }
    } finally {
      prefixController.dispose();
      capacityController.dispose();
    }
  }

  Future<void> _deletePrefix(
    Map<String, Object?> item,
  ) async {
    final prefix = '${item['Prefix']}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'حذف البادئة',
          style: TextStyle(
            color: AppTheme.goldBright,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل تريد حذف البادئة $prefix؟',
          style: const TextStyle(color: AppTheme.text),
        ),
        actions: [
          AppButtons.secondary(
            label: 'إلغاء',
            icon: Icons.close_rounded,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButtons.danger(
            label: 'حذف',
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await _db.deleteChassisPrefix(prefix);

      if (!mounted) return;

      await _loadPrefixes();

      if (!mounted) return;

      AppMessage.success(context, 'تم حذف البادئة');
    } catch (e) {
      if (!mounted) return;

      AppMessage.error(
        context,
        'فشل حذف البادئة: $e',
      );
    }
  }


@override
Widget build(BuildContext context) {
  return SingleChildScrollView(
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.button.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.tag_rounded,
                color: AppTheme.goldBright,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة بادئات الشاسيه',
                    style: TextStyle(
                      color: AppTheme.goldBright,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'إضافة البادئات وربطها بسعة الموتوسيكل',
                    style: TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        AppButtons.primary(
          label: 'إضافة بادئة جديدة',
          icon: Icons.add_rounded,
          expand: true,
          onPressed: () => _showPrefixDialog(),
        ),

        const SizedBox(height: 20),

        Text(
          'البادئات المسجلة (${_prefixes.length})',
          style: const TextStyle(
            color: AppTheme.text,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 12),

        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_prefixes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'لا توجد بادئات مسجلة',
                style: TextStyle(
                  color: AppTheme.mutedText,
                ),
              ),
            ),
          )
        else
          ..._prefixes.map((item) {
            final prefix = '${item['Prefix']}';
            final capacity = '${item['Capacity'] ?? ''}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.border,
                  ),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x223DAD8B),
                    child: Icon(
                      Icons.tag,
                      color: AppTheme.goldBright,
                    ),
                  ),
                  title: Text(
                    prefix,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    capacity.isEmpty
                        ? 'السعة غير محددة'
                        : 'السعة: $capacity سم3',
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        tooltip: 'تعديل',
                        onPressed: () =>
                            _showPrefixDialog(item: item),
                        style: IconButton.styleFrom(
                          foregroundColor: AppTheme.goldLight,
                          backgroundColor:
                              AppTheme.button.withOpacity(0.10),
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.edit_outlined,
                        ),
                      ),
                      AppButtons.dangerIcon(
                        tooltip: 'حذف',
                        onPressed: () => _deletePrefix(item),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    ),
  );
}

}
