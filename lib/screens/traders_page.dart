import 'package:flutter/material.dart';
import 'package:seraeditor/database/app_database.dart';
import 'package:seraeditor/utils/app_card.dart';
import 'package:seraeditor/utils/app_message.dart';
import 'package:seraeditor/utils/app_theme.dart';
import 'package:seraeditor/utils/app_buttons.dart';

class TradersPage extends StatefulWidget {
  final VoidCallback onChanged;

  const TradersPage({
    super.key,
    required this.onChanged,
  });

  @override
  State<TradersPage> createState() => _TradersPageState();
}

class _TradersPageState extends State<TradersPage> {
  late Future<List<Map<String, Object?>>> future =
      AppDatabase.instance.getTraders();

  void _reload() {
    setState(() {
      future = AppDatabase.instance.getTraders();
    });
  }

  Future<void> _showTraderDialog({
    Map<String, Object?>? trader,
  }) async {
    final isEditing = trader != null;

    final traderIdController = TextEditingController(
      text: trader?['traderid']?.toString() ?? '',
    );

    final nameController = TextEditingController(
      text: trader?['tradername']?.toString() ?? '',
    );

    final phoneController = TextEditingController(
      text: trader?['traderphone']?.toString() ?? '',
    );

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(
              isEditing ? 'تعديل بيانات التاجر' : 'إضافة تاجر',
              style: const TextStyle(
                color: AppTheme.goldBright,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: traderIdController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'كود التاجر',
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم التاجر',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم التليفون (اختياري)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              AppButtons.secondary(
                label: 'إلغاء',
                icon: Icons.close_rounded,
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
              ),
              AppButtons.primary(
                label: 'حفظ',
                icon: Icons.save_outlined,
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
              ),
            ],
          );
        },
      );

      if (result != true || !mounted) return;

      final traderId = traderIdController.text.trim();
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();

      if (traderId.isEmpty) {
        AppMessage.error(context, 'من فضلك أدخل كود التاجر.');
        return;
      }

      if (name.isEmpty) {
        AppMessage.error(context, 'من فضلك أدخل اسم التاجر.');
        return;
      }

      if (isEditing) {
        await AppDatabase.instance.updateTrader(
          id: (trader['id'] as num).toInt(),
          traderid: traderId,
          tradername: name,
          traderphone: phone,
        );
      } else {
        await AppDatabase.instance.addTrader(
          traderid: traderId,
          tradername: name,
          traderphone: phone,
        );
      }

      if (!mounted) return;

      _reload();
      widget.onChanged();

      AppMessage.success(
        context,
        isEditing
            ? 'تم تعديل بيانات التاجر بنجاح.'
            : 'تمت إضافة التاجر بنجاح.',
      );
    } catch (e) {
      if (mounted) {
        AppMessage.error(
          context,
          'تعذر ${isEditing ? 'تعديل' : 'حفظ'} بيانات التاجر: $e',
        );
      }
    } finally {
      traderIdController.dispose();
      nameController.dispose();
      phoneController.dispose();
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.goldBright,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message),
        actions: [
          AppButtons.secondary(
            label: 'إلغاء',
            icon: Icons.close_rounded,
            onPressed: () =>
                Navigator.pop(dialogContext, false),
          ),
          AppButtons.danger(
            label: confirmText,
            icon: Icons.delete_outline_rounded,
            onPressed: () =>
                Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _deleteTrader(
    Map<String, Object?> trader,
  ) async {
    final name = trader['tradername']?.toString() ?? 'التاجر';
    final id = (trader['id'] as num).toInt();

    final confirmed = await _confirm(
      title: 'حذف التاجر',
      message:
          'هل أنت متأكد من حذف "$name"؟\n'
          'سيتم الاحتفاظ ببيانات الموتوسيكلات، '
          'لكن سيتم فصلها عن هذا التاجر.',
      confirmText: 'حذف',
    );

    if (!confirmed || !mounted) return;

    try {
      await AppDatabase.instance.deleteTrader(id);

      if (!mounted) return;

      _reload();
      widget.onChanged();

      AppMessage.success(context, 'تم حذف التاجر بنجاح.');
    } catch (e) {
      if (mounted) {
        AppMessage.error(context, 'تعذر حذف التاجر: $e');
      }
    }
  }

  Future<void> _deleteAllTraders(int traderCount) async {
    if (traderCount == 0) return;

    final confirmed = await _confirm(
      title: 'حذف جميع التجار',
      message:
          'هل أنت متأكد من حذف جميع التجار وعددهم $traderCount؟\n'
          'لن يتم حذف بيانات الموتوسيكلات، '
          'لكن سيتم فصلها عن التجار.',
      confirmText: 'حذف الكل',
    );

    if (!confirmed || !mounted) return;

    try {
      await AppDatabase.instance.deleteAllTraders();

      if (!mounted) return;

      _reload();
      widget.onChanged();

      AppMessage.success(
        context,
        'تم حذف جميع التجار بنجاح.',
      );
    } catch (e) {
      if (mounted) {
        AppMessage.error(context, 'تعذر حذف التجار: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'قائمة التجار',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AppButtons.secondary(
                label: 'حذف الكل',
                icon: Icons.delete_sweep_outlined,
                onPressed: () async {
                  final traders = await future;

                  if (!mounted) return;

                  await _deleteAllTraders(traders.length);
                },
              ),
              const SizedBox(width: 10),
              AppButtons.primary(
                label: 'إضافة تاجر',
                icon: Icons.person_add_alt_1,
                onPressed: () => _showTraderDialog(),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
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
                      const Text('تعذر تحميل قائمة التجار.'),
                      const SizedBox(height: 8),
                      AppButtons.primary(
                        label: 'إعادة المحاولة',
                        icon: Icons.refresh_rounded,
                        onPressed: _reload,
                      ),
                    ],
                  ),
                );
              }

              final traders = snapshot.data ?? [];

              if (traders.isEmpty) {
                return const Center(
                  child: Text(
                    'لم يتم إضافة تجار حتى الآن.',
                    style: TextStyle(
                      color: AppTheme.secondaryText,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                itemCount: traders.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final trader = traders[index];

                  final traderId =
                      trader['traderid']?.toString() ?? '';
                  final name =
                      trader['tradername']?.toString() ?? '';
                  final phone =
                      trader['traderphone']?.toString() ?? '';

                  return AppCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          color: AppTheme.goldLight,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment:
                                    WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.goldLight
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.goldLight
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      'كود: $traderId',
                                      style: const TextStyle(
                                        color: AppTheme.goldBright,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (phone.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    color: AppTheme.secondaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'تعديل بيانات التاجر',
                          onPressed: () =>
                              _showTraderDialog(trader: trader),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppTheme.goldLight,
                          ),
                        ),
                        AppButtons.dangerIcon(
                          tooltip: 'حذف التاجر',
                          onPressed: () => _deleteTrader(trader),
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
  }
}
