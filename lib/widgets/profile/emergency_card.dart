import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../common_widgets.dart';

class EmergencyCard extends StatelessWidget {
  final String bloodType;
  final String allergies;
  final String emergencyContact;
  final VoidCallback onEdit;

  const EmergencyCard({
    super.key,
    required this.bloodType,
    required this.allergies,
    required this.emergencyContact,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.destructive.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emergency_rounded, color: AppColors.destructive, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Dijital Sağlık Kartı',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_note_rounded, color: cs.primary),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoItem(context, 'Kan Grubu', bloodType.isEmpty ? '--' : bloodType, Icons.bloodtype_rounded, AppColors.destructive),
              const SizedBox(width: 12),
              _buildInfoItem(context, 'Alerjiler', allergies.isEmpty ? 'Yok' : allergies, Icons.warning_amber_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.contact_phone_rounded, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                const Text('Acil Durum:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    emergencyContact.isEmpty ? 'Belirtilmedi' : emergencyContact,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
