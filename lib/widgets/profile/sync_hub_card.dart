import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:health/health.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/health_service.dart';
import '../../services/health_data_parser.dart';

class SyncHubCard extends StatefulWidget {
  final ParsedHealthData? data;
  final DateTime? lastSyncTime;

  const SyncHubCard({
    super.key,
    this.data,
    this.lastSyncTime,
  });

  @override
  State<SyncHubCard> createState() => _SyncHubCardState();
}

class _SyncHubCardState extends State<SyncHubCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  String _hcStatus = 'checking';
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _checkHCStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkHCStatus() async {
    if (mounted) setState(() => _hcStatus = 'checking');
    final status = await HealthService.checkHealthConnectStatus();
    if (mounted) setState(() => _hcStatus = status);
  }

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
          ),
        );
      }
    } else {
      await _checkHCStatus();
    }
    if (mounted) setState(() => _requestingPermission = false);
  }

  Future<void> _openHealthConnectStore() async {
    try {
      await HealthService.installHealthConnect();
      await Future.delayed(const Duration(seconds: 2));
      await _checkHCStatus();
      return;
    } catch (_) {}

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
    
    // Cihaz ikonunu belirle
    String primaryBrand = "Sistem Sensörü";
    IconData brandIcon = Icons.smartphone_rounded;
    
    if (widget.data != null && widget.data!.allSources.isNotEmpty) {
      final sources = widget.data!.allSources.map((s) => s.toLowerCase()).toList();
      if (sources.any((s) => s.contains('xiaomi') || s.contains('mi.fitness') || s.contains('redmi'))) {
        primaryBrand = "Xiaomi / Redmi Watch";
        brandIcon = Icons.watch_rounded;
      } else if (sources.any((s) => s.contains('huawei'))) {
        primaryBrand = "Huawei Health";
        brandIcon = Icons.watch_rounded;
      } else if (sources.any((s) => s.contains('samsung'))) {
        primaryBrand = "Samsung Health";
        brandIcon = Icons.watch_rounded;
      } else if (sources.any((s) => s.contains('garmin'))) {
        primaryBrand = "Garmin Connect";
        brandIcon = Icons.watch_rounded;
      } else if (sources.any((s) => s.contains('fitness'))) {
        primaryBrand = "Google Fit";
        brandIcon = Icons.smartphone_rounded;
      }
    }

    final bool isConnected = _hcStatus == 'connected';
    final Color statusColor = isConnected ? AppColors.secondary : AppColors.accent;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface,
              statusColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Veri Merkezi', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  if (widget.lastSyncTime != null)
                    Text(
                      'Son Senkronizasyon: ${widget.lastSyncTime!.hour.toString().padLeft(2, '0')}:${widget.lastSyncTime!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    )
                  else
                    GestureDetector(
                      onTap: _hcStatus == 'checking' ? null : _checkHCStatus,
                      child: Icon(Icons.refresh_rounded, size: 18, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              
              // CENTER ANIMATION & ICON
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 100 + (_pulseController.value * 20),
                      height: 100 + (_pulseController.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.1 - (_pulseController.value * 0.05)),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3 - (_pulseController.value * 0.2)),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor.withValues(alpha: 0.2),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: _pulseController.value * 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            brandIcon,
                            size: 40,
                            color: isConnected ? statusColor : Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // DEVICE NAME
              Text(
                primaryBrand,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Health Connect üzerinden veri akışı sağlanıyor.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // STATUS PILL / ACTION BUTTON
              _buildStatusPill(context, isConnected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, bool isConnected) {
    if (_hcStatus == 'checking') {
      return const CircularProgressIndicator();
    }

    if (isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 18),
            SizedBox(width: 8),
            Text('Canlı Senkronizasyon Aktif', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // İzin veya Yükleme Gerekli
    String buttonText = 'İzin Ver';
    IconData buttonIcon = Icons.health_and_safety_rounded;
    VoidCallback action = _requestPermissions;

    if (_hcStatus == 'unavailable' || _hcStatus == 'error') {
      buttonText = 'Health Connect Yükle';
      buttonIcon = Icons.download_rounded;
      action = _openHealthConnectStore;
    } else if (_hcStatus == 'update_required') {
      buttonText = 'Health Connect Güncelle';
      buttonIcon = Icons.system_update_rounded;
      action = _openHealthConnectStore;
    }

    return GestureDetector(
      onTap: _requestingPermission ? null : action,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_requestingPermission)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            else
              Icon(buttonIcon, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text(buttonText, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
