
import 'package:flutter/material.dart';
import 'package:seraeditor/utils/app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.goldLight,
          size: 21,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.goldBright,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _feature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.goldLight.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.goldLight,
              size: 22,
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
                    color: AppTheme.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.secondaryText,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
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
                    // شعار التطبيق
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppTheme.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppTheme.goldLight.withOpacity(.12),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.two_wheeler_rounded,
                              color: AppTheme.goldBright,
                              size: 52,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'SeraEditor',
                            style: TextStyle(
                              color: AppTheme.goldBright,
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'إدارة وتنظيم بيانات الموتوسيكلات',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.button.withOpacity(.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'الإصدار 1.0.0',
                              style: TextStyle(
                                color: AppTheme.goldLight,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // نبذة عن التطبيق
                    _sectionTitle(
                      'عن التطبيق',
                      Icons.info_outline_rounded,
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.border,
                        ),
                      ),
                      child: const Text(
                        'SeraEditor هو تطبيق مخصص لإدارة وتنظيم بيانات '
                        'الموتوسيكلات وبيانات المشترين والتجار، '
                        'مع توفير أدوات تساعد على تسهيل إدخال البيانات '
                        'وحفظها وتعديلها وتصديرها إلى ملفات Excel.\n\n'
                        'يهدف التطبيق إلى توفير تجربة سهلة وسريعة '
                        'لتنظيم العمل وتقليل الأخطاء وتسهيل الوصول '
                        'إلى البيانات السابقة.',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 13,
                          height: 1.9,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // المميزات
                    _sectionTitle(
                      'مميزات التطبيق',
                      Icons.stars_rounded,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          _feature(
                            icon: Icons.motorcycle_rounded,
                            title: 'إدارة بيانات الموتوسيكلات',
                            description:
                                'إضافة وتعديل وتنظيم بيانات الشاسيه والموتور.',
                          ),
                          _feature(
                            icon: Icons.storefront_rounded,
                            title: 'إدارة التجار',
                            description:
                                'تنظيم بيانات التجار وأكوادهم بسهولة.',
                          ),
                          _feature(
                            icon: Icons.history_rounded,
                            title: 'السجل التاريخي',
                            description:
                                'الاحتفاظ بالشيتات القديمة وإمكانية الرجوع إليها وتعديلها.',
                          ),
                          _feature(
                            icon: Icons.file_download_outlined,
                            title: 'تصدير Excel',
                            description:
                                'تصدير البيانات إلى ملفات Excel وإعادة تصدير الشيتات السابقة.',
                          ),
                          _feature(
                            icon: Icons.document_scanner_outlined,
                            title: 'استخراج البيانات من الصور',
                            description:
                                'قراءة بيانات البطاقة الشخصية وأرقام الشاسيه والموتور باستخدام OCR.',
                          ),
                          _feature(
                            icon: Icons.search_rounded,
                            title: 'البحث السريع',
                            description:
                                'سهولة البحث والوصول إلى البيانات المطلوبة.',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // معلومات التطبيق
                    _sectionTitle(
                      'معلومات التطبيق',
                      Icons.settings_outlined,
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.border,
                        ),
                      ),
                    child: Column(
  children: [
    _infoRow('اسم التطبيق', 'SeraEditor'),
    const Divider(color: AppTheme.border),
    _infoRow('الإصدار', '1.0.0'),
    const Divider(color: AppTheme.border),
    _infoRow('اللغة', 'العربية'),
    const Divider(color: AppTheme.border),
    _infoRow('التخزين', 'محلي'),
    const Divider(color: AppTheme.border),
    _infoRow('رقم الهاتف', '01099867346'),
  ],
),
                    ),

                    const SizedBox(height: 28),

                    // حقوق التطبيق
                    const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: AppTheme.goldLight,
                            size: 22,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'صُنع بعناية لتسهيل عملك',
                            style: TextStyle(
                              color: AppTheme.goldBright,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'جميع الحقوق محفوظة © SeraEditor',
                            style: TextStyle(
                              color: AppTheme.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
