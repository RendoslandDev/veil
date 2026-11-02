import 'package:flutter/material.dart';

import '../config.dart';
import '../services/face_pipeline.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'enroll_screen.dart';
import 'legal_screen.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  void _reload() => setState(() {});

  Future<void> _enroll() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const EnrollScreen()));
    if (ok == true) _reload();
  }

  Future<void> _erase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete your face data?'),
        content: const Text(
            'Your face template and search history are permanently deleted. Nobody can find you until you enroll again. Existing chats stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await Repo.eraseFaceData();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Builder(
      builder: (context) {
        final e = Repo.myEnrollment();
        final active = e?.active ?? false;
        final daysLeft = active ? e!.expiresAt.difference(DateTime.now()).inDays : 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Your privacy', style: t.headlineSmall),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Illustration(
                        active ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 170,
                        tint: active ? VeilColors.orange : VeilColors.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(active ? 'You are findable' : 'You are invisible',
                        style: t.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      active
                          ? 'Every match still needs your approval before anyone learns who you are.'
                          : e == null
                              ? 'No face data stored. Searches can never match you.'
                              : 'Your consent expired on ${_date(e.expiresAt)}. Searches can\'t match you.',
                      style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (active) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        children: [
                          Fact(Icons.timer_outlined, '$daysLeft days left'),
                          const Fact(Icons.phone_iphone_rounded, 'Stored on device'),
                          const Fact(Icons.verified_outlined, 'Signed consent'),
                          Fact(Icons.event_rounded, 'Until ${_date(e!.expiresAt)}', accent: true),
                        ],
                      ),
                      if (e.embedder == FacePipeline.fallbackId) ...[
                        const SizedBox(height: 16),
                        Text('Using the built-in matcher (no face model bundled yet).',
                            style: t.bodySmall),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _enroll,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(e == null ? 'Become findable' : 'Renew consent'),
            ),
            if (e != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _erase,
                child: const Text('Revoke and delete face data'),
              ),
            ],
            const SizedBox(height: 32),
            const SectionHeader('Privacy shield',
                trailing: Chip(label: Text('Phase 2'))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: VeilColors.peach,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Fact(Icons.blur_on_rounded, 'Cloak photos before you post them'),
                  SizedBox(height: 10),
                  Fact(Icons.mark_email_read_outlined, 'Removal requests for face search engines'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const SectionHeader('Legal'),
            const SizedBox(height: 8),
            for (final d in LegalDoc.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(
                        d == LegalDoc.privacy
                            ? Icons.privacy_tip_outlined
                            : Icons.gavel_rounded,
                        color: VeilColors.orange),
                    title: Text(d.title, style: t.titleMedium),
                    subtitle: Text('Version ${Config.policyVersion}', style: t.bodySmall),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => d.open(context),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}
