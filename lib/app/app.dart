import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/repositories/health_repository.dart';
import '../data/sources/sim_source.dart';
import '../presentation/pages/dashboard_page.dart';
import '../presentation/pages/debug_page.dart';
import '../presentation/pages/permissions_page.dart';

class AppBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SimSource>(() => SimSource());
    Get.lazyPut<HealthRepository>(
      () => HealthRepository(simSource: Get.find<SimSource>()),
      fenix: true,
    );
  }
}

class AppRoutes {
  static const String permissions = '/permissions';
  static const String dashboard = '/dashboard';
  static const String debug = '/debug';

  static List<GetPage> pages = [
    GetPage(
      name: permissions,
      page: () => const PermissionsPage(),
      binding: AppBinding(),
    ),
    GetPage(
      name: dashboard,
      page: () => const DashboardPage(),
      binding: AppBinding(),
    ),
    GetPage(
      name: debug,
      page: () => const DebugPage(),
      binding: AppBinding(),
    ),
  ];
}

class HealthConnectApp extends StatelessWidget {
  const HealthConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Health Connect Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12A5ED),
        ),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.permissions,
      getPages: AppRoutes.pages,
      debugShowCheckedModeBanner: false,
    );
  }
}