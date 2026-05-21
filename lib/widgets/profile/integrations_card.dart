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
  // 'checking', 'connected', 'needs_permission', 'available', 'unavailable', 'update_required', 'error'
  String _hcStatus = 'checking';
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    _checkHCStatus();
  }

  Future<void> _checkHCStatus() async {
    if (mounted) setState(() => _hcStatus = 'checking');
    final status = await HealthService.checkHealthConnectStatus();
    if (mounted) setState(() => _hcStatus = status);
  }

  /// Health Connect izinlerini iste ve durumu yeniden kontrol et
  Future<void> _requestPermissions() async {
    setState(() => _requestingPermission = true);
    final granted = await HealthService.requestHealthPermissions();
    if (granted) {
      await _checkHCStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Health Connect izinleri verildi! ✅'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      await _checkHCStatus();
    }
    if (mounted) setState(() => _requestingPermission = false);
  }

  /// Health Connect'i Play Store'da aç
  Future<void> _openHealthConnectStore() async {
    // Önce SDK'nın kendi yükleme metodunu dene
    try {
      await HealthService.installHealthConnect();
      // Yükledikten sonra durumu kontrol et
      await Future.delayed(const Duration(seconds: 2));
      await _checkHCStatus();
      return;
    } catch (_) {}

    // Fallback: Play Store'u aç
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';
    const marketUrl = 'market://details?id=com.google.android.apps.healthdata';
    
    final marketUri = Uri.parse(marketUrl);
    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
    } else {
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
              const Expanded(
                child: Text(
                  'Bağlantı Merkezi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              // Yenile butonu
              GestureDetector(
                onTap: _hcStatus == 'checking' ? null : _checkHCStatus,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sağlık platformlarınızı bağlayarak otomatik veri senkronizasyonu sağlayın.',
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
      case 'connected':
        return _buildConnectedItem(context);

      case 'needs_permission':
        return _buildPermissionPrompt(context);

      case 'available':
        return _buildPermissionPrompt(context);

      case 'unavailable':
        return _buildInstallPrompt(
          context,
          subtitle: 'Cihazınızda yüklü değil',
          description: 'Akıllı saatinizden veri almak için Health Connect uygulamasını yüklemeniz gerekiyor.',
          buttonText: 'Play Store\'dan Yükle',
          buttonIcon: Icons.download_rounded,
          buttonColor: AppColors.primary,
        );

      case 'update_required':
        return _buildInstallPrompt(
          context,
          subtitle: 'Güncelleme gerekli',
          description: 'Health Connect uygulamanız eski sürümde. Güncellemeniz gerekiyor.',
          buttonText: 'Güncelle',
          buttonIcon: Icons.system_update_rounded,
          buttonColor: AppColors.accent,
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
        return _buildInstallPrompt(
          context,
          subtitle: 'Bağlantı kurulamadı',
          description: 'Health Connect durumu kontrol edilemedi. Uygulamanın yüklü olduğundan emin olun.',
          buttonText: 'Play Store\'dan Yükle',
          buttonIcon: Icons.download_rounded,
          buttonColor: AppColors.primary,
        );
    }
  }

  /// HC bağlı ve izinler verilmiş
  Widget _buildConnectedItem(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.health_and_safety_rounded, color: AppColors.secondary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Health Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Text(
                'Aktif — otomatik senkronize ediliyor',
                style: TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Container(
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
        ),
      ],
    );
  }

  /// HC yüklü ama izinler verilmemiş
  Widget _buildPermissionPrompt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.health_and_safety_rounded, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Health Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    'İzin verilmedi',
                    style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, color: AppColors.accent, size: 14),
                  const SizedBox(width: 4),
                  Text('İzin Gerekli', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
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
            color: AppColors.accent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adım, nabız, uyku ve diğer sağlık verilerinizi okuyabilmemiz için Health Connect izni vermeniz gerekiyor.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _requestingPermission ? null : _requestPermissions,
                  icon: _requestingPermission
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(_requestingPermission ? 'İzin isteniyor...' : 'İzin Ver'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
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

  /// HC yüklü değil veya güncelleme gerekli
  Widget _buildInstallPrompt(
    BuildContext context, {
    required String subtitle,
    required String description,
    required String buttonText,
    required IconData buttonIcon,
    required Color buttonColor,
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
                  const Text('Health Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.destructive, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: AppColors.destructive, size: 14),
                  SizedBox(width: 4),
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
                  onPressed: _openHealthConnectStore,
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
