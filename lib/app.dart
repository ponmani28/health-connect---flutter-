import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pages/dashboard_page.dart';

class HealthConnectApp extends StatelessWidget {
  const HealthConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Health Connect Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF12A5ED)),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}