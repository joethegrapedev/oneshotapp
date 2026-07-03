import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../models/crisis_resource.dart';
import '../../widgets/doodles.dart';
import '../../widgets/hand_button.dart';
import '../../widgets/paper_scaffold.dart';

// VERIFY these numbers/hours against sos.org.sg and mindline.sg at build time
// (CONTRACTS §9). These are LOCAL FALLBACK resources rendered when the crisis
// payload from the edge function is absent. The screen NEVER shows methods,
// detail, or any self-harm content — only calm, supportive signposting.
const List<CrisisResource> _fallbackResources = [
  CrisisResource(
    name: 'Samaritans of Singapore (SOS)',
    contact: '1767',
    hours: '24 hours',
    note: 'Call to talk to someone, any time.',
  ),
  CrisisResource(
    name: 'SOS CareText (WhatsApp)',
    contact: '9151 1767',
    hours: '24 hours',
    note: 'Message on WhatsApp if you prefer to text.',
  ),
  CrisisResource(
    name: 'national mindline 1771',
    contact: '1771',
    hours: 'See mindline.sg for hours',
    note: 'Support and referrals — also at mindline.sg.',
  ),
];

/// A calm, supportive safety screen (CONTRACTS §2c / §9).
///
/// Warm, non-alarming tone. Shows local Singapore support resources as tappable
/// cards. Renders whatever crisis payload was passed, else a local fallback.
/// It must never surface self-harm content, methods, or detail.
class CrisisScreen extends StatelessWidget {
  const CrisisScreen({super.key, this.resources});

  /// Optional resources passed from a moderation `crisis` payload. When null or
  /// empty, the on-file local fallback list is shown instead.
  final List<CrisisResource>? resources;

  List<CrisisResource> get _resolvedResources =>
      (resources == null || resources!.isEmpty)
          ? _fallbackResources
          : resources!;

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't open that just now. Please try again."),
        ),
      );
    }
  }

  void _explainPrivate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text(
          'Kept private',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Your entry was saved privately to your journal. It was not shared '
          'and no one else can read it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Okay',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PaperScaffold(
      scroll: true,
      showAppBar: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpace.lg),
          const Center(
            child: DoodleIcon(Doodle.heart, size: 96, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'You matter. Support is available.',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            "Whatever you're carrying right now, you don't have to carry it "
            'alone. Kind, trained people are ready to listen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpace.xl),
          for (final resource in _resolvedResources) ...[
            _ResourceCard(
              resource: resource,
              onTap: () => _launch(context, _uriFor(resource)),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          const SizedBox(height: AppSpace.xs),
          Text(
            'If life is in danger, call 995 (SG emergency).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.xl),
          HandButton(
            label: 'Save privately',
            icon: Icons.lock_outline,
            variant: HandButtonVariant.outline,
            onPressed: () => _explainPrivate(context),
          ),
          const SizedBox(height: AppSpace.sm),
          HandButton(
            label: 'Back to journal',
            onPressed: () => context.goNamed('journal'),
          ),
          const SizedBox(height: AppSpace.lg),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource, required this.onTap});

  final CrisisResource resource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPhone = _isTelContact(resource.contact);
    return Material(
      color: AppColors.paperShade,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Icon(
                isPhone ? Icons.call_outlined : Icons.language,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${resource.contact}'
                      '${resource.hours.isEmpty ? '' : '  ·  ${resource.hours}'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (resource.note != null && resource.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        resource.note!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether a contact string looks like a phone number (digits/spaces only).
bool _isTelContact(String contact) {
  final trimmed = contact.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^[0-9+\-\s]+$').hasMatch(trimmed);
}

/// Builds the launch [Uri] for a resource: `tel:` for phone-like contacts,
/// otherwise an `https:` URL (adding the scheme if the contact is bare).
Uri _uriFor(CrisisResource resource) {
  final contact = resource.contact.trim();
  final name = resource.name.toLowerCase();

  // WhatsApp CareText: open a chat rather than dialling.
  if (name.contains('whatsapp') || name.contains('caretext')) {
    final digits = contact.replaceAll(RegExp(r'[^0-9]'), '');
    final intl = digits.length <= 8 ? '65$digits' : digits;
    return Uri.parse('https://wa.me/$intl');
  }
  if (_isTelContact(contact)) {
    final digits = contact.replaceAll(RegExp(r'[^0-9+]'), '');
    return Uri(scheme: 'tel', path: digits);
  }
  if (contact.startsWith('http://') || contact.startsWith('https://')) {
    return Uri.parse(contact);
  }
  return Uri.parse('https://$contact');
}
