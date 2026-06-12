import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/settings_provider.dart';
import '../../services/sync_service.dart';

final _dateFormat = DateFormat('yyyy年M月d日', 'zh_CN');

const _colorPalette = [
  0xFF1976D2, // 蓝
  0xFFE91E63, // 粉
  0xFF43A047, // 绿
  0xFFFF9800, // 橙
  0xFF9C27B0, // 紫
  0xFF00BCD4, // 青
  0xFFF44336, // 红
  0xFF795548, // 棕
  0xFF607D8B, // 蓝灰
  0xFF000000, // 黑
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // 宝宝信息
  final _babyNameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  DateTime? _birthday;

  // 记录人
  final _newAuthorCtrl = TextEditingController();

  // 同步
  final _urlCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _setupLoading = false;
  String? _setupResult;

  bool _profileDirty = false;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(settingsProvider);
      if (s.loaded && !_profileLoaded) _applySettings(s);
    });
  }

  void _applySettings(AppSettings s) {
    if (_profileLoaded) return;
    _profileLoaded = true;
    _babyNameCtrl.text = s.babyName;
    _birthday = s.babyBirthday;
    if (s.babyHeight != null) _heightCtrl.text = s.babyHeight!.toStringAsFixed(1);
    if (s.babyWeight != null) _weightCtrl.text = s.babyWeight!.toStringAsFixed(2);
    setState(() {});
  }

  @override
  void dispose() {
    _babyNameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _newAuthorCtrl.dispose();
    _urlCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    await ref.read(settingsProvider.notifier).save(
      babyName: _babyNameCtrl.text.trim(),
      babyBirthday: _birthday,
      babyHeight: double.tryParse(_heightCtrl.text),
      babyWeight: double.tryParse(_weightCtrl.text),
    );
    setState(() => _profileDirty = false);
    final sync = ref.read(syncServiceProvider.notifier);
    if (ref.read(syncServiceProvider).status == SyncStatus.connected) sync.syncAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() { _birthday = picked; _profileDirty = true; });
  }

  Future<void> _runSetup() async {
    if (_urlCtrl.text.trim().isEmpty || _adminEmailCtrl.text.trim().isEmpty || _adminPasswordCtrl.text.isEmpty) {
      setState(() => _setupResult = '请填写服务器地址和管理员账号');
      return;
    }
    setState(() { _setupLoading = true; _setupResult = null; });
    try {
      final result = await ref.read(syncServiceProvider.notifier).setupCollections(
        _urlCtrl.text.trim(), _adminEmailCtrl.text.trim(), _adminPasswordCtrl.text,
      );
      setState(() => _setupResult = result);
    } catch (e) {
      setState(() => _setupResult = e.toString());
    } finally {
      setState(() => _setupLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final syncState = ref.watch(syncServiceProvider);

    // 监听设置从 SharedPreferences 加载完成后填入表单（只填一次）
    ref.listen<AppSettings>(settingsProvider, (_, next) {
      if (!_profileLoaded && next.loaded) _applySettings(next);
    });

    // 服务器地址跟随连接状态自动填入
    if (_urlCtrl.text.isEmpty && syncState.serverUrl != null) {
      _urlCtrl.text = syncState.serverUrl!;
    }
    final syncService = ref.read(syncServiceProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 宝宝档案 ──
          _SectionHeader(icon: Icons.child_care, title: '宝宝档案'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _babyNameCtrl,
                    decoration: const InputDecoration(labelText: '宝宝名字', border: OutlineInputBorder(), prefixIcon: Icon(Icons.face)),
                    onChanged: (_) => setState(() => _profileDirty = true),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickBirthday,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '生日', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)),
                      child: Row(
                        children: [
                          Text(
                            _birthday != null ? _dateFormat.format(_birthday!) : '请选择',
                            style: TextStyle(color: _birthday == null ? colorScheme.onSurfaceVariant : null),
                          ),
                          const Spacer(),
                          if (settings.babyAge.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(settings.babyAge,
                                  style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightCtrl,
                          decoration: const InputDecoration(labelText: '身高 (cm)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.height)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() => _profileDirty = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _weightCtrl,
                          decoration: const InputDecoration(labelText: '体重 (kg)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.monitor_weight_outlined)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() => _profileDirty = true),
                        ),
                      ),
                    ],
                  ),
                  if (_profileDirty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存档案'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 记录人 ──
          _SectionHeader(icon: Icons.people_outline, title: '记录人'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前记录人', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: settings.authors.map((author) {
                      final selected = settings.currentAuthor == author;
                      final color = settings.colorFor(author);
                      return GestureDetector(
                        onTap: () => ref.read(settingsProvider.notifier).save(currentAuthor: author),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? color.withValues(alpha: 0.15) : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? color : colorScheme.outline.withValues(alpha: 0.3),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(author,
                            style: TextStyle(
                              color: selected ? color : colorScheme.onSurface,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('标签颜色', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  ...settings.authors.map((author) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(author, style: const TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 8,
                          children: _colorPalette.map((c) {
                            final current = settings.colorFor(author).value;
                            final isSelected = current == c;
                            return GestureDetector(
                              onTap: () {
                                final newColors = Map<String, int>.from(settings.authorColors);
                                newColors[author] = c;
                                ref.read(settingsProvider.notifier).save(authorColors: newColors);
                              },
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: Colors.black54, width: 2.5)
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newAuthorCtrl,
                          decoration: const InputDecoration(
                            hintText: '添加记录人（如：奶奶）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () {
                          final name = _newAuthorCtrl.text.trim();
                          if (name.isNotEmpty && !settings.authors.contains(name)) {
                            ref.read(settingsProvider.notifier).save(
                              authors: [...settings.authors, name],
                              currentAuthor: name,
                            );
                            _newAuthorCtrl.clear();
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (settings.authors.length > 2) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: settings.authors.skip(2).map((author) => InputChip(
                        label: Text(author),
                        onDeleted: () {
                          final newList = settings.authors.where((a) => a != author).toList();
                          final newCurrent = settings.currentAuthor == author
                              ? (newList.isNotEmpty ? newList.first : '')
                              : settings.currentAuthor;
                          ref.read(settingsProvider.notifier).save(authors: newList, currentAuthor: newCurrent);
                        },
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 局域网同步 ──
          _SectionHeader(icon: Icons.sync, title: '局域网同步'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusDot(status: syncState.status),
                      const SizedBox(width: 8),
                      Text(_statusLabel(syncState.status),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      if (syncState.lastSync != null) ...[
                        const Spacer(),
                        Text('上次：${_formatTime(syncState.lastSync!)}',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                  if (syncState.error != null) ...[
                    const SizedBox(height: 4),
                    Text(syncState.error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'http://192.168.1.100:2363',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 10),
                  if (syncState.status == SyncStatus.disconnected || syncState.status == SyncStatus.error)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => syncService.connect(_urlCtrl.text.trim()),
                        icon: const Icon(Icons.wifi),
                        label: const Text('连接'),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: syncState.status == SyncStatus.syncing ? null : () => syncService.syncAll(),
                            icon: syncState.status == SyncStatus.syncing
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.sync),
                            label: Text(syncState.status == SyncStatus.syncing ? '同步中...' : '立即同步'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: () => syncService.disconnect(), child: const Text('断开')),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 一键初始化（折叠）
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.build_outlined),
              title: const Text('首次初始化服务器'),
              subtitle: const Text('自动创建数据库集合', style: TextStyle(fontSize: 12)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _adminEmailCtrl,
                        decoration: const InputDecoration(
                          labelText: '管理员邮箱', border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined), isDense: true,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _adminPasswordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: '管理员密码', border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline), isDense: true,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _setupLoading ? null : _runSetup,
                          icon: _setupLoading
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.rocket_launch_outlined),
                          label: const Text('初始化集合'),
                        ),
                      ),
                      if (_setupResult != null) ...[
                        const SizedBox(height: 8),
                        _ResultBanner(message: _setupResult!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _statusLabel(SyncStatus s) => switch (s) {
    SyncStatus.disconnected => '未连接',
    SyncStatus.connecting => '连接中...',
    SyncStatus.connected => '已连接',
    SyncStatus.syncing => '同步中',
    SyncStatus.error => '连接失败',
  };

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    return '${diff.inHours}小时前';
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          )),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final SyncStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SyncStatus.connected || SyncStatus.syncing => Colors.green,
      SyncStatus.connecting => Colors.orange,
      SyncStatus.error => Colors.red,
      SyncStatus.disconnected => Colors.grey,
    };
    return Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _ResultBanner extends StatelessWidget {
  final String message;
  const _ResultBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isError = message.contains('失败') || message.contains('请填写');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 16, color: isError ? Colors.red : Colors.green),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
