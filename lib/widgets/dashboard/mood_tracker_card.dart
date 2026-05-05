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
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              blurRadius: 12.0,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          m['emoji']!,
                          style: TextStyle(
                            fontSize: isSelected ? 28 : 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m['label']!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.accent : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
