import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_file_picker/android_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SAF descriptors, children and metadata keep content URIs without file paths',
    () async {
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      final uri = Uri.parse('content://provider/tree/root/document/child');
      final descriptor = {
        'identity': 'provider/child',
        'uri': uri.toString(),
        'name': 'song.flac',
        'directory': false,
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.arguments, {'uri': uri.toString()});
            if (call.method == 'documentChildren') return [descriptor];
            if (call.method == 'documentMetadata')
              return {'title': 'Song', 'duration': '1000'};
            return descriptor;
          });
      expect(
        (await AndroidDocumentReferences.describe(uri))['uri'],
        uri.toString(),
      );
      expect(
        (await AndroidDocumentReferences.children(uri)).single['identity'],
        'provider/child',
      );
      expect(
        (await AndroidDocumentReferences.metadata(uri))['duration'],
        '1000',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}
