import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/health_chart.dart';
import '../widgets/stat_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashboardController>(
      init: DashboardController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Live Health Dashboard'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.developer_mode),
                tooltip: 'Debug',
                onPressed: () => Get.toNamed('/debug'),
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(
                    color: Color(0xFF12A5ED),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Zero Provision • No Network',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Permissions'),
                  onTap: () => Get.toNamed('/permissions'),
                ),
                ListTile(
                  leading: const Icon(Icons.developer_mode),
                  title: const Text('Debug & Simulation'),
                  onTap: () => Get.toNamed('/debug'),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await controller.refreshData();
              },
              child: Obx(() {
                return _buildContent(context, controller);
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
      BuildContext context, DashboardController controller) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PerformanceHud(
            avgBuildTime: controller.avgBuildTimeMs.value,
            paintTime: controller.lastPaintTimeMs.value,
            fps: controller.fps.value,
            meetsTarget: controller.meetsBuildTarget.value,
            updateCount: controller.totalUpdatesReceived.value,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Steps Today',
                value: _formatNumber(controller.totalStepsToday.value),
                subtitle: 'Live total',
                icon: Icons.directions_walk,
                accentColor: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Heart Rate',
                value: controller.currentHeartRate.value > 0
                    ? '${controller.currentHeartRate.value.toStringAsFixed(0)} bpm'
                    : '--',
                subtitle: controller.heartRateAge.value,
                icon: Icons.favorite,
                accentColor: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(context, 'Steps vs Time (60 min)'),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 260,
              child: HealthChart(
                points: controller.stepsChartData,
                lineColor: Colors.blue,
                areaColor: Colors.blue.withValues(alpha: 0.15),
                title: 'Step Count',
                unit: 'steps',
                window: const Duration(minutes: AppConstants.chartWindowMinutes),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionHeader(context, 'Heart Rate vs Time (rolling)'),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 260,
              child: HealthChart(
                points: controller.hrChartData,
                lineColor: Colors.red,
                areaColor: Colors.red.withValues(alpha: 0.15),
                title: 'Heart Rate',
                unit: 'bpm',
                window: const Duration(minutes: AppConstants.chartWindowMinutes),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Obx(() => controller.isListening.value
            ? const SizedBox()
            : _buildSyncBanner(context)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  String _formatNumber(int number) {
    final text = number.toString();
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return text;
  }

  Widget _buildSyncBanner(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.wifi_off,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not receiving updates. Check permissions or enable simulation.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}