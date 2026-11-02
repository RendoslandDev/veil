import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets.dart';

enum LegalDoc {
  privacy('Privacy Policy', 'assets/legal/privacy.md'),
  terms('Terms of Service', 'assets/legal/terms.md');

  final String title;
  final String asset;
  const LegalDoc(this.title, this.asset);

  void open(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => LegalScreen(doc: this)));
}

/// Shows a bundled legal document. The Markdown files in assets/legal are
/// the single source of truth: the same files can be hosted for the App
/// Store, so the app and the web never drift apart.
class LegalScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: const BackSquare(), leadingWidth: 64),
        body: FutureBuilder<String>(
          future: rootBundle.loadString(doc.asset),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              children: _MiniMarkdown.parse(snap.data!, Theme.of(context).textTheme),
            );
          },
        ),
      );
}

/// Just enough Markdown for our own legal files: #/##/### headings,
/// paragraphs, "-" bullets, two-column tables and **bold**.
class _MiniMarkdown {
  static List<Widget> parse(String src, TextTheme t) {
    final out = <Widget>[];
    final para = <String>[];
    final table = <List<String>>[];

    void flushPara() {
      if (para.isEmpty) return;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text.rich(_inline(para.join(' '), t.bodyMedium!)),
      ));
      para.clear();
    }

    void flushTable() {
      if (table.isEmpty) return;
      out.add(Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: VeilColors.peach,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          for (var i = 0; i < table.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: VeilColors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < table[i].length; c++)
                    Expanded(
                      flex: c == 0 ? 2 : 3,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text.rich(_inline(
                            table[i][c],
                            (i == 0 ? t.titleSmall : t.bodySmall)!
                                .copyWith(color: VeilColors.ink))),
                      ),
                    ),
                ],
              ),
            ),
        ]),
      ));
      table.clear();
    }

    for (final raw in src.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('|')) {
        flushPara();
        final cells = line.split('|').map((c) => c.trim()).toList()
          ..removeAt(0)
          ..removeLast();
        if (!cells.every((c) => RegExp(r'^-+$').hasMatch(c))) table.add(cells);
        continue;
      }
      flushTable();
      if (line.isEmpty) {
        flushPara();
      } else if (line.startsWith('# ')) {
        flushPara();
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(line.substring(2), style: t.headlineSmall),
        ));
      } else if (line.startsWith('## ')) {
        flushPara();
        out.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(line.substring(3), style: t.titleLarge),
        ));
      } else if (line.startsWith('### ')) {
        flushPara();
        out.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(line.substring(4),
              style: t.titleMedium?.copyWith(color: VeilColors.orange)),
        ));
      } else if (line.startsWith('- ')) {
        flushPara();
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8, right: 10),
                child: CircleAvatar(radius: 3, backgroundColor: VeilColors.orange),
              ),
              Expanded(child: Text.rich(_inline(line.substring(2), t.bodyMedium!))),
            ],
          ),
        ));
      } else if (line.startsWith('Version ')) {
        flushPara();
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(line, style: t.bodySmall),
        ));
      } else {
        para.add(line);
      }
    }
    flushPara();
    flushTable();
    return out;
  }

  static TextSpan _inline(String s, TextStyle base) {
    final spans = <TextSpan>[];
    final parts = s.split('**');
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ));
    }
    return TextSpan(style: base, children: spans);
  }
}
