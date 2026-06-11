import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/milestone_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/sync_service.dart';
import '../../widgets/app_image.dart';

final _dateFormat = DateFormat('yyyy年M月d日', 'zh_CN');

class MilestoneEditScreen extends ConsumerStatefulWidget {
  final String? milestoneId;
  const MilestoneEditScreen({super.key, this.milestoneId});

  @override
  ConsumerState<MilestoneEditScreen> createState() => _MilestoneEditScreenState();
}

class _MilestoneEditScreenState extends ConsumerState<MilestoneEditScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = 'other';
  XFile? _newPhoto;
  String? _existingPhotoPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.milestoneId != null) {
      final db = ref.read(databaseProvider);
      final all = await db.getAllMilestones();
      final milestone = all.where((m) => m.id == widget.milestoneId).firstOrNull;
      if (milestone != null) {
        _titleCtrl.text = milestone.title;
        _descCtrl.text = milestone.description ?? '';
        _date = milestone.date;
        _category = milestone.category;
        _existingPhotoPath = milestone.localPhotoPath;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
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

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _newPhoto = image);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写里程碑标题')),
      );
      return;
    }

    final author = ref.read(settingsProvider).currentAuthor;
    await ref.read(milestoneNotifierProvider.notifier).saveMilestone(
          existingId: widget.milestoneId,
          date: _date,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          category: _category,
          author: author,
          photo: _newPhoto,
        );

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.milestoneId == null ? '添加里程碑' : '编辑里程碑'),
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
            // Date
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
            const SizedBox(height: 16),

            // Category
            Text('分类', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: milestoneCategories.entries.map((e) {
                final selected = _category == e.key;
                return ChoiceChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = e.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '里程碑标题 *',
                hintText: '例如：第一次翻身、叫了第一声妈妈',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                hintText: '记录更多细节...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),

            // Photo
            const Divider(),
            const SizedBox(height: 8),
            Text('照片（可选）', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_newPhoto != null)
              _PhotoPreview(
                path: _newPhoto!.path,
                onRemove: () => setState(() => _newPhoto = null),
              )
            else if (_existingPhotoPath != null)
              _PhotoPreview(
                path: _existingPhotoPath!,
                onRemove: () => setState(() => _existingPhotoPath = null),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('选择照片'),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _PhotoPreview({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AppImage(path, height: 180, width: double.infinity),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
