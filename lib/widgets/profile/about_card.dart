import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/common_widgets.dart';

/// Hakkında kartı — Yardım, Web Sitesi, Gizlilik
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('Resmi Web Sitesi', 'https://aksa.app'),
      ('Yardım Merkezi', 'https://aksa.app/help'),
      ('Gizlilik ve Koşullar', 'https://aksa.app/privacy'),
    ];
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Destek ve Topluluk', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Column(
              children: [
                InkWell(
                  onTap: () => _launchUrl(item.$2),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.$1, style: TextStyle(color: cs.onSurface)),
                        Icon(Icons.open_in_new_rounded, color: cs.onSurfaceVariant, size: 18),
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
