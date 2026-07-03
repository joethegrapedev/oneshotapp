import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/served_entry.dart';
import '../../widgets/doodles.dart';
import '../../widgets/hand_button.dart';
import '../../widgets/paper_scaffold.dart';

/// Reads back ONE stranger's already-cleared entry from the pool.
///
/// Anonymous: the author's identity is never shown; `authorId` is used only to
/// Block. Report and Block are two distinct, separately-labelled actions with
/// two different outcomes (Google Play UGC requirement).
class ReadBackScreen extends ConsumerStatefulWidget {
  const ReadBackScreen({super.key});

  @override
  ConsumerState<ReadBackScreen> createState() => _ReadBackScreenState();
}

class _ReadBackScreenState extends ConsumerState<ReadBackScreen> {
  Future<ServedEntry?>? _served;

  @override
  void initState() {
    super.initState();
    _served = ref.read(poolRepositoryProvider).serveOne();
  }

  void _serveNext() {
    setState(() {
      _served = ref.read(poolRepositoryProvider).serveOne();
    });
  }

  Future<void> _report(ServedEntry entry) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => const _ReportReasonSheet(),
    );
    if (reason == null || reason.isEmpty) return;
    if (!mounted) return;

    try {
      await ref.read(poolRepositoryProvider).report(entry.id, reason);
    } catch (_) {
      if (!mounted) return;
      _showSnack("Couldn't send your report. Please try again.");
      return;
    }
    if (!mounted) return;
    _showSnack('Reported. We review within 24 hours.');
    _serveNext();
  }

  Future<void> _block(ServedEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text(
          'Block this writer?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          "You won't be shown entries from this writer again. "
          'This is separate from reporting the entry.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Block',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await ref.read(poolRepositoryProvider).block(entry.authorId);
    } catch (_) {
      if (!mounted) return;
      _showSnack("Couldn't block right now. Please try again.");
      return;
    }
    if (!mounted) return;
    _showSnack("You won't see their entries again.");
    _serveNext();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      title: 'Read one',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back to journal',
        onPressed: () => context.goNamed('journal'),
      ),
      child: FutureBuilder<ServedEntry?>(
        future: _served,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snapshot.hasError) {
            return _ColdStart(
              message:
                  "Something went wrong finding an entry. Please try again.",
              onBack: () => context.goNamed('journal'),
              onRetry: _serveNext,
            );
          }
          final entry = snapshot.data;
          if (entry == null) {
            // Cold start — never fabricate or seed fake entries.
            return _ColdStart(
              message:
                  'No entries to read just yet. Yours may be the first.\n'
                  'Check back soon.',
              onBack: () => context.goNamed('journal'),
              onRetry: _serveNext,
            );
          }
          return _EntryView(
            entry: entry,
            onReport: () => _report(entry),
            onBlock: () => _block(entry),
            onReadAnother: _serveNext,
          );
        },
      ),
    );
  }
}

class _EntryView extends StatelessWidget {
  const _EntryView({
    required this.entry,
    required this.onReport,
    required this.onBlock,
    required this.onReadAnother,
  });

  final ServedEntry entry;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onReadAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: AppColors.paperShade,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.accentSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(entry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(entry.body, style: AppTypography.writing()),
                  const SizedBox(height: AppSpace.md),
                  const Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.inkSoft,
                      ),
                      SizedBox(width: AppSpace.xs),
                      Text(
                        'From someone, anonymously',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        HandButton(
          label: 'Read another',
          icon: Icons.refresh,
          onPressed: onReadAnother,
        ),
        const SizedBox(height: AppSpace.lg),
        // Two clearly-distinct safety actions with two different outcomes.
        Text(
          'Keep this space safe',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HandButton(
                    label: 'Report',
                    icon: Icons.flag_outlined,
                    variant: HandButtonVariant.outline,
                    onPressed: onReport,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Flag this entry for review.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HandButton(
                    label: 'Block writer',
                    icon: Icons.block,
                    variant: HandButtonVariant.quiet,
                    onPressed: onBlock,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Never see this writer again.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A bottom sheet to pick a report reason. Returns the chosen reason string.
class _ReportReasonSheet extends StatelessWidget {
  const _ReportReasonSheet();

  static const List<String> _reasons = [
    'Harmful/self-harm',
    'Sexual',
    'Harassment/hate',
    'Personal info',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.md),
            for (final reason in _reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  reason,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.inkSoft,
                ),
                onTap: () => Navigator.of(context).pop(reason),
              ),
          ],
        ),
      ),
    );
  }
}

class _ColdStart extends StatelessWidget {
  const _ColdStart({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DoodleIcon(Doodle.moon, size: 96, color: AppColors.accent),
              const SizedBox(height: AppSpace.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpace.xl),
              HandButton(
                label: 'Back to journal',
                onPressed: onBack,
              ),
              const SizedBox(height: AppSpace.sm),
              HandButton(
                label: 'Try again',
                variant: HandButtonVariant.outline,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
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
