import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/moderation_outcome.dart';
import '../../widgets/hand_button.dart';
import '../../widgets/paper_scaffold.dart';
import '../../widgets/warning_banner.dart';

/// The paper writing surface. Two intents: keep an entry fully private, or
/// stage it for the anonymous exchange (which runs the server moderation gate).
class WriteScreen extends ConsumerStatefulWidget {
  const WriteScreen({super.key});

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _savingPrivate = false;
  bool _sharing = false;

  bool get _busy => _savingPrivate || _sharing;
  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _keepPrivate() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _savingPrivate = true);
    try {
      await ref
          .read(entriesRepositoryProvider)
          .saveDraft(body: text, private: true);
      if (!mounted) return;
      _snack('Saved privately');
      context.goNamed('journal');
    } catch (_) {
      _snack('Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _savingPrivate = false);
    }
  }

  Future<void> _shareAndRead() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _sharing = true);
    try {
      // a. Optional, advisory on-device pre-check. Decides nothing.
      final proceed = await _runPrecheck(text);
      if (!proceed) return;

      // b. Stage the entry for sharing (visibility=shared, status=pending).
      final entry = await ref
          .read(entriesRepositoryProvider)
          .saveDraft(body: text, private: false);
      if (!mounted) return;

      // c. Authoritative server gate.
      final outcome = await ref
          .read(moderationRepositoryProvider)
          .submitForSharing(entry.id);
      if (!mounted) return;

      // d. Branch on the gate's decision.
      await _handleOutcome(outcome);
    } catch (_) {
      _snack('Could not share right now. Please try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Returns true if sharing should proceed. The pre-check is advisory only.
  Future<bool> _runPrecheck(String text) async {
    final precheck = ref.read(precheckServiceProvider);
    try {
      if (!await precheck.isAvailable()) return true;
      final result = await precheck.classify(text);
      if (!result.tripped) return true;
      if (!mounted) return false;
      final categories = result.categories.isEmpty
          ? 'sensitive content'
          : result.categories.join(', ');
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.paper,
          title: const Text('A gentle heads-up'),
          content: Text(
            'This may contain $categories. You can still save it privately, '
            'but it may not be shared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Share anyway'),
            ),
          ],
        ),
      );
      return go ?? false;
    } catch (_) {
      // If the pre-check misbehaves, never block the user.
      return true;
    }
  }

  Future<void> _handleOutcome(ModerationOutcome outcome) async {
    switch (outcome.status) {
      case GateStatus.clean:
        _snack("Shared. Here's one from someone else.");
        context.goNamed('read');
      case GateStatus.heldSelfharm:
        // Entry stays private server-side; route to support resources.
        context.goNamed('crisis');
      case GateStatus.heldPii:
        await _showPiiDialog();
      case GateStatus.rejected:
      case GateStatus.rejectedObjectionable:
        await _showRejectedDialog(outcome.message);
    }
  }

  Future<void> _showPiiDialog() async {
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('Remove personal details?'),
        content: const Text(
          'This entry seems to include identifying details (like a name, '
          'phone, or address). Please remove them before sharing. It has been '
          'kept private for now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('private'),
            child: const Text('Keep private'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('edit'),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result == 'private') {
      _snack('Kept private');
      context.goNamed('journal');
    }
    // 'edit' (or dismissed) → stay on the writing surface.
  }

  Future<void> _showRejectedDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text("This can't be shared"),
        content: Text(
          message.isEmpty
              ? 'This entry cannot be shared, but it has been saved privately '
                  'for you.'
              : message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.goNamed('journal');
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      title: 'Write',
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _busy ? null : () => context.goNamed('journal'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_sharing) ...[
            const WarningBanner(
              message: 'Checking your entry before sharing…',
            ),
            const SizedBox(height: AppSpace.md),
          ],
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_busy,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: AppTypography.writing(),
              cursorColor: AppColors.accent,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Write freely…',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          HandButton(
            label: 'Keep private',
            variant: HandButtonVariant.outline,
            icon: Icons.lock_outline,
            loading: _savingPrivate,
            onPressed: (!_hasText || _busy) ? null : _keepPrivate,
          ),
          const SizedBox(height: AppSpace.sm),
          HandButton(
            label: 'Share & read one',
            icon: Icons.swap_horiz,
            loading: _sharing,
            onPressed: (!_hasText || _busy) ? null : _shareAndRead,
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }
}
