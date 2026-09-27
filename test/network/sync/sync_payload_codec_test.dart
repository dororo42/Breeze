import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';

/// 旧版载荷编码器：固定 nonce、无载荷头。云端已有的 settings_*.bin / comic_*.bin
/// 都是这个格式，升级后必须仍能读出，否则用户的收藏与历史会在同步时被判为损坏。
List<int> _encodeLegacy(List<int> plain) {
  return Encrypter(
    AES(Key.fromUtf8('XY!Ex3j3hP^BGPFanYEjBA!L!oD2kkCN'), mode: AESMode.ctr),
  ).encryptBytes(plain, iv: IV.fromUtf8('7qFwTxwH&iyuw35f')).bytes;
}

void main() {
  final plain = utf8.encode(
    jsonEncode({
      'version': 'v1',
      'syncTime': 1700000000000,
      'favorites': [
        {'uniqueKey': 'a', 'title': 'A'},
      ],
    }),
  );
  final plainChanged = utf8.encode(
    jsonEncode({
      'version': 'v1',
      'syncTime': 1700000000000,
      'favorites': [
        {'uniqueKey': 'a', 'title': 'A'},
        {'uniqueKey': 'b', 'title': 'B'},
      ],
    }),
  );

  group('sync payload codec', () {
    test('round-trips its own output', () {
      final encoded = ComicSyncCore.encryptPayloadForTest(plain);
      final decoded = ComicSyncCore.decryptPayloadForTest(encoded);
      expect(Uint8List.fromList(decoded), equals(Uint8List.fromList(plain)));
    });

    test('reads payloads written before the nonce fix', () {
      final decoded = ComicSyncCore.decryptPayloadForTest(_encodeLegacy(plain));
      expect(Uint8List.fromList(decoded), equals(Uint8List.fromList(plain)));
    });

    // 上层用密文 MD5 同时做"内容是否变化"的判据和远端文件选择，
    // 因此同一明文必须得到同一密文；随机 nonce 会让每次同步都多写一个文件。
    test('is deterministic so the MD5 change check keeps working', () {
      final a = ComicSyncCore.encryptPayloadForTest(plain);
      final b = ComicSyncCore.encryptPayloadForTest(plain);
      expect(md5.convert(a).toString(), md5.convert(b).toString());

      final changed = ComicSyncCore.encryptPayloadForTest(plainChanged);
      expect(md5.convert(changed).toString(), isNot(md5.convert(a).toString()));
    });

    // 固定 nonce 的 AES-CTR 等于所有载荷共用密钥流：两段密文相减即两段明文相减。
    test('does not reuse a keystream across payloads', () {
      final a = ComicSyncCore.encryptPayloadForTest(plain);
      final b = ComicSyncCore.encryptPayloadForTest(plainChanged);
      final headerLength = 20;
      var leaked = 0;
      for (var i = headerLength; i < headerLength + 40; i++) {
        if ((a[i] ^ b[i]) ==
            (plain[i - headerLength] ^ plainChanged[i - headerLength])) {
          leaked++;
        }
      }
      expect(leaked, 0);
    });
  });
}
