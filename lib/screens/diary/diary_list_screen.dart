import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/diary_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_media_thumbnail.dart';

final _dateFormat = DateFormat('yyyy年M月d日', 'zh_CN');

class DiaryListScreen extends ConsumerStatefulWidget {
  const DiaryListScreen({super.key});

  @override
  ConsumerState<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends ConsumerState<DiaryListScreen> {
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

  List<DiaryEntry> _filter(List<DiaryEntry> list) {
    return list.where((d) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final inTitle = d.title?.toLowerCase().contains(q) ?? false;
        final inContent = d.content.toLowerCase().contains(q);
        if (!inTitle && !inContent) return false;
      }
      if (_fromDate != null && d.date.isBefore(_fromDate!)) return false;
      if (_toDate != null && d.date.isAfter(_toDate!.add(const Duration(days: 1)))) return false;
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
    final diaries = ref.watch(diaryListProvider);
    final hasDateFilter = _fromDate != null || _toDate != null;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: '搜索日记...', border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('宝宝日记'),
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
      body: diaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (all) {
          final list = _searching ? _filter(all) : all;
          if (all.isEmpty) {
            return _EmptyState(
              icon: Icons.book_outlined,
              message: '还没有日记，\n记录宝宝的第一个故事吧',
            );
          }
          if (list.isEmpty) {
            return const _EmptyState(icon: Icons.search_off, message: '没有匹配的日记');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) => _DiaryCard(diary: list[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/diary/new'),
        icon: const Icon(Icons.add),
        label: const Text('写日记'),
      ),
    );
  }
}

class _DiaryCard extends ConsumerWidget {
  final DiaryEntry diary;
  const _DiaryCard({required this.diary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(diaryPhotosProvider(diary.id));
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final authorColor = diary.author.isNotEmpty ? settings.colorFor(diary.author) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/diary/${diary.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _dateFormat.format(diary.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (diary.mood != null && diary.mood!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(diary.mood!, style: const TextStyle(fontSize: 18)),
                  ],
                  const Spacer(),
                  if (diary.author.isNotEmpty && authorColor != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: authorColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        diary.author,
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  photos.maybeWhen(
                    data: (p) => p.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.photo, size: 16, color: colorScheme.outline),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              if (diary.title != null && diary.title!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  diary.title!,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                diary.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
              photos.maybeWhen(
                data: (photoList) {
                  if (photoList.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photoList.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppMediaThumbnail(
                              photoList[i].localPath,
                              width: 70,
                              height: 70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
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
          Icon(icon, size: 72, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            message,
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
