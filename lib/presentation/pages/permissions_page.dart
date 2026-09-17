import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/permissions_controller.dart';

class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PermissionsController>(
      init: PermissionsController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Health Connect Permissions'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: Obx(() => _buildBody(context, controller)),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PermissionsController controller) {
    if (controller.isLoading.value) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking permissions...'),
          ],
        ),
      );
    }

    if (controller.errorMessage.value.isNotEmpty) {
      final healthConnectMissing = !controller.isInitialized.value ||
          controller.sdkStatus.value != 'available';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                controller.errorMessage.value,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              if (healthConnectMissing) ...[
                ElevatedButton.icon(
                  onPressed: () => controller.installHealthConnect(),
                  icon: const Icon(Icons.system_update_alt),
                  label: Text(
                    controller.sdkStatus.value == 'update_required'
                        ? 'Update Health Connect'
                        : 'Install Health Connect',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: () => controller.checkPermissions(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.health_and_safety, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'Health Connect Access',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This app needs access to your health data to display the dashboard.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildPermissionTile(
            context,
            icon: Icons.directions_walk,
            label: 'Steps',
            granted: controller.stepsGranted.value,
          ),
          const SizedBox(height: 12),
          _buildPermissionTile(
            context,
            icon: Icons.favorite,
            label: 'Heart Rate',
            granted: controller.heartRateGranted.value,
          ),
          const SizedBox(height: 32),
          if (controller.allGranted.value)
            ElevatedButton.icon(
              onPressed: () => controller.navigateToDashboard(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Go to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => controller.requestPermissions(),
              icon: const Icon(Icons.security),
              label: const Text('Grant Permissions'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => controller.checkPermissions(),
            child: const Text('Refresh Status'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool granted,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: granted ? Colors.green : Colors.grey),
        title: Text(label),
        trailing: Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.red,
        ),
        subtitle: Text(granted ? 'Granted' : 'Not granted'),
      ),
    );
  }
}
