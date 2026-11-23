
import 'package:flutter/material.dart';
import 'package:seraeditor/screens/about_page.dart';
import 'package:seraeditor/screens/current_sheet_page.dart';
import 'package:seraeditor/screens/dashboard_page.dart';
import 'package:seraeditor/screens/history_page.dart';
import 'package:seraeditor/screens/image_data_extractor_page.dart';
import 'package:seraeditor/screens/prefixes_page.dart';

import 'package:seraeditor/utils/app_navbar.dart';
import 'package:seraeditor/utils/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  int refreshToken = 0;

  static const pageTitles = [
    'الرئيسية',
    'اضافه شيت جديد',
    'الشيتات',
      'البادئات',
        'قراءة البيانات من الصور',
         'عن التطبيق',
  ];

  void _navigateTo(int index) {
    setState(() => selectedIndex = index);
  }

  void _refreshAll() {
    setState(() => refreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        key: ValueKey('dashboard-$refreshToken'),
        onNavigate: _navigateTo,
      ),
      CurrentSheetPage(
        key: ValueKey('current-$refreshToken'),
        onChanged: _refreshAll,
      ),
      HistoryPage(
        key: ValueKey('history-$refreshToken'),
        onChanged: _refreshAll,
      ),
    
      PrefixesPage(
        key: ValueKey('prefixes-$refreshToken'),
       
      ),

      const ImageDataExtractorPage(
    key: ValueKey('image-extractor'),
  ),
  
   AboutPage(
        key: ValueKey('about-$refreshToken'),

      ),

    ];

return Scaffold(
  backgroundColor: AppTheme.background,
  body: SafeArea(
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        final content = Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                pageTitles[selectedIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppTheme.background,
              elevation: 0,
             actions: [
 
  // زر التحديث
  IconButton(
    tooltip: 'تحديث',
    onPressed: _refreshAll,
    icon: const Icon(
      Icons.refresh_rounded,
      color: AppTheme.goldLight,
    ),
  ),


const SizedBox(width: 8),
],
            ),
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children: pages,
              ),
            ),
          ],
        );

        if (isDesktop) {
          return Row(
            children: [
              AppNavbar(
                selectedIndex: selectedIndex,
                onDestinationSelected: _navigateTo,
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppTheme.divider,
              ),
              Expanded(child: content),
            ],
          );
        }

        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Stack(
          children: [
            // الصفحة الأساسية
            Positioned.fill(
              child: content,
            ),

            // مساحة محجوزة أسفل الصفحة حتى لا يغطي الـ Navbar المحتوى
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 66 + 8 + 10 + bottomInset,
              ),
            ),

            // الـ Navbar العائم
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomInset + 10,
              child: AppNavbar(
                selectedIndex: selectedIndex,
                onDestinationSelected: _navigateTo,
              ),
            ),
          ],
        );
      },
    ),
  ),
);

  }
}
