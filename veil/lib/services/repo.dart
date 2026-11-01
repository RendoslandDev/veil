import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import 'consent_service.dart';
import 'face_pipeline.dart';

/// A rule violation shown to the user as-is.
class RepoError implements Exception {
  final String message;
  RepoError(this.message);
  @override
  String toString() => message;
}

class Person {
  final String id;
  final String name;
  Person(this.id, this.name);
}

class Enrollment {
  final DateTime expiresAt;
  final bool livenessPassed;
  final String embedder;
  Enrollment(this.expiresAt, this.livenessPassed, this.embedder);
  bool get active => expiresAt.isAfter(DateTime.now());
}

class MatchRequest {
  final String id;
  final String status;
  final DateTime createdAt;
  final String? peerId;
  final String? peerName;
  final String? note;
  final double? similarity;
  final bool incoming;
  MatchRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.incoming,
    this.peerId,
    this.peerName,
    this.note,
    this.similarity,
  });
}

class Message {
  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  Message(this.id, this.senderId, this.body, this.createdAt);
}

class SearchResult {
  final String message;

  /// Debug builds only: best similarity and threshold, for calibration.
  final String? devDetail;
  SearchResult(this.message, this.devDetail);
}

/// On-device stand-in for the backend: one JSON file in app support storage,
/// nothing on the network. It enforces the same rules as
/// supabase/migrations/*_init.sql so a server can replace it later:
///   - only active, unexpired, liveness-passed consent can be matched
///   - a search never reveals who matched; it can only create a request
///   - searchers must be enrolled themselves and are rate limited
///   - identities are revealed only after the target approves
///   - revoking consent deletes the template
class Repo {
  static late File _file;
  static late Map<String, dynamic> _db;
  static final _changes = StreamController<void>.broadcast();
  static final _rand = Random.secure();

