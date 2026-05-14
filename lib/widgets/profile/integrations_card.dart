import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/health_service.dart';

class IntegrationsCard extends StatefulWidget {
  const IntegrationsCard({super.key});

  @override
  State<IntegrationsCard> createState() => _IntegrationsCardState();
}

class _IntegrationsCardState extends State<IntegrationsCard> {
  String _hcStatus = 'checking'; // 'checking', 'available', 'unavailable', 'update_required', 'error'

  @override
  void initState() {
    super.initState();
    _checkHCStatus();
  }

  Future<void> _checkHCStatus() async {
    final status = await HealthService.checkHealthConnectStatus();
    if (mounted) {
      setState(() => _hcStatus = status);
    }
  }

  /// Health Connect'i Play Store'da aç
  Future<void> _openHealthConnectStore() async {
    // Health Connect'in Play Store paket URI'si
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';
    const marketUrl = 'market://details?id=com.google.android.apps.healthdata';
    
    // Önce market:// ile dene (doğrudan Play Store açar)
    final marketUri = Uri.parse(marketUrl);
    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
    } else {
      // Olmazsa tarayıcıda aç
      final webUri = Uri.parse(playStoreUrl);
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

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
            Text(
              'Verilerinizi otomatik senkronize etmek için sağlık platformlarınızı bağlayın.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // ── Health Connect ──
            _buildHealthConnectItem(context),

            const Divider(height: 24),
            _buildIntegrationItem(
              context,
              'Garmin Connect',
              'Yakında kullanılabilir olacak',
              Icons.watch_rounded,
              AppColors.primaryLight,
              IntegrationStatus.comingSoon,
            ),
            const Divider(height: 24),
            _buildIntegrationItem(
              context,
              'Strava',
              'Yakında kullanılabilir olacak',
              Icons.directions_run_rounded,
              AppColors.accent,
              IntegrationStatus.comingSoon,
            ),
          ],
        ),
    );
  }

  /// Health Connect satırı — duruma göre dinamik
  Widget _buildHealthConnectItem(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    switch (_hcStatus) {
      case 'available':
        return _buildIntegrationItem(
          context,
          'Health Connect',
          'Aktif — otomatik senkronize ediliyor',
          Icons.health_and_safety_rounded,
          AppColors.primary,
          IntegrationStatus.connected,
        );

      case 'unavailable':
        return _buildHCInstallPrompt(
          context,
          title: 'Health Connect',
          subtitle: 'Cihazınızda yüklü değil',
          description: 'Akıllı saatinizden veri almak için Health Connect uygulamasını yüklemeniz gerekiyor.',
          buttonText: 'Play Store\'dan Yükle',
          buttonIcon: Icons.download_rounded,
          buttonColor: AppColors.primary,
          onPressed: _openHealthConnectStore,
        );

      case 'update_required':
        return _buildHCInstallPrompt(
          context,
          title: 'Health Connect',
          subtitle: 'Güncelleme gerekli',
          description: 'Health Connect uygulamanız eski sürümde. Güncellemeniz gerekiyor.',
          buttonText: 'Güncelle',
          buttonIcon: Icons.system_update_rounded,
          buttonColor: AppColors.accent,
          onPressed: _openHealthConnectStore,
        );

      case 'checking':
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Health Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Durum kontrol ediliyor...', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        );

      default: // 'error'
        return _buildHCInstallPrompt(
          context,
          title: 'Health Connect',
          subtitle: 'Bağlantı kurulamadı',
          description: 'Health Connect durumu kontrol edilemedi. Yüklü olduğundan emin olun.',
          buttonText: 'Play Store\'dan Yükle',
          buttonIcon: Icons.download_rounded,
          buttonColor: AppColors.primary,
          onPressed: _openHealthConnectStore,
        );
    }
  }

  /// HC yüklenmemişse gösterilecek kurulum prompt'u
  Widget _buildHCInstallPrompt(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required String buttonText,
    required IconData buttonIcon,
    required Color buttonColor,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.health_and_safety_rounded, color: AppColors.destructive, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.destructive, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: AppColors.destructive, size: 14),
                  const SizedBox(width: 4),
                  Text('Gerekli', style: TextStyle(color: AppColors.destructive, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: buttonColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: buttonColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPressed,
                  icon: Icon(buttonIcon, size: 18),
                  label: Text(buttonText),
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntegrationItem(
    BuildContext context,
    String name,
    String status,
    IconData icon,
    Color color,
    IntegrationStatus integrationStatus,
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
                  color: integrationStatus == IntegrationStatus.connected
                      ? AppColors.secondary
                      : cs.onSurfaceVariant,
                  fontWeight: integrationStatus == IntegrationStatus.connected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(context, integrationStatus),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, IntegrationStatus status) {
    switch (status) {
      case IntegrationStatus.connected:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 14),
              SizedBox(width: 4),
              Text('Aktif', style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case IntegrationStatus.comingSoon:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 14),
              const SizedBox(width: 4),
              Text('Yakında', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    }
  }
}

enum IntegrationStatus {
  connected,
  comingSoon,
}
