import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app.dart';
import 'controllers/health_controller.dart';

void main() {
  Get.put(HealthController(), permanent: true);
  runApp(const HealthConnectApp());
}