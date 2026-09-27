import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';

/// 旧版载荷编码器：固定 nonce、无载荷头。云端已有的 settings_*.bin / comic_*.bin
/// 都是这个格式，升级后必须仍能读出，否则用户的收藏与历史会在同步时被判为损坏；
/// 当前写侧也刻意保持这一格式，让旧设备能读新设备的数据。
List<int> _encodeLegacy(List<int> plain) {
  return Encrypter(
    AES(Key.fromUtf8('XY!Ex3j3hP^BGPFanYEjBA!L!oD2kkCN'), mode: AESMode.ctr),
  ).encryptBytes(plain, iv: IV.fromUtf8('7qFwTxwH&iyuw35f')).bytes;
}

/// 带载荷头的实验格式：4 字节 magic + 16 字节 nonce。
const int _headerSize = 4 + 16;

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

    test('reads payloads written before the nonce experiment', () {
      final decoded = ComicSyncCore.decryptPayloadForTest(_encodeLegacy(plain));
      expect(Uint8List.fromList(decoded), equals(Uint8List.fromList(plain)));
    });

    test('reads payloads written with the BSY2 nonce header', () {
      final encoded = ComicSyncCore.buildHeaderedPayloadForTest(
        plain: plain,
        nonce: List<int>.generate(16, (i) => i * 7 % 256),
      );
      final decoded = ComicSyncCore.decryptPayloadForTest(encoded);
      expect(Uint8List.fromList(decoded), equals(Uint8List.fromList(plain)));
    });

    // 兼容性的关键方向：旧版本只会解「固定 nonce、无载荷头」这一种格式。
    // 写侧一旦改成带新框架的字节，旧设备读取新设备数据就会失败，
    // 所以在所有在用设备都具备新格式读取能力之前，这里必须逐字节等于旧编码器。
    test('writes the legacy framing so older builds can read it', () {
      final longPlain = Uint8List.fromList(
        List<int>.generate(4096, (i) => (i * 31 + 7) % 256),
      );
      final encoded = ComicSyncCore.encryptPayloadForTest(longPlain);
      expect(
        Uint8List.fromList(encoded),
        equals(Uint8List.fromList(_encodeLegacy(longPlain))),
      );
      expect(
        encoded.sublist(0, 4),
        isNot(equals(<int>[0x42, 0x53, 0x59, 0x32])),
      );
      // 带载荷头的格式会额外多出 20 字节。
      expect(encoded.length, lessThan(longPlain.length + _headerSize));
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
  });
}