  /// Fires after every write, so screens can refresh.
  static Stream<void> get changes => _changes.stream;

  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    await initAt(File('${dir.path}/veil_local.json'));
  }

  @visibleForTesting
  static Future<void> initAt(File file) async {
    _file = file;
    _db = await _file.exists()
        ? jsonDecode(await _file.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{};
    for (final k in ['people', 'requests', 'searchLog', 'messages']) {
      _db.putIfAbsent(k, () => <dynamic>[]);
    }
    _db.putIfAbsent('templates', () => <String, dynamic>{});
    await purgeExpired();
  }

  /// Retention promised in the Privacy Policy: a template is destroyed once
  /// its consent expires, and search times are kept for 24 hours only.
  static Future<void> purgeExpired() async {
    final now = DateTime.now();
    final before = jsonEncode([_templates.length, _list('searchLog').length]);
    _templates.removeWhere((_, t) => !DateTime.parse(t['expiresAt']).isAfter(now));
    final dayAgo = now.subtract(const Duration(days: 1));
    _list('searchLog').removeWhere((s) => !DateTime.parse(s['at']).isAfter(dayAgo));
    if (jsonEncode([_templates.length, _list('searchLog').length]) != before) {
      await _save();
    }
  }

  static Future<void> _save() async {
    await _file.writeAsString(jsonEncode(_db));
    _changes.add(null);
  }

  static String _newId() =>
      List.generate(16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  static List _list(String k) => _db[k] as List;
  static Map<String, dynamic> get _templates => _db['templates'] as Map<String, dynamic>;

  // People (no accounts: a name on this device) -----------------------------

  static String? get currentId => _db['currentId'] as String?;
  static String get myId => currentId!;

  static List<Person> people() =>
      _list('people').map((p) => Person(p['id'], p['name'])).toList();

  static String nameOf(String id) =>
      _list('people').firstWhere((p) => p['id'] == id)['name'] as String;

  static String myName() => nameOf(myId);

  static Future<void> createPerson(String name) async {
    final id = _newId();
    _list('people').add({'id': id, 'name': name.trim()});
    _db['currentId'] = id;
    await _save();
  }

  static Future<void> switchTo(String id) async {
    _db['currentId'] = id;
    await _save();
  }

  // Enrollment + consent ----------------------------------------------------

  static Enrollment? myEnrollment() {
    final t = _templates[myId];
    if (t == null) return null;
    return Enrollment(DateTime.parse(t['expiresAt']), t['liveness'], t['embedder']);
  }

  /// Replaces any existing template: re-enrolling is how consent is renewed.
  static Future<void> enroll({
    required FaceEmbedding embedding,
    required bool livenessPassed,
    required int days,
  }) async {
    final consent = await ConsentService.instance.sign(userId: myId, days: days);
    _templates[myId] = {
      'embedding': embedding.vector,
      'embedder': embedding.embedder,
      'liveness': livenessPassed,
      'consentPayload': consent.payload,
      'consentSignature': consent.signature,
      'publicKey': consent.publicKey,
      'expiresAt': consent.expiresAt.toIso8601String(),
    };
    await _save();
  }

  static Future<void> eraseFaceData() async {
    _templates.remove(myId);
    _list('searchLog').removeWhere((s) => s['searcher'] == myId);
    await _save();
  }

  // Search ------------------------------------------------------------------

  static const _uniformReply =
      'If someone who consented to be found matches, they will get your request.';

  static Future<SearchResult> search(FaceEmbedding query, String? note) async {
    await purgeExpired();
    final me = _templates[myId];
    if (me == null || me['liveness'] != true) {
      throw RepoError('Enroll your own face before searching.');
    }
    final dayAgo = DateTime.now().subtract(const Duration(days: 1));
    final recent = _list('searchLog').where((s) =>
        s['searcher'] == myId && DateTime.parse(s['at']).isAfter(dayAgo));
    if (recent.length >= Config.dailySearchLimit) {
      throw RepoError('Daily search limit reached.');
    }
    _list('searchLog').add({'searcher': myId, 'at': DateTime.now().toIso8601String()});

    final blockedBy = _list('requests')
        .where((r) => r['requester'] == myId && r['status'] == 'blocked')
        .map((r) => r['target'])
        .toSet();
    String? bestId;
    var best = -1.0;
    _templates.forEach((uid, t) {
      if (uid == myId || blockedBy.contains(uid)) return;
      if (t['liveness'] != true) return;
      if (t['embedder'] != query.embedder) return;
      if (!DateTime.parse(t['expiresAt']).isAfter(DateTime.now())) return;
      final sim = FacePipeline.cosine(
          query.vector, (t['embedding'] as List).cast<num>().map((n) => n.toDouble()).toList());
      if (sim > best) {
        best = sim;
        bestId = uid;
      }
    });

    final threshold = FaceEmbedding.thresholdFor(query.embedder);
    if (bestId != null && best >= threshold) {
      final exists = _list('requests')
          .any((r) => r['requester'] == myId && r['target'] == bestId);
      if (!exists) {
        _list('requests').add({
          'id': _newId(),
          'requester': myId,
          'target': bestId,
          'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
          'similarity': best,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    }
    await _save();
    return SearchResult(
      _uniformReply,
      kDebugMode
          ? 'DEV: best similarity ${best < 0 ? 'n/a' : best.toStringAsFixed(3)}, threshold $threshold (${query.embedder})'
          : null,
    );
  }

  // Requests ----------------------------------------------------------------

  static List<MatchRequest> incoming() => _list('requests')
      .where((r) => r['target'] == myId)
      .map((r) => MatchRequest(
            id: r['id'],
            status: r['status'],
            createdAt: DateTime.parse(r['createdAt']),
            incoming: true,
            // The requester chose to reveal themselves by searching.
            peerId: r['requester'],
            peerName: nameOf(r['requester']),
            note: r['note'],
            similarity: (r['similarity'] as num).toDouble(),
          ))
      .toList()
      .reversed
      .toList();

  /// The target's identity stays hidden until they approve; blocked reads
  /// as denied so the requester can't tell the difference.
  static List<MatchRequest> outgoing() => _list('requests')
      .where((r) => r['requester'] == myId)
      .map((r) {
        final approved = r['status'] == 'approved';
        return MatchRequest(
          id: r['id'],
          status: r['status'] == 'blocked' ? 'denied' : r['status'],
          createdAt: DateTime.parse(r['createdAt']),
          incoming: false,
          peerId: approved ? r['target'] : null,
          peerName: approved ? nameOf(r['target']) : null,
        );
      })
      .toList()
      .reversed
      .toList();

  static Future<void> respond(String id, String decision) async {
    if (!const ['approved', 'denied', 'blocked'].contains(decision)) {
      throw RepoError('Invalid decision.');
    }
    final r = _list('requests')
        .firstWhere((r) => r['id'] == id && r['target'] == myId, orElse: () => null);
    if (r == null) throw RepoError('Request not found.');
    r['status'] = decision;
    r['respondedAt'] = DateTime.now().toIso8601String();
    await _save();
  }

  static List<MatchRequest> chats() =>
      [...incoming(), ...outgoing()].where((r) => r.status == 'approved').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Messages ----------------------------------------------------------------

  static bool _isMember(String requestId) => _list('requests').any((r) =>
      r['id'] == requestId &&
      r['status'] == 'approved' &&
      (r['requester'] == myId || r['target'] == myId));

  static List<Message> _messagesFor(String requestId) => _list('messages')
      .where((m) => m['requestId'] == requestId)
      .map((m) => Message(m['id'], m['sender'], m['body'], DateTime.parse(m['createdAt'])))
      .toList();

  static Stream<List<Message>> messages(String requestId) async* {
    if (!_isMember(requestId)) return;
    yield _messagesFor(requestId);
    await for (final _ in changes) {
      yield _messagesFor(requestId);
    }
  }

  static Future<void> send(String requestId, String body) async {
    if (!_isMember(requestId)) throw RepoError('This chat is not open.');
    _list('messages').add({
      'id': _newId(),
      'requestId': requestId,
      'sender': myId,
      'body': body,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _save();
  }
}
