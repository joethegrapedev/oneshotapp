import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/doodles.dart';
import '../../widgets/hand_button.dart';
import '../../widgets/paper_scaffold.dart';

/// The first-run flow: value prop → 18+ age gate → Terms of Use acceptance.
///
/// The age gate and ToS acceptance cannot be skipped; both write to the
/// profile before the user is allowed onward to the (hard) paywall.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _step = 0;

  bool _ageDeclined = false;
  bool _tosChecked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).capture('onboard_start');
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmAge() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).confirmAge();
      if (!mounted) return;
      ref.read(analyticsServiceProvider).capture('age_confirmed');
      _goToStep(2);
    } catch (_) {
      _showError('Could not save that just now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptTos() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).acceptTos(Env.tosVersion);
      if (!mounted) return;
      ref.read(analyticsServiceProvider).capture('tos_accepted');
      await ref.read(appSessionProvider).refresh();
      if (!mounted) return;
      context.goNamed('paywall');
    } catch (_) {
      _showError('Could not save that just now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showError('Could not open the link.');
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      showAppBar: false,
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _step = i),
              children: [
                _ValueProp(onStart: () => _goToStep(1)),
                _AgeGate(
                  declined: _ageDeclined,
                  busy: _busy,
                  onConfirm: _confirmAge,
                  onDecline: () => setState(() => _ageDeclined = true),
                  onReconsider: () => setState(() => _ageDeclined = false),
                ),
                _TosStep(
                  checked: _tosChecked,
                  busy: _busy,
                  onChanged: (v) => setState(() => _tosChecked = v),
                  onAccept: _tosChecked ? _acceptTos : null,
                  onReadTos: () => _openUrl(Env.tosUrl),
                  onReadPrivacy: () => _openUrl(Env.privacyUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _StepDots(count: 3, index: _step),
          const SizedBox(height: AppSpace.md),
          TextButton(
            onPressed: () => context.goNamed('crisis'),
            child: Text(
              'Need support now?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.accent,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueProp extends StatelessWidget {
  const _ValueProp({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Center(child: DoodleIcon(Doodle.quill, size: 96)),
        const SizedBox(height: AppSpace.xl),
        Text('One Shot', style: text.displaySmall),
        const SizedBox(height: AppSpace.sm),
        Text(
          'A quiet place to write for yourself.',
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          'Everything you write stays private by default. When you feel like '
          'it, you can share one entry anonymously and read one from a '
          'stranger in return. No names, no profiles, no replies.',
          style: text.bodyLarge,
        ),
        const Spacer(),
        HandButton(
          label: 'Begin',
          icon: Icons.arrow_forward,
          onPressed: onStart,
        ),
      ],
    );
  }
}

class _AgeGate extends StatelessWidget {
  const _AgeGate({
    required this.declined,
    required this.busy,
    required this.onConfirm,
    required this.onDecline,
    required this.onReconsider,
  });

  final bool declined;
  final bool busy;
  final Future<void> Function() onConfirm;
  final VoidCallback onDecline;
  final VoidCallback onReconsider;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (declined) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(child: DoodleIcon(Doodle.moon, size: 88)),
          const SizedBox(height: AppSpace.xl),
          Text('Come back when you turn 18', style: text.headlineSmall),
          const SizedBox(height: AppSpace.md),
          Text(
            'One Shot is only available to people who are 18 or older. '
            'Thank you for your honesty.',
            style: text.bodyLarge,
          ),
          const Spacer(),
          HandButton(
            label: 'Go back',
            variant: HandButtonVariant.outline,
            onPressed: onReconsider,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Center(child: DoodleIcon(Doodle.spark, size: 88)),
        const SizedBox(height: AppSpace.xl),
        Text('A quick check', style: text.headlineSmall),
        const SizedBox(height: AppSpace.md),
        Text(
          'You must be 18 or older to use One Shot.',
          style: text.bodyLarge,
        ),
        const Spacer(),
        HandButton(
          label: 'I am 18 or older',
          loading: busy,
          onPressed: busy ? null : onConfirm,
        ),
        const SizedBox(height: AppSpace.sm),
        HandButton(
          label: "I'm under 18",
          variant: HandButtonVariant.quiet,
          onPressed: busy ? null : onDecline,
        ),
      ],
    );
  }
}

class _TosStep extends StatelessWidget {
  const _TosStep({
    required this.checked,
    required this.busy,
    required this.onChanged,
    required this.onAccept,
    required this.onReadTos,
    required this.onReadPrivacy,
  });

  final bool checked;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final Future<void> Function()? onAccept;
  final VoidCallback onReadTos;
  final VoidCallback onReadPrivacy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.lg),
        const Center(child: DoodleIcon(Doodle.heart, size: 80)),
        const SizedBox(height: AppSpace.lg),
        Text('Before you share', style: text.headlineSmall),
        const SizedBox(height: AppSpace.md),
        Text(
          'Sharing is a small community. Our Terms of Use define and prohibit '
          'objectionable content. You must accept them before you can create '
          'or share any entry.',
          style: text.bodyLarge,
        ),
        const SizedBox(height: AppSpace.lg),
        _LinkRow(label: 'Read Terms of Use', onTap: onReadTos),
        const SizedBox(height: AppSpace.sm),
        _LinkRow(label: 'Read Privacy Policy', onTap: onReadPrivacy),
        const SizedBox(height: AppSpace.lg),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: busy ? null : () => onChanged(!checked),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: checked,
                  onChanged:
                      busy ? null : (v) => onChanged(v ?? false),
                  activeColor: AppColors.accent,
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(
                    'I have read and accept the Terms of Use and Privacy '
                    'Policy.',
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        HandButton(
          label: 'Accept and continue',
          loading: busy,
          onPressed: onAccept,
        ),
        const SizedBox(height: AppSpace.lg),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(
          children: [
            const Icon(Icons.open_in_new, size: 18, color: AppColors.accent),
            const SizedBox(width: AppSpace.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accent,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent
                : AppColors.inkSoft.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
