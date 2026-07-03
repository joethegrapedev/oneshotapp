import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/entry.dart';
import '../../widgets/doodles.dart';
import '../../widgets/hand_button.dart';
import '../../widgets/paper_scaffold.dart';

/// Home screen: the writer's own private journal.
///
/// Lists the current user's entries (never fabricates any), offers Write and
/// Read-one actions, a body search, and a small per-entry state indicator.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<List<Entry>>? _entriesFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _entriesFuture =
        ref.read(entriesRepositoryProvider).myEntries(search: _query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _entriesFuture =
          ref.read(entriesRepositoryProvider).myEntries(search: _query);
    });
  }

  void _onSearchChanged(String value) {
    _query = value;
    _reload();
  }

  Future<void> _refresh() async {
    final future = ref.read(entriesRepositoryProvider).myEntries(search: _query);
    setState(() => _entriesFuture = future);
    await future;
  }

  void _openEntry(Entry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusChip(entry: entry),
                const SizedBox(height: AppSpace.sm),
                Text(
                  _formatDate(entry.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      entry.body,
                      style: AppTypography.writing(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                HandButton(
                  label: 'Close',
                  variant: HandButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      title: 'One Shot',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => context.goNamed('settings'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: HandButton(
                  label: 'Write',
                  icon: Icons.edit_outlined,
                  onPressed: () => context.goNamed('write'),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: HandButton(
                  label: 'Read one',
                  icon: Icons.auto_stories_outlined,
                  variant: HandButtonVariant.outline,
                  onPressed: () => context.goNamed('read'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          _SearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: AppSpace.md),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _refresh,
              child: FutureBuilder<List<Entry>>(
                future: _entriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    );
                  }
                  if (snapshot.hasError) {
                    return const _MessageState(
                      doodle: Doodle.folder,
                      message:
                          "Couldn't load your journal. Pull down to try again.",
                    );
                  }
                  final entries = snapshot.data ?? const <Entry>[];
                  if (entries.isEmpty) {
                    return _MessageState(
                      doodle: Doodle.sprout,
                      message: _query.trim().isEmpty
                          ? 'Your journal is empty.\nWrite your first entry.'
                          : 'No entries match "$_query".',
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpace.sm),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _EntryCard(
                        entry: entry,
                        onTap: () => _openEntry(entry),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.paperShade,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.inkSoft),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search your entries',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: AppSpace.sm + 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paperShade,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.body.trim().isEmpty ? '(empty entry)' : entry.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  Text(
                    _formatDate(entry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  _StatusChip(entry: entry),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    // In-pool takes precedence, then private intent, then everything else
    // (pending / held / rejected) reads as a muted "Not shared".
    final IconData icon;
    final String label;
    final Color color;
    if (entry.isInPool) {
      icon = Icons.public;
      label = 'Shared';
      color = AppColors.accent;
    } else if (entry.isPrivate) {
      icon = Icons.lock_outline;
      label = 'Private';
      color = AppColors.inkSoft;
    } else {
      icon = Icons.schedule;
      label = 'Not shared';
      color = AppColors.inkSoft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs / 2 + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpace.xs / 2 + 1),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.doodle, required this.message});

  final Doodle doodle;
  final String message;

  @override
  Widget build(BuildContext context) {
    // Wrapped in a scrollable so pull-to-refresh still works when empty.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DoodleIcon(doodle, size: 88, color: AppColors.accent),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Tiny local date formatter (no intl dependency): e.g. "3 Jul 2026".
String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final month = _monthNames[local.month - 1];
  return '${local.day} $month ${local.year}';
}
