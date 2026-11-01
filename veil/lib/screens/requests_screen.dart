import 'dart:async';

import 'package:flutter/material.dart';

import '../services/repo.dart';
import '../theme.dart';
import '../widgets.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
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

  Future<void> _respond(MatchRequest r, String decision) =>
      Repo.respond(r.id, decision);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Requests', style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.symmetric(horizontal: 8),
            tabs: [Tab(text: 'Received'), Tab(text: 'Sent')],
          ),
          Expanded(
            child: TabBarView(children: [
              _list(Repo.incoming(), 'No one has asked to connect yet.',
                  (r) => _IncomingTile(r, _respond)),
              _list(Repo.outgoing(), 'No requests sent yet.',
                  (r) => _OutgoingTile(r)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _list(List<MatchRequest> items, String empty,
          Widget Function(MatchRequest) tile) =>
      RefreshIndicator(
        onRefresh: _refresh,
        child: items.isEmpty
            ? ListView(children: [
                const SizedBox(height: 60),
                const Center(child: Illustration(Icons.mark_email_unread_outlined, size: 150)),
                const SizedBox(height: 20),
                Center(child: Text(empty, style: Theme.of(context).textTheme.bodySmall)),
              ])
            : ListView(children: items.map(tile).toList()),
      );
}

class _IncomingTile extends StatelessWidget {
  final MatchRequest r;
  final Future<void> Function(MatchRequest, String) respond;
  const _IncomingTile(this.r, this.respond);

  @override
  Widget build(BuildContext context) {
    final pending = r.status == 'pending';
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                InitialBadge(r.peerName!),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.peerName!, style: t.titleMedium),
                      Text('wants to connect', style: t.bodySmall),
                    ],
                  ),
                ),
                if (!pending) Chip(label: Text(r.status)),
              ]),
              if (r.note != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: VeilColors.peach,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('"${r.note}"', style: t.bodyMedium),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Face similarity ${(r.similarity! * 100).round()}%. If this isn\'t you or you don\'t know them, deny or block.',
                style: t.bodySmall,
              ),
              if (pending) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                        onPressed: () => respond(r, 'approved'),
                        child: const Text('Approve')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => respond(r, 'denied'),
                        child: const Text('Deny')),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Block',
                    color: VeilColors.muted,
                    onPressed: () => respond(r, 'blocked'),
                    icon: const Icon(Icons.block_rounded),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded-square initial avatar in the accent colors.
class InitialBadge extends StatelessWidget {
  final String name;
  final double size;
  const InitialBadge(this.name, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VeilColors.orangeSoft,
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Text(name[0].toUpperCase(),
            style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                color: VeilColors.orange)),
      );
}

class _OutgoingTile extends StatelessWidget {
  final MatchRequest r;
  const _OutgoingTile(this.r);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (r.status) {
      'approved' => (Icons.check_circle_rounded, VeilColors.orange),
      'denied' => (Icons.cancel_outlined, VeilColors.muted),
      _ => (Icons.hourglass_top_rounded, VeilColors.sky),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: Icon(icon, color: color, size: 30),
          title: Text(
            r.status == 'approved'
                ? '${r.peerName} accepted'
                : r.status == 'denied'
                    ? 'Request declined'
                    : 'Waiting for a reply',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text('Sent ${r.createdAt.toLocal().toString().substring(0, 16)}',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }
}
