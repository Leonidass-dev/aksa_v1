import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class IntegrationsCard extends StatelessWidget {
  const IntegrationsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Bağlantı Merkezi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Verilerinizi otomatik senkronize etmek için sağlık platformlarınızı bağlayın.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildIntegrationItem(
            context,
            'Health Connect / Apple Health',
            'Aktif',
            Icons.health_and_safety_rounded,
            Colors.redAccent,
            true,
          ),
          const Divider(height: 24),
          _buildIntegrationItem(
            context,
            'Garmin Connect',
            'Bağlı Değil',
            Icons.watch_rounded,
            Colors.blueGrey,
            false,
          ),
          const Divider(height: 24),
          _buildIntegrationItem(
            context,
            'Strava',
            'Bağlı Değil',
            Icons.directions_run_rounded,
            Colors.orange,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationItem(
    BuildContext context,
    String name,
    String status,
    IconData icon,
    Color color,
    bool isConnected,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? AppColors.secondary : cs.onSurfaceVariant,
                  fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: isConnected,
          onChanged: (v) {},
          activeThumbColor: AppColors.secondary,
        ),
      ],
    );
  }
}
