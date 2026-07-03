import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/doodles.dart';
import '../../widgets/hand_button.dart';
import '../../widgets/paper_scaffold.dart';

/// The hard paywall. The whole app is gated behind the `pro` entitlement.
///
/// Prices are never hardcoded — they come from RevenueCat's localized
/// `StoreProduct.priceString` (SGD for the Singapore launch). Yearly leads.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = true;
  bool _working = false;
  Package? _weekly;
  Package? _annual;
  Package? _selected;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _loading = true);
    Package? weekly;
    Package? annual;
    try {
      final offerings = await ref.read(purchasesServiceProvider).offerings();
      final offering = offerings?.current;
      if (offering != null) {
        weekly = offering.weekly ??
            _find(offering.availablePackages, PackageType.weekly);
        annual = offering.annual ??
            _find(offering.availablePackages, PackageType.annual);
      }
    } catch (_) {
      // Leave packages null → graceful "billing unavailable" state below.
    }
    if (!mounted) return;
    setState(() {
      _weekly = weekly;
      _annual = annual;
      // Lead with yearly: preselect it when present.
      _selected = annual ?? weekly;
      _loading = false;
    });
  }

  Package? _find(List<Package> packages, PackageType type) {
    for (final p in packages) {
      if (p.packageType == type) return p;
    }
    return null;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _purchase() async {
    final pkg = _selected;
    if (pkg == null) return;
    setState(() => _working = true);
    try {
      final ok = await ref.read(purchasesServiceProvider).purchase(pkg);
      if (!mounted) return;
      if (ok) {
        await ref.read(appSessionProvider).refresh();
        if (!mounted) return;
        context.go('/journal');
      } else {
        _snack('Purchase did not complete.');
      }
    } catch (_) {
      _snack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _working = true);
    try {
      final ok = await ref.read(purchasesServiceProvider).restore();
      if (!mounted) return;
      if (ok) {
        await ref.read(appSessionProvider).refresh();
        if (!mounted) return;
        context.go('/journal');
      } else {
        _snack('No purchases to restore.');
      }
    } catch (_) {
      _snack('Could not restore right now.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Could not open the link.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasOffer = _annual != null || _weekly != null;

    return PaperScaffold(
      scroll: true,
      showAppBar: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpace.lg),
          const Center(child: DoodleIcon(Doodle.sprout, size: 88)),
          const SizedBox(height: AppSpace.lg),
          Text('Unlock One Shot', style: text.displaySmall),
          const SizedBox(height: AppSpace.sm),
          Text(
            'One subscription. Private journaling, plus the anonymous '
            'exchange whenever you want it.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpace.xl),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!hasOffer)
            _UnavailableNote(text: text)
          else ...[
            if (_annual != null)
              _PlanCard(
                title: 'Yearly',
                price: _annual!.storeProduct.priceString,
                note: 'Best value',
                highlighted: true,
                selected: _selected == _annual,
                onTap: () => setState(() => _selected = _annual),
              ),
            if (_annual != null && _weekly != null)
              const SizedBox(height: AppSpace.md),
            if (_weekly != null)
              _PlanCard(
                title: 'Weekly',
                price: _weekly!.storeProduct.priceString,
                note: null,
                highlighted: false,
                selected: _selected == _weekly,
                onTap: () => setState(() => _selected = _weekly),
              ),
          ],
          const SizedBox(height: AppSpace.xl),
          HandButton(
            label: 'Subscribe',
            loading: _working,
            onPressed:
                (!hasOffer || _selected == null || _working) ? null : _purchase,
          ),
          const SizedBox(height: AppSpace.sm),
          HandButton(
            label: 'Restore Purchases',
            variant: HandButtonVariant.outline,
            onPressed: _working ? null : _restore,
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterLink(label: 'Terms', onTap: () => _openUrl(Env.tosUrl)),
              Text('  ·  ', style: text.bodySmall),
              _FooterLink(
                label: 'Privacy',
                onTap: () => _openUrl(Env.privacyUrl),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    );
  }
}

class _UnavailableNote extends StatelessWidget {
  const _UnavailableNote({required this.text});

  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.paperShade,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentSoft),
      ),
      child: Text(
        'Subscriptions are not available on this device right now. You can '
        'still restore an existing purchase below.',
        style: text.bodyMedium,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.note,
    required this.highlighted,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String price;
  final String? note;
  final bool highlighted;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final borderColor = selected ? AppColors.accent : AppColors.accentSoft;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.accentSoft.withValues(alpha: 0.25)
              : AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: borderColor,
            width: selected ? 2.2 : 1.4,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.accent : AppColors.inkSoft,
              size: 22,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: text.titleLarge),
                      if (note != null) ...[
                        const SizedBox(width: AppSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            note!,
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.paper),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(price, style: text.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.accent,
              decoration: TextDecoration.underline,
            ),
      ),
    );
  }
}
