import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker_darwin/file_picker_darwin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'children require an active lease and preserve durable child bookmarks',
    () async {
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            final descriptor = {
              'bookmark': Uint8List.fromList([1, 2]),
              'uri': 'file:///source',
              'name': 'source',
              'isDirectory': true,
              'identity': 'root',
            };
            if (call.method == 'referenceAcquire')
              return {...descriptor, 'leaseId': 'lease'};
            if (call.method == 'referenceChildren') {
              expect(call.arguments, {'leaseId': 'lease'});
              return [
                {
                  ...descriptor,
                  'name': 'song.flac',
                  'isDirectory': false,
                  'identity': 'child',
                },
              ];
            }
            return null;
          });
      final lease = await DarwinDocumentReferences.acquire(
        Uint8List.fromList([1]),
      );
      final children = await lease.children();
      expect(children.single.identity, 'child');
      expect(children.single.isDirectory, isFalse);
      expect(children.single.bookmark, [1, 2]);
      await lease.release();
      await lease.release();
      expect(calls.where((c) => c.method == 'referenceRelease'), hasLength(1));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}
