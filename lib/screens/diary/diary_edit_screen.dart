import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/diary_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/sync_service.dart';
import '../../widgets/app_image.dart';

final _dateFormat = DateFormat('yyyy年M月d日', 'zh_CN');

const _moods = ['😊', '😄', '😢', '😴', '🤒', '🎉', '❤️', '🌟'];

class DiaryEditScreen extends ConsumerStatefulWidget {
  final String? diaryId;
  const DiaryEditScreen({super.key, this.diaryId});

  @override
  ConsumerState<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends ConsumerState<DiaryEditScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _mood;
  List<XFile> _newPhotos = [];
  List<DiaryPhoto> _existingPhotos = [];
  bool _loading = true;
  DiaryEntry? _existing;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.diaryId != null) {
      final db = ref.read(databaseProvider);
      _existing = await db.getDiaryById(widget.diaryId!);
      if (_existing != null) {
        _titleCtrl.text = _existing!.title ?? '';
        _contentCtrl.text = _existing!.content;
        _date = _existing!.date;
        _mood = _existing!.mood;
        _existingPhotos = await db.getPhotosForDiary(widget.diaryId!);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _newPhotos.addAll(images));
    }
  }

  Future<void> _save() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请写点什么吧')),
      );
      return;
    }

    final notifier = ref.read(diaryNotifierProvider.notifier);
    final author = ref.read(settingsProvider).currentAuthor;
    final id = await notifier.saveDiary(
      existingId: widget.diaryId,
      date: _date,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      mood: _mood,
      author: author,
      newPhotos: _newPhotos,
    );

    if (mounted) {
      if (widget.diaryId != null) {
        context.pop();
      } else {
        context.pushReplacement('/diary/$id');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.diaryId == null ? '写日记' : '编辑日记'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: colorScheme.onPrimaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      _dateFormat.format(_date),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Mood selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _moods.map((m) => GestureDetector(
                  onTap: () => setState(() => _mood = _mood == m ? null : m),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _mood == m ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: _mood == m
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Text(m, style: const TextStyle(fontSize: 24)),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: '标题（可选）',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 20),
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textInputAction: TextInputAction.next,
            ),

            // Content
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                hintText: '今天宝宝...',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 16),
              ),
              style: const TextStyle(fontSize: 16, height: 1.8),
              maxLines: null,
              minLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Photos section
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('照片', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('添加照片'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Existing photos
            if (_existingPhotos.isNotEmpty) ...[
              _PhotoGrid(
                paths: _existingPhotos.map((p) => p.localPath).toList(),
                onRemove: (index) {
                  final photo = _existingPhotos[index];
                  ref.read(diaryNotifierProvider.notifier).deletePhoto(photo);
                  setState(() => _existingPhotos.removeAt(index));
                },
              ),
              const SizedBox(height: 8),
            ],

            // New photos
            if (_newPhotos.isNotEmpty)
              _PhotoGrid(
                paths: _newPhotos.map((f) => f.path).toList(),
                onRemove: (index) => setState(() => _newPhotos.removeAt(index)),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<String> paths;
  final void Function(int index) onRemove;
  const _PhotoGrid({required this.paths, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: paths.asMap().entries.map((e) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AppImage(e.value, width: 90, height: 90),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => onRemove(e.key),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
