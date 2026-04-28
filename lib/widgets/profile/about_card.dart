import 'package:flutter/material.dart';
import '../../widgets/common_widgets.dart';

/// Hakkında kartı — yardım, koşullar, gizlilik linkleri + versiyon.
class AboutCard extends StatelessWidget {
  final VoidCallback onHelpTap;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyPolicyTap;

  const AboutCard({
    super.key,
    required this.onHelpTap,
    required this.onTermsTap,
    required this.onPrivacyPolicyTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('Yardım ve Destek', onHelpTap),
      ('Kullanım Koşulları', onTermsTap),
      ('Gizlilik Politikası', onPrivacyPolicyTap),
    ];
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hakkında', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Column(
              children: [
                InkWell(
                  onTap: item.$2,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.$1, style: TextStyle(color: cs.onSurface)),
                        Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
                      ],
                    ),
                  ),
                ),
                Divider(color: cs.outlineVariant, height: 1),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'AKSA v1.0.0 • Akıllı Kişisel Sağlık Asistanı',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
