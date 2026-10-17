// OSR1: how an issue report is sealed on the phone so only the maintainers
// can open it.
//
//   ephemeral P-256 keypair → ECDH with our public key (32-byte x)
//   → HKDF-SHA256(salt = ephemeral public key, 65 bytes uncompressed,
//                 info = "openstrap-report-v1", 32 bytes)
//   → AES-256-GCM, random 12-byte nonce, no AAD.
//
//   blob = "OSR1" | eph_pub(65) | nonce(12) | ciphertext || tag(16)
//
// Pure Dart, no Flutter: the tests run it directly.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// The maintainers' report key, P-256 uncompressed point. The private half
/// never ships in any repo.
const String kReportPublicKeyB64 =
    'BPMdcMa2jzNju8JAdSFLFwRuhvEDcaPPUmFbamtbKR2kb7SEml4HfuXf1nRg/SKZNFrG/TBbjx9Jai+/BLHbmhc=';

const List<int> kOsr1Magic = [0x4F, 0x53, 0x52, 0x31]; // "OSR1"
const String _info = 'openstrap-report-v1';

final ECDomainParameters _p256 = ECDomainParameters('secp256r1');

SecureRandom _random() {
  final seed = Random.secure();
  return FortunaRandom()
    ..seed(KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => seed.nextInt(256)))));
}

Uint8List _x32(BigInt x) {
  final out = Uint8List(32);
  var v = x;
  for (var i = 31; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

Uint8List _key(BigInt shared, Uint8List ephPub) {
  final hkdf = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(_x32(shared), 32, ephPub,
        Uint8List.fromList(utf8.encode(_info))));
  final key = Uint8List(32);
  hkdf.deriveKey(null, 0, key, 0);
  return key;
}

Uint8List _gcm(bool encrypt, Uint8List key, Uint8List nonce, Uint8List data) {
  final c = GCMBlockCipher(AESEngine())
    ..init(encrypt,
        AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
  return c.process(data);
}

/// Bytes OSR1 adds to the plaintext: magic, ephemeral key, nonce, GCM tag.
const int kOsr1Overhead = 4 + 65 + 12 + 16;

/// A fresh ephemeral key and nonce: the blob header, and a GCM cipher ready
/// to encrypt the body that follows it.
(Uint8List, GCMBlockCipher) _seal(String publicKeyB64) {
  final rnd = _random();
  final recipient = ECPublicKey(
      _p256.curve.decodePoint(base64Decode(publicKeyB64)), _p256);
  final gen = ECKeyGenerator()
    ..init(ParametersWithRandom(ECKeyGeneratorParameters(_p256), rnd));
  final pair = gen.generateKeyPair();
  final ephPriv = pair.privateKey as ECPrivateKey;
  final ephPub = (pair.publicKey as ECPublicKey).Q!.getEncoded(false);
  final shared = (ECDHBasicAgreement()..init(ephPriv))
      .calculateAgreement(recipient);
  final nonce = rnd.nextBytes(12);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true,
        AEADParameters(KeyParameter(_key(shared, ephPub)), 128, nonce, Uint8List(0)));
  return (
    (BytesBuilder(copy: false)..add(kOsr1Magic)..add(ephPub)..add(nonce))
        .takeBytes(),
    cipher
  );
}

/// Seal [plain] for the holder of the private key matching [publicKeyB64].
Uint8List osr1Encrypt(Uint8List plain,
    {String publicKeyB64 = kReportPublicKeyB64}) {
  final (header, cipher) = _seal(publicKeyB64);
  return (BytesBuilder(copy: false)..add(header)..add(cipher.process(plain)))
      .takeBytes();
}

/// [osr1Encrypt] from file to file, 1 MB at a time: a 95 MB report never sits
/// in memory. Synchronous on purpose; run it in an isolate.
void osr1EncryptFile(String inPath, String outPath,
    {String publicKeyB64 = kReportPublicKeyB64}) {
  final (header, cipher) = _seal(publicKeyB64);
  final src = File(inPath).openSync();
  final dst = File(outPath).openSync(mode: FileMode.writeOnly);
  try {
    dst.writeFromSync(header);
    final inBuf = Uint8List(1 << 20);
    final outBuf = Uint8List((1 << 20) + 32);
    for (;;) {
      final n = src.readIntoSync(inBuf);
      if (n == 0) break;
      dst.writeFromSync(outBuf, 0, cipher.processBytes(inBuf, 0, n, outBuf, 0));
    }
    dst.writeFromSync(outBuf, 0, cipher.doFinal(outBuf, 0));
  } finally {
    src.closeSync();
    dst.closeSync();
  }
}

/// The inverse, for tests and tooling. Throws on a bad tag or layout.
Uint8List osr1Decrypt(Uint8List blob, ECPrivateKey priv) {
  if (blob.length < 4 + 65 + 12 + 16 ||
      String.fromCharCodes(blob.sublist(0, 4)) != 'OSR1') {
    throw const FormatException('not an OSR1 blob');
  }
  final ephPub = blob.sublist(4, 69);
  final nonce = blob.sublist(69, 81);
  final shared = (ECDHBasicAgreement()..init(priv))
      .calculateAgreement(ECPublicKey(_p256.curve.decodePoint(ephPub), _p256));
  return _gcm(false, _key(shared, ephPub), nonce, blob.sublist(81));
}

/// A fresh P-256 keypair (tests only; the real private key lives offline).
AsymmetricKeyPair<PublicKey, PrivateKey> osr1TestKeyPair() =>
    (ECKeyGenerator()
          ..init(ParametersWithRandom(
              ECKeyGeneratorParameters(_p256), _random())))
        .generateKeyPair();

