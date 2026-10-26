import 'package:file_picker_darwin/file_picker_darwin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final saved = Uint8List.fromList([1, 2, 3]);
  Map<String, Object> reference(Uint8List bookmark) => {
    'bookmark': bookmark,
    'uri': 'file:///external/album/song.flac',
    'name': 'song.flac',
    'isDirectory': false,
    'identity': 'volume/file',
  };
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'selection opts into existing document picker without copying',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'custom');
        expect(call.arguments['openInPlace'], isTrue);
        expect(call.arguments['referenceDirectory'], isTrue);
        expect(call.arguments['allowMultipleSelection'], isFalse);
        return [reference(saved)];
      });
      final files = await DarwinDocumentReferences.pick(
        directory: true,
        multiple: false,
      );
      expect(files.single.bookmark, saved);
      expect(files.single.identity, 'volume/file');
    },
  );

  test('cancel returns no references', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await DarwinDocumentReferences.pick(), isEmpty);
  });

  test('saved bookmark is resolved, refreshed and released once', () async {
    final refreshed = Uint8List.fromList([4, 5]);
    var releases = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'referenceAcquire') {
        expect(call.arguments['bookmark'], saved);
        return {...reference(refreshed), 'leaseId': 'lease-1'};
      }
      expect(call.method, 'referenceRelease');
      expect(call.arguments['leaseId'], 'lease-1');
      releases++;
      return null;
    });
    final lease = await DarwinDocumentReferences.acquire(saved);
    expect(lease.reference.bookmark, refreshed);
    await Future.wait([lease.release(), lease.release()]);
    expect(releases, 1);
  });

  test(
    'missing and revoked access are failures rather than cancellations',
    () async {
      for (final code in [
        'not_found',
        'permission_denied',
        'provider_unavailable',
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: code),
        );
        await expectLater(
          DarwinDocumentReferences.acquire(saved),
          throwsA(isA<PlatformException>().having((e) => e.code, 'code', code)),
        );
      }
    },
  );
}
