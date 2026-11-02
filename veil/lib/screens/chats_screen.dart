import 'dart:async';

import 'package:flutter/material.dart';

import '../services/repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'requests_screen.dart' show InitialBadge;

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final StreamSubscription<void> _sub;

  @override
  void initState() {
    super.initState();
    _sub = Repo.changes.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _refresh() async => setState(() {});

  void _open(MatchRequest c) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ChatScreen(chat: c)));

  @override
  Widget build(BuildContext context) => Builder(
        builder: (context) {
          final chats = Repo.chats();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text('Chats', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                if (chats.isEmpty) ...[
                  const SizedBox(height: 40),
                  const Center(child: Illustration(Icons.forum_outlined, size: 150)),
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Chats open once a request is approved.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
                for (final c in chats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: InitialBadge(c.peerName!),
                        title: Text(c.peerName!,
                            style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(
                            c.incoming ? 'You approved them' : 'They approved you',
                            style: Theme.of(context).textTheme.bodySmall),
                        trailing: ArrowButton(
                            size: 36, tooltip: 'Open chat', onPressed: () => _open(c)),
                        onTap: () => _open(c),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class ChatScreen extends StatefulWidget {
  final MatchRequest chat;
  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  late final _stream = Repo.messages(widget.chat.id);

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await Repo.send(widget.chat.id, text);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackSquare(),
        leadingWidth: 64,
        title: Row(children: [
          InitialBadge(widget.chat.peerName!, size: 36),
          const SizedBox(width: 10),
          Text(widget.chat.peerName!),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _stream,
              builder: (context, snap) {
                final msgs = snap.data ?? const [];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[msgs.length - 1 - i];
                    final mine = m.senderId == Repo.myId;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: mine ? VeilColors.orange : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(mine ? 20 : 6),
                            bottomRight: Radius.circular(mine ? 6 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: VeilColors.orange.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(m.body,
                            style: TextStyle(color: mine ? cs.onPrimary : cs.onSurface)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Message'),
                  ),
                ),
                const SizedBox(width: 10),
                ArrowButton(size: 52, tooltip: 'Send', onPressed: _send),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
