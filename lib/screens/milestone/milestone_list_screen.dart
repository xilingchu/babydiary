import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/milestone_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_image.dart';
import 'milestone_detail_screen.dart';

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

class MilestoneListScreen extends ConsumerStatefulWidget {
  const MilestoneListScreen({super.key});

  @override
  ConsumerState<MilestoneListScreen> createState() => _MilestoneListScreenState();
}

class _MilestoneListScreenState extends ConsumerState<MilestoneListScreen> {
  bool _searching = false;
  String _query = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Milestone> _filter(List<Milestone> list) {
    return list.where((m) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final inTitle = m.title.toLowerCase().contains(q);
        final inDesc = m.description?.toLowerCase().contains(q) ?? false;
        if (!inTitle && !inDesc) return false;
      }
      if (_fromDate != null && m.date.isBefore(_fromDate!)) return false;
      if (_toDate != null && m.date.isAfter(_toDate!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (picked != null) {
      setState(() { _fromDate = picked.start; _toDate = picked.end; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final milestones = ref.watch(milestoneListProvider);
    final hasDateFilter = _fromDate != null || _toDate != null;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: '搜索里程碑...', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('成长里程碑'),
        actions: [
          if (_searching) ...[
            if (hasDateFilter)
              IconButton(
                icon: const Icon(Icons.date_range, color: Colors.orange),
                tooltip: '清除日期筛选',
                onPressed: () => setState(() { _fromDate = null; _toDate = null; }),
              )
            else
              IconButton(
                icon: const Icon(Icons.date_range),
                tooltip: '按日期范围筛选',
                onPressed: _pickDateRange,
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _searching = false;
                _query = '';
                _fromDate = null;
                _toDate = null;
                _searchCtrl.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: '同步设置',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ],
      ),
      body: milestones.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (all) {
          final list = _searching ? _filter(all) : all;
          if (all.isEmpty) return const _EmptyMilestones();
          if (list.isEmpty) {
            return const _EmptyState(icon: Icons.search_off, message: '没有匹配的里程碑');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) => _MilestoneCard(milestone: list[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/milestone/new'),
        icon: const Icon(Icons.add),
        label: const Text('添加里程碑'),
      ),
    );
  }
}

class _MilestoneCard extends ConsumerWidget {
  final Milestone milestone;
  const _MilestoneCard({required this.milestone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _categoryIcons[milestone.category] ?? Icons.star;
    final color = _categoryColors[milestone.category] ?? const Color(0xFF9C27B0);
    final categoryLabel = milestoneCategories[milestone.category] ?? '其他';
    final settings = ref.watch(settingsProvider);
    final authorColor = milestone.author.isNotEmpty ? settings.colorFor(milestone.author) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MilestoneDetailScreen(milestone: milestone),
        )),
        onLongPress: () => _showOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            categoryLabel,
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _dateFormat.format(milestone.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (milestone.author.isNotEmpty && authorColor != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: authorColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              milestone.author,
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      milestone.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (milestone.description != null && milestone.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        milestone.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (milestone.localPhotoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(milestone.localPhotoPath!, width: 60, height: 60),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/milestone/${milestone.id}/edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(milestoneNotifierProvider.notifier).deleteMilestone(milestone);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _EmptyMilestones extends StatelessWidget {
  const _EmptyMilestones();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌟', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            '记录宝宝的每一个\n成长里程碑',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
