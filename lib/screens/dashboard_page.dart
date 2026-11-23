import 'package:flutter/material.dart';
import 'package:seraeditor/database/app_database.dart';
import 'package:seraeditor/utils/app_card.dart';
import 'package:seraeditor/utils/app_theme.dart';

class DashboardPage extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardPage({
    super.key,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>>(
      future: AppDatabase.instance.getDashboardStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};

        String val(String key) =>
            snapshot.connectionState == ConnectionState.waiting
                ? '…'
                : '${stats[key] ?? 0}';

        return SingleChildScrollView(
  physics: const AlwaysScrollableScrollPhysics(),
  padding: EdgeInsets.fromLTRB(
    20,
    20,
    20,
    MediaQuery.of(context).viewPadding.bottom + 110,
  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // كارت الترحيب بدون أزرار
              const AppCard(
                width: double.infinity,
                padding:  EdgeInsets.all(24),
                child:  Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً بك في Sera Editor',
                      style: TextStyle(
                        color: AppTheme.goldBright,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'إدارة سجلات الموتوسيكلات وتصدير الشيتات مع الاحتفاظ بتاريخ كل عملية.',
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'نظرة عامة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              // كارتان في كل صف على جميع أحجام الشاشات
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _StatCard(
                    title: 'إجمالي الموتوسيكلات',
                    value: val('bikeCount'),
                    icon: Icons.two_wheeler_rounded,
                  ),
                  _StatCard(
                    title: 'الشيتات المصدّرة',
                    value: val('sheetCount'),
                    icon: Icons.file_download_done_rounded,
                  ),
              
                ],
              ),

              const SizedBox(height: 20),

              // كارت آخر تاجر
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.store_outlined,
                      color: AppTheme.goldLight,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'آخر تاجر في شيت مُصدّر',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${stats['lastTrader'] ?? '…'}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: AppTheme.goldBright,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: AppTheme.goldLight,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.goldBright,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}