import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Kullanıcının tıbbi profili (Kan Grubu, Alerjiler, Diyet Tercihi vb.)
class ClinicalProfileCard extends StatelessWidget {
  final String bloodType;
  final List<String> allergies;
  final String dietPreference;
  final VoidCallback onEdit;

  const ClinicalProfileCard({
    super.key,
    required this.bloodType,
    required this.allergies,
    required this.dietPreference,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.medical_information_rounded, color: AppColors.destructive, size: 20),
                  const SizedBox(width: 8),
                  Text('Klinik Bilgiler', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                ],
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Düzenle',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Kan Grubu & Diyet
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  context,
                  icon: Icons.bloodtype,
                  title: 'Kan Grubu',
                  value: bloodType.isNotEmpty ? bloodType : 'Belirtilmedi',
                  color: AppColors.destructive,
                ),
              ),
              Expanded(
                child: _buildInfoRow(
                  context,
                  icon: Icons.restaurant_menu,
                  title: 'Diyet Tercihi',
                  value: dietPreference.isNotEmpty ? dietPreference : 'Standart',
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          
          if (allergies.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Alerjiler', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allergies.map((a) => _buildWarningChip(a)).toList(),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text('Alerjiler', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('Bilinen bir alerji kaydı yok.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String title, required String value, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
