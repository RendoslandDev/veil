import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/face_pipeline.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets.dart';

class FindScreen extends StatefulWidget {
  const FindScreen({super.key});

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  final _note = TextEditingController();
  bool _working = false;
  SearchResult? _result;
  String? _error;

  Future<void> _search(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    setState(() {
      _working = true;
      _result = _error = null;
    });
    try {
      final embedding = await FacePipeline.instance.embeddingFromFile(file.path);
      final result = await Repo.search(embedding, _note.text);
      setState(() => _result = result);
      _note.clear();
    } on FaceError catch (e) {
      setState(() => _error = e.message);
    } on RepoError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Search failed: $e');
    } finally {
      await FacePipeline.discardPhoto(file.path);
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('Find someone\nwho said yes', style: t.headlineSmall),
        const SizedBox(height: 20),
        TextField(
          controller: _note,
          maxLength: 200,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: 'Say how you know them',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Illustration(Icons.person_search_rounded, size: 150),
                const SizedBox(height: 16),
                Text(
                  'Searches only reach people who chose to be findable. You never see who matched: they get your request and decide.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _working ? null : () => _search(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Take a photo'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _working ? null : () => _search(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Choose a photo'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_working) const Center(child: CircularProgressIndicator()),
        if (_result != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: VeilColors.peach,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.send_rounded, color: VeilColors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Search sent', style: t.titleMedium),
                      const SizedBox(height: 4),
                      Text([_result!.message, ?_result!.devDetail].join('\n\n'),
                          style: t.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (_error != null) Text(_error!, style: TextStyle(color: cs.error)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            const Fact(Icons.how_to_reg_outlined, 'You must be enrolled'),
            Fact(Icons.speed_rounded, '${Config.dailySearchLimit} searches a day'),
            const Fact(Icons.badge_outlined, 'Every search is tied to you'),
          ],
        ),
      ],
    );
  }
}
