import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/face_pipeline.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'liveness_screen.dart';

/// Opting in to being findable. Pops true on success.
class EnrollScreen extends StatefulWidget {
  const EnrollScreen({super.key});

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  int _days = Config.consentDays[1];
  bool _agreed = false;
  bool _working = false;
  String? _error;

  Future<void> _run({required bool devPhoto}) async {
    setState(() {
      _working = true;
      _error = null;
    });
    String? path;
    try {
      if (devPhoto) {
        path = (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
      } else {
        path = await Navigator.push<String>(context,
            MaterialPageRoute(builder: (_) => const LivenessScreen()));
      }
      if (path == null) return;
      final embedding = await FacePipeline.instance.embeddingFromFile(path);
      // Dev builds on the simulator have no camera; they are flagged as
      // passing so the flow can be tested end to end. Release builds can't.
      await Repo.enroll(
        embedding: embedding,
        livenessPassed: !devPhoto || kDebugMode,
        days: _days,
      );
      if (mounted) Navigator.pop(context, true);
    } on FaceError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Enrollment failed: $e');
    } finally {
      if (path != null) await FacePipeline.discardPhoto(path);
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ready = _agreed && !_working;
    return Scaffold(
      appBar: AppBar(leading: const BackSquare(), leadingWidth: 64),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          const Center(child: Illustration(Icons.face_retouching_natural_rounded, size: 200)),
          const SizedBox(height: 24),
          Text('Become findable', style: t.headlineSmall),
          const SizedBox(height: 10),
          Text(
            'Your photo is processed on this phone and never uploaded. Nobody who searches learns who you are: you see who is asking and decide. Revoking deletes your template entirely.',
            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 22,
            runSpacing: 12,
            children: [
              Fact(Icons.phone_iphone_rounded, 'Stays on device'),
              Fact(Icons.visibility_off_outlined, 'Identity hidden'),
              Fact(Icons.how_to_reg_outlined, 'You approve'),
              Fact(Icons.verified_outlined, 'Signed consent', accent: true),
            ],
          ),
          const SizedBox(height: 28),
          Text('Stay findable for', style: t.titleMedium),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final d in Config.consentDays)
                ButtonSegment(value: d, label: Text('$d days')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: VeilColors.peach,
              borderRadius: BorderRadius.circular(18),
            ),
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              title: Text(
                  'I agree to be findable by face for $_days days. This consent is signed with a key stored only on this device.',
                  style: t.bodyMedium),
            ),
          ),
          const SizedBox(height: 10),
          const LegalLinks(
              lead: 'How your face template is used, kept and destroyed is set out in the ',
              align: TextAlign.left),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$_days', style: t.headlineSmall?.copyWith(color: VeilColors.orange)),
                    Text('/ days', style: t.bodySmall),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ready ? () => _run(devPhoto: false) : null,
                    iconAlignment: IconAlignment.end,
                    icon: _working
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Liveness check'),
                  ),
                ),
              ]),
              if (kDebugMode)
                TextButton(
                  onPressed: ready ? () => _run(devPhoto: true) : null,
                  child: const Text('DEV: enroll from photo (simulator)'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
