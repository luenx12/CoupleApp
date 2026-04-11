// ═══════════════════════════════════════════════════════════════════════════════
// CryptoService — Zero-Leak Hybrid Encryption Engine
//
// Mimarisi:
//   RSA-2048 (OAEP-SHA256) + AES-256-GCM Hybrid Encryption
//   Private key → flutter_secure_storage (Android Keystore / iOS Keychain)
//   Plaintext → asla diske yazılmaz
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

/// Şifrelenmiş paket — wire/disk formatı
class EncryptedPayload {
  final Uint8List encryptedKey; // RSA-OAEP şifreli AES-256 key (256 byte)
  final Uint8List nonce;        // AES-GCM nonce (12 byte)
  final Uint8List ciphertext;   // AES-GCM ciphertext + 16 byte auth tag

  const EncryptedPayload({
    required this.encryptedKey,
    required this.nonce,
    required this.ciphertext,
  });

  // Format: [4B big-endian enc_key_len][enc_key][12B nonce][ciphertext+tag]
  Uint8List toBytes() {
    final keyLen  = encryptedKey.length;
    final total   = 4 + keyLen + 12 + ciphertext.length;
    final out     = Uint8List(total);
    final bd      = ByteData.sublistView(out);
    bd.setInt32(0, keyLen, Endian.big);
    out.setRange(4,            4 + keyLen,       encryptedKey);
    out.setRange(4 + keyLen,   4 + keyLen + 12,  nonce);
    out.setRange(4 + keyLen + 12, total,          ciphertext);
    return out;
  }

  factory EncryptedPayload.fromBytes(Uint8List bytes) {
    final keyLen = ByteData.sublistView(bytes, 0, 4).getInt32(0, Endian.big);
    return EncryptedPayload(
      encryptedKey: bytes.sublist(4,             4 + keyLen),
      nonce:        bytes.sublist(4 + keyLen,    4 + keyLen + 12),
      ciphertext:   bytes.sublist(4 + keyLen + 12),
    );
  }

  String toBase64()                        => base64Encode(toBytes());
  factory EncryptedPayload.fromBase64(String b) => EncryptedPayload.fromBytes(base64Decode(b));
}

// ─────────────────────────────────────────────────────────────────────────────
class CryptoService {
  CryptoService(this._storage);

  final FlutterSecureStorage _storage;
  static const _kPrivPem = 'rsa_priv_pem_v1';
  static const _kPubPem  = 'rsa_pub_pem_v1';

  RSAPublicKey?  _pub;
  RSAPrivateKey? _priv;

  bool get isReady => _pub != null && _priv != null;

