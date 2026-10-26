import 'package:flutter/services.dart';

/// A persistent reference to a user-selected document, without an audio copy.
/// Persist [bookmark], not [uri]: providers can relocate their documents.
final class DarwinDocumentReference {
  const DarwinDocumentReference({
    required this.bookmark,
    required this.uri,
    required this.name,
    required this.isDirectory,
    required this.identity,
  });

  factory DarwinDocumentReference.fromMap(Map<Object?, Object?> map) =>
      DarwinDocumentReference(
        bookmark: map['bookmark'] as Uint8List,
        uri: Uri.parse(map['uri'] as String),
        name: map['name'] as String,
        isDirectory: map['isDirectory'] as bool,
        identity: map['identity'] as String,
      );

  final Uint8List bookmark;
  final Uri uri;
  final String name;
  final bool isDirectory;

  /// Resource identity where available, otherwise a canonical file URI.
  /// This is a file identity, not a content hash.
  final String identity;
}

/// Access that must remain alive until the underlying reader/player releases
/// the URL. Pausing playback does not mean its file is no longer in use.
final class DarwinDocumentLease {
  DarwinDocumentLease._(this.id, this.reference);
  final String id;
  final DarwinDocumentReference reference;
  Future<void>? _release;

  Future<void> release() => _release ??= DarwinDocumentReferences._channel
      .invokeMethod<void>('referenceRelease', {'leaseId': id});
}

/// Opt-in open-in-place selection. Existing FilePicker calls are unchanged.
/// Reads must use file coordination where required by the document provider.
abstract final class DarwinDocumentReferences {
  static const _channel = MethodChannel(
    'miguelruivo.flutter.plugins.filepicker',
  );

  static Future<List<DarwinDocumentReference>> pick({
    List<String> allowedExtensions = const [],
    bool directory = false,
    bool multiple = true,
    int? viewId,
  }) async {
    final maps = await _channel
        .invokeListMethod<Map<Object?, Object?>>('custom', {
          'openInPlace': true,
          'referenceDirectory': directory,
          'allowMultipleSelection': multiple,
          'allowedExtensions': allowedExtensions,
          'viewId': ?viewId,
        });
    return maps?.map(DarwinDocumentReference.fromMap).toList() ?? const [];
  }

  /// Resolve a saved bookmark and begin access. Persist the returned bookmark
  /// again, as the OS may have refreshed a stale one.
  static Future<DarwinDocumentLease> acquire(Uint8List bookmark) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'referenceAcquire',
      {'bookmark': bookmark},
    );
    if (map == null) throw StateError('Missing document access response');
    return DarwinDocumentLease._(
      map['leaseId'] as String,
      DarwinDocumentReference.fromMap(map),
    );
  }
}
