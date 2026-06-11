import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/milestone_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/comment_section.dart';

final _dateFormat = DateFormat('yyyy年M月d日', 'zh_CN');

const _categoryIcons = {
  'movement': Icons.directions_run,
  'speech': Icons.record_voice_over,
  'social': Icons.people,
  'cognitive': Icons.lightbulb,
  'other': Icons.star,
};

const _categoryColors = {
  'movement': Color(0xFF4CAF50),
  'speech': Color(0xFF2196F3),
  'social': Color(0xFFE91E63),
  'cognitive': Color(0xFFFF9800),
  'other': Color(0xFF9C27B0),
};

class MilestoneDetailScreen extends ConsumerWidget {
  final Milestone milestone;
  const MilestoneDetailScreen({super.key, required this.milestone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final icon = _categoryIcons[milestone.category] ?? Icons.star;
    final color = _categoryColors[milestone.category] ?? const Color(0xFF9C27B0);
    final categoryLabel = milestoneCategories[milestone.category] ?? '其他';
    final authorColor = milestone.author.isNotEmpty ? settings.colorFor(milestone.author) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(milestone.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              context.pop();
              context.push('/milestone/${milestone.id}/edit');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(categoryLabel,
                              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                        ),
                        if (milestone.author.isNotEmpty && authorColor != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: authorColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(milestone.author,
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_dateFormat.format(milestone.date),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ],
            ),
            if (milestone.localPhotoPath != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(milestone.localPhotoPath!, width: double.infinity, height: 220),
              ),
            ],
            if (milestone.description != null && milestone.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(milestone.description!, style: const TextStyle(fontSize: 15, height: 1.7)),
            ],
            const SizedBox(height: 20),
            CommentSection(parentId: milestone.id, parentType: 'milestone'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除里程碑'),
        content: const Text('确定要删除这条里程碑吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(milestoneNotifierProvider.notifier).deleteMilestone(milestone);
      if (context.mounted) context.pop();
    }
  }
}
