import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer efektli iskelet yükleme widget'ı.
/// Tüm ekranlarda CircularProgressIndicator yerine kullanılır.
class ShimmerLoading extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final bool showHeader;

  const ShimmerLoading({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 120,
    this.showHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? cs.surfaceContainerHighest : const Color(0xFFE8E8E8);
    final highlightColor = isDark ? cs.surface : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              _shimmerBox(context, width: 180, height: 24, radius: 8),
              const SizedBox(height: 8),
              _shimmerBox(context, width: 120, height: 14, radius: 6),
              const SizedBox(height: 24),
            ],
            ...List.generate(
              itemCount,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _shimmerCard(context, height: itemHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerCard(BuildContext context, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _shimmerBox(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Dashboard'a özel 2x3 grid shimmer
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? cs.surfaceContainerHighest : const Color(0xFFE8E8E8);
    final highlightColor = isDark ? cs.surface : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gauge card shimmer
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 20),
            // Section title shimmer
            Container(
              width: 140,
              height: 18,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 12),
            // Metrics grid shimmer (2x3)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.35,
              children: List.generate(
                6,
                (_) => Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Water + mood shimmer
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Beslenme ekranı shimmer
class NutritionShimmer extends StatelessWidget {
  const NutritionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? cs.surfaceContainerHighest : const Color(0xFFE8E8E8);
    final highlightColor = isDark ? cs.surface : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Makro özet kartı
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            // Öğün kartları
            ...List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
