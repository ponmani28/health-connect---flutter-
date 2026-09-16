import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/debug_controller.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DebugController>(
      init: DebugController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Debug & Simulation'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSimSourceCard(context, controller),
                const SizedBox(height: 16),
                _buildManualEmitCard(context, controller),
                const SizedBox(height: 16),
                _buildDataManagementCard(context, controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimSourceCard(
      BuildContext context, DebugController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.science, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  'Simulation Source',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Emits synthetic steps and heart-rate updates through the '
              'same stream interface as the real Health Connect listener.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(controller.simEnabled.value
                  ? 'Simulation Active'
                  : 'Simulation Off'),
              subtitle: const Text('No Health Connect writes'),
              value: controller.simEnabled.value,
              onChanged: (value) => controller.toggleSimSource(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Steps Emitted',
                    controller.emittedSteps.value.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'HR (bpm)',
                    controller.emittedHr.value.toStringAsFixed(0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEmitCard(
      BuildContext context, DebugController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Emission',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.emitSteps(count: 100),
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('+100 Steps'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.emitHeartRate(bpm: 92),
                    icon: const Icon(Icons.favorite),
                    label: const Text('Emit HR 92'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard(
      BuildContext context, DebugController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.injectHistory(),
                    icon: const Icon(Icons.history),
                    label: const Text('2h History'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.clearAllData(),
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Clear All'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total events emitted: ${controller.totalEventsEmitted.value}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}