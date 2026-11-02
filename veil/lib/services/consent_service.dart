import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

/// A signed, expiring consent record. The private key lives only in the
/// device keychain, so a consent record can't be forged on the server: the
/// signature proves this device's owner agreed to these exact terms.
class SignedConsent {
  final Map<String, dynamic> payload;
  final String signature;
  final String publicKey;
  final DateTime expiresAt;
  SignedConsent(this.payload, this.signature, this.publicKey, this.expiresAt);
}

class ConsentService {
  ConsentService._();
  static final instance = ConsentService._();

  final _storage = const FlutterSecureStorage();
  final _algo = Ed25519();

  /// One key per person on this device, so test persons can't sign for each other.
  Future<SimpleKeyPair> _keyPair(String userId) async {
    final seedKey = 'veil.ed25519.seed.$userId';
    final stored = await _storage.read(key: seedKey);
    if (stored != null) {
      return _algo.newKeyPairFromSeed(base64Decode(stored));
    }
    final pair = await _algo.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    await _storage.write(key: seedKey, value: base64Encode(seed));
    return pair;
  }

  Future<String> publicKeyB64(String userId) async =>
      base64Encode((await (await _keyPair(userId)).extractPublicKey()).bytes);

  Future<SignedConsent> sign({required String userId, required int days}) async {
    final now = DateTime.now().toUtc();
    final expires = now.add(Duration(days: days));
    // Keys in fixed alphabetical order so the bytes signed are reproducible.
    final payload = <String, dynamic>{
      'expires_at': expires.toIso8601String(),
      'issued_at': now.toIso8601String(),
      'policy_version': Config.policyVersion,
      'scope': 'discoverable_by_face',
      'terms': 'Matches are never revealed without my approval.',
      'user_id': userId,
    };
    final pair = await _keyPair(userId);
    final sig = await _algo.sign(utf8.encode(jsonEncode(payload)), keyPair: pair);
    return SignedConsent(
      payload,
      base64Encode(sig.bytes),
      await publicKeyB64(userId),
      expires,
    );
  }
}
