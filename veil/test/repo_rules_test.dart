import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veil/config.dart';
import 'package:veil/services/face_pipeline.dart';
import 'package:veil/services/repo.dart';

FaceEmbedding face(List<double> v) => FaceEmbedding(v, FacePipeline.fallbackId);
final ama = face([1, 0, 0]);
final kofi = face([0, 1, 0]);

Future<String> person(String name) async {
  await Repo.createPerson(name);
  return Repo.myId;
}

void main() {
  late Directory dir;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('veil');
    await Repo.initAt(File('${dir.path}/db.json'));
  });
  tearDown(() => dir.delete(recursive: true));

  test('search needs the searcher to be enrolled', () async {
    await person('Kofi');
    expect(() => Repo.search(ama, null), throwsA(isA<RepoError>()));
  });

  test('match creates a hidden request; approval reveals both sides', () async {
    final amaId = await person('Ama');
    await Repo.enroll(embedding: ama, livenessPassed: true, days: 30);
    await person('Kofi');
    await Repo.enroll(embedding: kofi, livenessPassed: true, days: 30);

    final res = await Repo.search(ama, 'We met at the meetup');
    expect(res.message, contains('If someone who consented'));
    final out = Repo.outgoing().single;
    expect(out.status, 'pending');
    expect(out.peerName, isNull, reason: 'target hidden before approval');

    await Repo.switchTo(amaId);
    final incoming = Repo.incoming().single;
    expect(incoming.peerName, 'Kofi');
    expect(incoming.note, 'We met at the meetup');
    expect(() => Repo.send(incoming.id, 'hi'), throwsA(isA<RepoError>()),
        reason: 'no chat before approval');

    await Repo.respond(incoming.id, 'approved');
    await Repo.send(incoming.id, 'Hi Kofi');
    await Repo.switchTo(Repo.people().firstWhere((p) => p.name == 'Kofi').id);
    expect(Repo.outgoing().single.peerName, 'Ama');
    expect(Repo.chats().single.peerName, 'Ama');
  });

  test('non-matching and non-consenting faces create no request', () async {
    await person('Ama'); // never enrolls
    await person('Esi');
    await Repo.enroll(embedding: face([0, 0, 1]), livenessPassed: true, days: 30);
    await person('Kofi');
    await Repo.enroll(embedding: kofi, livenessPassed: true, days: 30);
    final res = await Repo.search(ama, null);
    expect(res.message, contains('If someone who consented'),
        reason: 'same reply whether or not anyone matched');
    expect(Repo.outgoing(), isEmpty);
  });

  test('revoking deletes the template so searches stop matching', () async {
    final amaId = await person('Ama');
    await Repo.enroll(embedding: ama, livenessPassed: true, days: 30);
    await Repo.eraseFaceData();
    expect(Repo.myEnrollment(), isNull);
    await person('Kofi');
    await Repo.enroll(embedding: kofi, livenessPassed: true, days: 30);
    await Repo.search(ama, null);
    expect(Repo.outgoing(), isEmpty);
    expect(amaId, isNotEmpty);
  });

  test('blocked reads as denied to the requester', () async {
    final amaId = await person('Ama');
    await Repo.enroll(embedding: ama, livenessPassed: true, days: 30);
    final kofiId = await person('Kofi');
    await Repo.enroll(embedding: kofi, livenessPassed: true, days: 30);
    await Repo.search(ama, null);
    await Repo.switchTo(amaId);
    await Repo.respond(Repo.incoming().single.id, 'blocked');
    await Repo.switchTo(kofiId);
    expect(Repo.outgoing().single.status, 'denied');
  });

  test('daily search limit', () async {
    await person('Kofi');
    await Repo.enroll(embedding: kofi, livenessPassed: true, days: 30);
    for (var i = 0; i < Config.dailySearchLimit; i++) {
      await Repo.search(ama, null);
    }
    expect(() => Repo.search(ama, null), throwsA(isA<RepoError>()));
  });

  test('expired consent deletes the template on next load', () async {
    await person('Ama');
    await Repo.enroll(embedding: ama, livenessPassed: true, days: 30);
    final file = File('${dir.path}/db.json');
    final db = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final t = (db['templates'] as Map).values.first as Map;
    t['expiresAt'] = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
    await file.writeAsString(jsonEncode(db));
    await Repo.initAt(file);
    expect(Repo.myEnrollment(), isNull);
  });

  test('consent records the policy version agreed to', () async {
    await person('Ama');
    await Repo.enroll(embedding: ama, livenessPassed: true, days: 30);
    final db = jsonDecode(await File('${dir.path}/db.json').readAsString());
    final t = (db['templates'] as Map).values.first as Map;
    expect(t['consentPayload']['policy_version'], Config.policyVersion);
  });
}