  // ── Başlatıcı ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    final privPem = await _storage.read(key: _kPrivPem);
    if (privPem == null) {
      await _generateAndStore();
    } else {
      final pubPem = await _storage.read(key: _kPubPem);
      _priv = _parsePkcs8Pem(privPem);
      _pub  = _parseSpkiPem(pubPem!);
    }
  }

  String get publicKeyPem {
    _assertReady();
    return _toSpkiPem(_pub!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Şifreleme
  // ═══════════════════════════════════════════════════════════════════════════
  EncryptedPayload encrypt(Uint8List plaintext, String recipientPubPem) {
    final recipientPub = _parseSpkiPem(recipientPubPem);

    // 1. Rastgele AES key + GCM nonce (RAM only)
    final aesKey = _randomBytes(32);
    final nonce  = _randomBytes(12);

    // 2. AES-256-GCM şifreleme
    final ciphertext = _aesGcmEncrypt(plaintext, aesKey, nonce);

    // 3. AES key'i RSA-OAEP ile şifrele
    final encKey = _rsaEncrypt(aesKey, recipientPub);

    // 4. AES key'i RAM'den sil
    zeroFill(aesKey);

    return EncryptedPayload(encryptedKey: encKey, nonce: nonce, ciphertext: ciphertext);
  }

  EncryptedPayload encryptForSelf(Uint8List plaintext) {
    _assertReady();
    return encrypt(plaintext, publicKeyPem);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Çözme (sadece RAM'de)
  // ═══════════════════════════════════════════════════════════════════════════
  Uint8List decrypt(EncryptedPayload payload) {
    _assertReady();
    final aesKey    = _rsaDecrypt(payload.encryptedKey, _priv!);
    final plaintext = _aesGcmDecrypt(payload.ciphertext, aesKey, payload.nonce);
    zeroFill(aesKey);
    return plaintext;
  }

  String decryptText(EncryptedPayload payload) {
    final bytes = decrypt(payload);
    final text  = utf8.decode(bytes);
    zeroFill(bytes);
    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  AES-256-GCM
  // ═══════════════════════════════════════════════════════════════════════════
  Uint8List _aesGcmEncrypt(Uint8List plain, Uint8List key, Uint8List nonce) {
    final params = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0));
    return (GCMBlockCipher(AESEngine())..init(true, params)).process(plain);
  }

  Uint8List _aesGcmDecrypt(Uint8List cipher, Uint8List key, Uint8List nonce) {
    final params = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0));
    return (GCMBlockCipher(AESEngine())..init(false, params)).process(cipher);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RSA-OAEP
  // ═══════════════════════════════════════════════════════════════════════════
  Uint8List _rsaEncrypt(Uint8List data, RSAPublicKey pub) =>
      (OAEPEncoding.withSHA256(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(pub)))
          .process(data);

  Uint8List _rsaDecrypt(Uint8List data, RSAPrivateKey priv) =>
      (OAEPEncoding.withSHA256(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(priv)))
          .process(data);

  // ═══════════════════════════════════════════════════════════════════════════
  //  RSA Key Generation
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _generateAndStore() async {
    final rng = FortunaRandom();
    final seed = Uint8List(32);
    final sr   = Random.secure();
    for (var i = 0; i < 32; i++) { seed[i] = sr.nextInt(256); }
    rng.seed(KeyParameter(seed));
    zeroFill(seed);

    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        rng,
      ));

    final pair = keyGen.generateKeyPair();
    _pub  = pair.publicKey  as RSAPublicKey;
    _priv = pair.privateKey as RSAPrivateKey;

    await _storage.write(key: _kPrivPem, value: _toPkcs8Pem(_priv!));
    await _storage.write(key: _kPubPem,  value: _toSpkiPem(_pub!));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PEM Serialization (Manuel DER encoding — ASN.1)
  // ═══════════════════════════════════════════════════════════════════════════
  static const _rsaOid = [1, 2, 840, 113549, 1, 1, 1]; // rsaEncryption OID

  // ──  SubjectPublicKeyInfo (SPKI) encoding ──
  String _toSpkiPem(RSAPublicKey key) {
    final innerSeq = ASN1Sequence()
      ..add(ASN1Integer(key.modulus))
      ..add(ASN1Integer(key.publicExponent));
    final innerDer = innerSeq.encode();

    final bitStr = ASN1BitString(
      stringValues: Uint8List.fromList([0, ...innerDer]),
    );
    final algSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier(_rsaOid))
      ..add(ASN1Null());
    final spki = ASN1Sequence()
      ..add(algSeq)
      ..add(bitStr);

    return _wrapPem('PUBLIC KEY', spki.encode());
  }

  // ── PKCS#8 Private Key encoding ──
  String _toPkcs8Pem(RSAPrivateKey key) {
    final inner = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))       // version
      ..add(ASN1Integer(key.modulus))
      ..add(ASN1Integer(key.publicExponent))
      ..add(ASN1Integer(key.privateExponent))
      ..add(ASN1Integer(key.p))
      ..add(ASN1Integer(key.q))
      ..add(ASN1Integer(key.privateExponent! % (key.p! - BigInt.one)))
      ..add(ASN1Integer(key.privateExponent! % (key.q! - BigInt.one)))
      ..add(ASN1Integer(key.q!.modInverse(key.p!)));

    final algSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier(_rsaOid))
      ..add(ASN1Null());

    final pkcs8 = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))
      ..add(algSeq)
      ..add(ASN1OctetString(octets: inner.encode()));

    return _wrapPem('PRIVATE KEY', pkcs8.encode());
  }

  // ── Parse SPKI PEM ──
  RSAPublicKey _parseSpkiPem(String pem) {
    final der      = base64Decode(_stripPem(pem));
    final outer    = ASN1Parser(der).nextObject() as ASN1Sequence;
    final bitStr   = outer.elements![1] as ASN1BitString;
    // skip 1 padding byte at the start of BitString value
    final innerDer = Uint8List.fromList(bitStr.stringValues!.skip(1).toList());
    final inner    = ASN1Parser(innerDer).nextObject() as ASN1Sequence;
    final mod      = (inner.elements![0] as ASN1Integer).integer!;
    final exp      = (inner.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(mod, exp);
  }

  // ── Parse PKCS#8 PEM ──
  RSAPrivateKey _parsePkcs8Pem(String pem) {
    final der   = base64Decode(_stripPem(pem));
    final outer = ASN1Parser(der).nextObject() as ASN1Sequence;
    final inner = ASN1Parser(
      (outer.elements![2] as ASN1OctetString).octets!,
    ).nextObject() as ASN1Sequence;
    final mod   = (inner.elements![1] as ASN1Integer).integer!;
    final p     = (inner.elements![4] as ASN1Integer).integer!;
    final q     = (inner.elements![5] as ASN1Integer).integer!;
    final priv  = (inner.elements![3] as ASN1Integer).integer!;
    return RSAPrivateKey(mod, priv, p, q);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════════════════════════════════
  String _wrapPem(String label, Uint8List der) {
    final b64 = base64Encode(der);
    final buf = StringBuffer('-----BEGIN $label-----\n');
    for (var i = 0; i < b64.length; i += 64) {
      buf.writeln(b64.substring(i, (i + 64).clamp(0, b64.length)));
    }
    buf.write('-----END $label-----');
    return buf.toString();
  }

  String _stripPem(String pem) =>
      pem.replaceAll(RegExp(r'-----[^-]+-----'), '').replaceAll('\n', '').trim();

  Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  void _assertReady() {
    if (!isReady) throw StateError('CryptoService.init() çağrılmadı');
  }

  // ── Statik yardımcı: RAM'deki bytes'ı sıfırla (GC'yi beklemeden) ──────────
  static void zeroFill(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}
