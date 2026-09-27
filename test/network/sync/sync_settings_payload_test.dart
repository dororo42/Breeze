import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/network/sync/sync_service.dart';

void main() {
  const withCredentials = GlobalSettingState(
    syncSetting: SyncSettingState(
      syncServiceType: SyncServiceType.webdav,
      settingsSyncTime: 1700000000000,
      webdavSetting: WebDavSettingState(
        host: 'https://dav.example.com/breeze',
        username: 'doro',
        password: 'correct horse battery staple',
      ),
      s3Setting: S3SettingState(
        endpoint: 's3.example.com',
        accessKey: 'AKIAEXAMPLEEXAMPLE',
        secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        bucket: 'breeze',
        region: 'ap-east-1',
      ),
    ),
  );

  // 载荷密钥是硬编码在公开仓库里的，云端又存着同一份设置——口令一旦跟着上传，
  // 任何拿到这份云端文件的人都能直接解密读出。
  group('stripSyncCredentials', () {
    test('drops the sync passwords and keys', () {
      final webdav =
          stripSyncCredentials(withCredentials)['syncSetting']
              as Map<String, dynamic>;
      final webdavAccount = webdav['webdavSetting'] as Map<String, dynamic>;
      final s3Account = webdav['s3Setting'] as Map<String, dynamic>;

      expect(webdavAccount['password'], isEmpty);
      expect(s3Account['accessKey'], isEmpty);
      expect(s3Account['secretKey'], isEmpty);
      expect(
        webdav.values.whereType<String>().join('\n'),
        isNot(contains('correct horse battery staple')),
      );
    });

    // 新设备要能认出该连哪台服务，所以只清凭据、不清坐标。
    test('keeps the coordinates needed to recognise the service again', () {
      final sync =
          stripSyncCredentials(withCredentials)['syncSetting']
              as Map<String, dynamic>;
      final webdav = sync['webdavSetting'] as Map<String, dynamic>;
      final s3 = sync['s3Setting'] as Map<String, dynamic>;

      expect(webdav['host'], 'https://dav.example.com/breeze');
      expect(webdav['username'], 'doro');
      expect(s3['endpoint'], 's3.example.com');
      expect(s3['bucket'], 'breeze');
      expect(s3['region'], 'ap-east-1');
    });

    test('resets settingsSyncTime so it never overwrites the local clock', () {
      final sync =
          stripSyncCredentials(withCredentials)['syncSetting']
              as Map<String, dynamic>;
      expect(sync['settingsSyncTime'], 0);
    });

    test('survives the json round-trip without rehydrating credentials', () {
      final restored = GlobalSettingState.fromJson(
        stripSyncCredentials(withCredentials),
      );
      expect(restored.syncSetting.webdavSetting.password, isEmpty);
      expect(restored.syncSetting.s3Setting.accessKey, isEmpty);
      expect(restored.syncSetting.s3Setting.secretKey, isEmpty);
    });
  });
}
