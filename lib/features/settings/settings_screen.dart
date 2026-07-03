import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/hand_button.dart';
import '../../widgets/paper_scaffold.dart';

/// A calm settings list: account deletion, blocked writers, support, restore,
/// and legal links. Nothing here ever reveals another user's identity.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loadingBlocks = true;
  bool _working = false;
  List<String> _blockedIds = const [];

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadBlocks() async {
    setState(() => _loadingBlocks = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) {
          setState(() {
            _blockedIds = const [];
            _loadingBlocks = false;
          });
        }
        return;
      }
      final rows = await client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);
      final ids = (rows as List)
          .map((r) => (r as Map)['blocked_id'] as String?)
          .whereType<String>()
          .toList();
      if (!mounted) return;
      setState(() {
        _blockedIds = ids;
        _loadingBlocks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _blockedIds = const [];
        _loadingBlocks = false;
      });
    }
  }

  Future<void> _unblock(String blockedId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;
      await client
          .from('blocks')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', blockedId);
      if (!mounted) return;
      setState(() {
        _blockedIds = _blockedIds.where((id) => id != blockedId).toList();
      });
      _snack('Unblocked');
    } catch (_) {
      _snack('Could not unblock right now.');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes your account, your private entries, and '
          'any entries you shared into the pool. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _working = true);
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      await ref.read(authRepositoryProvider).signOut();
      await ref.read(appSessionProvider).refresh();
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      _snack('Could not delete your account right now.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _working = true);
    try {
      final ok = await ref.read(purchasesServiceProvider).restore();
      _snack(ok ? 'Purchases restored' : 'No purchases to restore.');
    } catch (_) {
      _snack('Could not restore right now.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openUrl(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Could not open that.');
  }

  Future<void> _emailSupport() async {
    final uri = Uri(scheme: 'mailto', path: Env.supportEmail);
    final ok = await launchUrl(uri);
    if (!ok) _snack('Could not open your email app.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return PaperScaffold(
      title: 'Settings',
      scroll: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.goNamed('journal'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader('Blocked writers'),
          _BlockedList(
            loading: _loadingBlocks,
            blockedIds: _blockedIds,
            onUnblock: _working ? null : _unblock,
          ),
          const SizedBox(height: AppSpace.xl),
          const _SectionHeader('Support'),
          _Tile(
            icon: Icons.mail_outline,
            title: 'Contact support',
            subtitle: Env.supportEmail,
            onTap: _emailSupport,
          ),
          const SizedBox(height: AppSpace.xl),
          const _SectionHeader('Subscription'),
          HandButton(
            label: 'Restore Purchases',
            variant: HandButtonVariant.outline,
            onPressed: _working ? null : _restore,
          ),
          const SizedBox(height: AppSpace.xl),
          const _SectionHeader('Legal'),
          _Tile(
            icon: Icons.description_outlined,
            title: 'Terms of Use',
            onTap: () => _openUrl(Uri.parse(Env.tosUrl)),
          ),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _openUrl(Uri.parse(Env.privacyUrl)),
          ),
          const SizedBox(height: AppSpace.xl),
          const _SectionHeader('Account'),
          Text(
            'Deleting your account permanently purges your entries, including '
            'anything you shared.',
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpace.md),
          HandButton(
            label: 'Delete account',
            variant: HandButtonVariant.outline,
            icon: Icons.delete_outline,
            loading: _working,
            onPressed: _working ? null : _confirmDelete,
          ),
          const SizedBox(height: AppSpace.xl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Text(label, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _BlockedList extends StatelessWidget {
  const _BlockedList({
    required this.loading,
    required this.blockedIds,
    required this.onUnblock,
  });

  final bool loading;
  final List<String> blockedIds;
  final void Function(String blockedId)? onUnblock;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (blockedIds.isEmpty) {
      return Text('No one blocked', style: text.bodyMedium);
    }
    return Column(
      children: [
        for (final id in blockedIds)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Row(
              children: [
                const Icon(
                  Icons.person_off_outlined,
                  color: AppColors.inkSoft,
                  size: 22,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text('Blocked writer', style: text.titleMedium),
                ),
                HandButton(
                  label: 'Unblock',
                  variant: HandButtonVariant.quiet,
                  expand: false,
                  onPressed: onUnblock == null ? null : () => onUnblock!(id),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Icon(icon, color: AppColors.ink, size: 22),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  if (subtitle != null) Text(subtitle!, style: text.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
