import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';

class OpportunityMiniCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;

  const OpportunityMiniCard({super.key, required this.data, required this.index});

  @override
  State<OpportunityMiniCard> createState() => _OpportunityMiniCardState();
}

class _OpportunityMiniCardState extends State<OpportunityMiniCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final probability = (widget.data['probability'] as double);
    final isNew = widget.data['isNew'] as bool;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/opportunities/${widget.data['id']}'),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
          child: GlassCard(
            borderColor: _isHovered ? AppColors.primary : null,
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getCategoryGradient(widget.data['category']),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _getCategoryEmoji(widget.data['category']),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isNew) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: AppColors.goldGradient),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'NEW',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              widget.data['title'],
                              style: AppTextStyles.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.data['amount'],
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(' • ', style: AppTextStyles.caption),
                          const Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 2),
                          Text(
                            widget.data['deadline'],
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.md),

                // Probability ring
                Column(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        children: [
                          CircularProgressIndicator(
                            value: probability,
                            backgroundColor: AppColors.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getProbabilityColor(probability),
                            ),
                            strokeWidth: 3,
                          ),
                          Center(
                            child: Text(
                              '${(probability * 100).toInt()}%',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: _getProbabilityColor(probability),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('success', style: AppTextStyles.caption.copyWith(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: widget.index * 100)).slideX(begin: 0.2);
  }

  Color _getProbabilityColor(double p) {
    if (p >= 0.7) return AppColors.success;
    if (p >= 0.4) return AppColors.warning;
    return AppColors.error;
  }

  List<Color> _getCategoryGradient(String category) {
    switch (category.toLowerCase()) {
      case 'scholarship': return AppColors.primaryGradient;
      case 'state scholarship': return AppColors.successGradient;
      case 'central govt': return AppColors.goldGradient;
      default: return AppColors.primaryGradient;
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'scholarship': return '🎓';
      case 'state scholarship': return '📜';
      case 'central govt': return '🏛️';
      case 'fellowship': return '🔬';
      case 'job': return '💼';
      default: return '📋';
    }
  }
}
