import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Emoji tabanlı ruh hali takip kartı.
class MoodTrackerCard extends StatelessWidget {
  final String currentMood;
  final Future<void> Function(String mood) onMoodSelected;

  static const _moods = [
    {'val': 'happy', 'emoji': '🤩', 'label': 'Harika'},
    {'val': 'good', 'emoji': '😊', 'label': 'İyi'},
    {'val': 'neutral', 'emoji': '😐', 'label': 'Normal'},
    {'val': 'tired', 'emoji': '😫', 'label': 'Yorgun'},
    {'val': 'stressed', 'emoji': '😵\u200d💫', 'label': 'Stresli'},
  ];

  const MoodTrackerCard({
    super.key,
    required this.currentMood,
    required this.onMoodSelected,
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emoji_emotions_outlined, color: AppColors.accent, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Bugün Nasılsın?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _moods.map((m) {
              final isSelected = currentMood == m['val'];
              return GestureDetector(
                onTap: () => onMoodSelected(m['val']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        m['emoji']!,
                        style: TextStyle(
                          fontSize: 24,
                          color: isSelected ? null : Colors.grey.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m['label']!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppColors.accent : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
