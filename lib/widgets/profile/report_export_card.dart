import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/report_service.dart';

class ReportExportCard extends StatefulWidget {
  const ReportExportCard({super.key});

  @override
  State<ReportExportCard> createState() => _ReportExportCardState();
}

class _ReportExportCardState extends State<ReportExportCard> {
  bool _isExporting = false;

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      await ReportService.generateAndShareReport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapor oluşturulamadı: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
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
              Icon(Icons.insert_chart_outlined, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text('Sağlık Raporu', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Son 30 günlük detaylı sağlık verilerinizi doktorunuzla paylaşmak için dışa aktarabilirsiniz.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _handleExport,
              icon: _isExporting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_isExporting ? 'Hazırlanıyor...' : 'Raporu İndir (CSV)'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
