import 'package:flutter/services.dart';

/// SAF descriptors and header metadata. Content remains at the provider URI.
abstract final class AndroidDocumentReferences {
  static const _channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  static Future<Map<String, dynamic>> describe(Uri uri) async =>
    Map<String, dynamic>.from((await _channel.invokeMapMethod<String, dynamic>('documentDescribe', {'uri': uri.toString()}))!);
  static Future<List<Map<String, dynamic>>> children(Uri uri) async =>
    (await _channel.invokeListMethod<Map>('documentChildren', {'uri': uri.toString()}))!
      .map((value) => Map<String, dynamic>.from(value)).toList();
  static Future<Map<String, dynamic>> metadata(Uri uri) async =>
    Map<String, dynamic>.from((await _channel.invokeMapMethod<String, dynamic>('documentMetadata', {'uri': uri.toString()}))!);
}
