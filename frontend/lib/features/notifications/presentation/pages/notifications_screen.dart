import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/glassmorphism_card.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String? type) {
    switch (type) {
      case 'new_opportunity': return Icons.campaign_outlined;
      case 'document_expiry': return Icons.warning_amber_rounded;
      default: return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationActionsProvider.notifier).markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load notifications: $e', style: AppTextStyles.bodyMedium),
        ),
        data: (data) {
          final notifications = (data['notifications'] as List? ?? []).cast<Map<String, dynamic>>();
          if (notifications.isEmpty) {
            return Center(
              child: Text('No notifications yet.', style: AppTextStyles.bodyMedium),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.xl),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final n = notifications[i];
              final isUnread = n['read_at'] == null;
              return GlassCard(
                borderColor: isUnread ? AppColors.primary : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(n['type'] as String?), color: isUnread ? AppColors.primaryLight : AppColors.textMuted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n['title']?.toString() ?? '', style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                          )),
                          const SizedBox(height: 4),
                          Text(n['body']?.toString() ?? '', style: AppTextStyles.caption),
                          const SizedBox(height: 4),
                          Text(n['created_at']?.toString() ?? '', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (isUnread)
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        onPressed: () => ref.read(notificationActionsProvider.notifier).markRead(n['id'].toString()),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
