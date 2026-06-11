import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../db/database.dart';
import '../../providers/diary_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/media_utils.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_media_thumbnail.dart';
import '../../widgets/comment_section.dart';

final _dateFormat = DateFormat('yyyy年M月d日 EEEE', 'zh_CN');

final _diaryByIdProvider = FutureProvider.family<DiaryEntry?, String>((ref, id) {
  return ref.watch(databaseProvider).getDiaryById(id);
});

class DiaryDetailScreen extends ConsumerWidget {
  final String id;
  const DiaryDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(_diaryByIdProvider(id));
    final photos = ref.watch(diaryPhotosProvider(id));

    return diary.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (entry) {
        if (entry == null) {
          return const Scaffold(body: Center(child: Text('日记不存在')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(entry.title ?? _dateFormat.format(entry.date)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/diary/${entry.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref, entry),
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
                    Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      _dateFormat.format(entry.date),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.mood != null && entry.mood!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(entry.mood!, style: const TextStyle(fontSize: 20)),
                    ],
                    const Spacer(),
                    if (entry.author.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(entry.author,
                            style: TextStyle(fontSize: 12,
                                color: Theme.of(context).colorScheme.onSecondaryContainer)),
                      ),
                  ],
                ),
                if (entry.title != null && entry.title!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    entry.title!,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 12),
                Text(entry.content, style: const TextStyle(fontSize: 16, height: 1.8)),
                photos.maybeWhen(
                  data: (photoList) {
                    if (photoList.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '照片 / 视频',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: photoList.length,
                          itemBuilder: (context, i) => GestureDetector(
                            onTap: () => _viewMedia(context, photoList, i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppMediaThumbnail(photoList[i].localPath),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                CommentSection(parentId: entry.id, parentType: 'diary'),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewMedia(BuildContext context, List<DiaryPhoto> photos, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _MediaViewScreen(photos: photos, initialIndex: index),
    ));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, DiaryEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除日记'),
        content: const Text('确定要删除这篇日记吗？此操作不可恢复。'),
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
      await ref.read(diaryNotifierProvider.notifier).deleteDiary(entry.id);
      if (context.mounted) context.pop();
    }
  }
}

class _MediaViewScreen extends StatefulWidget {
  final List<DiaryPhoto> photos;
  final int initialIndex;
  const _MediaViewScreen({required this.photos, required this.initialIndex});

  @override
  State<_MediaViewScreen> createState() => _MediaViewScreenState();
}

class _MediaViewScreenState extends State<_MediaViewScreen> {
  late int _currentIndex;
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemCount: widget.photos.length,
        itemBuilder: (context, i) {
          final path = widget.photos[i].localPath;
          if (isVideo(path)) {
            return _InlineVideoPlayer(path: path);
          }
          return InteractiveViewer(
            child: Center(
              child: AppImage(path, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final String path;
  const _InlineVideoPlayer({required this.path});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.path.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
        : VideoPlayerController.file(File(widget.path));
    _ctrl.initialize().then((_) {
      if (mounted) {
        setState(() => _ready = true);
        _ctrl.play();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() {
        _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
      }),
      child: Center(
        child: _ready
            ? AspectRatio(
                aspectRatio: _ctrl.value.aspectRatio,
                child: VideoPlayer(_ctrl),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
