import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../providers/comment_provider.dart';
import '../providers/settings_provider.dart';

final _timeFormat = DateFormat('MM-dd HH:mm', 'zh_CN');

class CommentSection extends ConsumerStatefulWidget {
  final String parentId;
  final String parentType;

  const CommentSection({
    super.key,
    required this.parentId,
    required this.parentType,
  });

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final author = ref.read(settingsProvider).currentAuthor;
    await ref.read(commentNotifierProvider.notifier).addComment(
      parentId: widget.parentId,
      parentType: widget.parentType,
      content: text,
      author: author,
    );
    _ctrl.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.parentId));
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('评论', style: Theme.of(context).textTheme.titleMedium),
        ),
        commentsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '还没有评论',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              );
            }
            return Column(
              children: list.map((c) => _CommentTile(
                comment: c,
                settings: settings,
                onDelete: () => ref.read(commentNotifierProvider.notifier).deleteComment(c),
              )).toList(),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: '写评论...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final AppSettings settings;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.settings,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authorColor = comment.author.isNotEmpty ? settings.colorFor(comment.author) : null;
    final isOwn = comment.author == settings.currentAuthor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (comment.author.isNotEmpty && authorColor != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: authorColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          comment.author,
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _timeFormat.format(comment.createdAt),
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOwn
                        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(comment.content, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
          if (isOwn)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.onSurfaceVariant),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
