import 'package:flutter/material.dart';

class LandingReplayControls extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final double speed;
  final List<double> speedOptions;

  final VoidCallback onPlayPause;
  final VoidCallback onReplay;
  final ValueChanged<double> onScrub;
  final ValueChanged<double> onSpeedSelected;

  const LandingReplayControls({
    super.key,
    required this.isPlaying,
    required this.progress,
    required this.speed,
    required this.speedOptions,
    required this.onPlayPause,
    required this.onReplay,
    required this.onScrub,
    required this.onSpeedSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: onScrub,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _iconBtn(
                icon: Icons.replay_10,
                onTap: () => onScrub((progress - 0.05).clamp(0.0, 1.0)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mainPlayButton(),
              ),
              const SizedBox(width: 8),
              _iconBtn(
                icon: Icons.forward_10,
                onTap: () => onScrub((progress + 0.05).clamp(0.0, 1.0)),
              ),
              const SizedBox(width: 8),
              _iconBtn(
                icon: Icons.replay,
                onTap: onReplay,
              ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: speedOptions.map((v) {
              final selected = v == speed;
              return GestureDetector(
                onTap: () => onSpeedSelected(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.20)
                        : colors.surface.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? colors.primary.withValues(alpha: 0.55)
                          : colors.outline.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    '${v}x',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _mainPlayButton() {
    return ElevatedButton.icon(
      onPressed: onPlayPause,
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      label: Text(isPlaying ? 'Pause' : 'Play'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}