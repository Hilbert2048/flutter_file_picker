# Vyn document references

Base: upstream `file_picker-v13.3.0`, commit
`83c3ea4d40b618c3735a27b4cef8a48579f59001`.
The existing fork master is an ancestor of this release; it is preserved.

## Why this fork exists

First upgrade the facade to official file_picker 13.3.0. Its federated platform
implementations are the reuse boundary. Source inspection of Darwin 2.4.0 shows
Files selections use `asCopy: true`; the `copyMedia` option only affects Photos.
Android 2.1.2 supports SAF lifetime grants but still copies every selected file
before returning it. Only these two platform packages are changed here.

Default picking remains compatible, including copy-to-temporary behavior.
No user audio is copied, moved or deleted by the new reference paths.

## Apple references

Import `package:file_picker_darwin/file_picker_darwin.dart`.

```dart
final refs = await DarwinDocumentReferences.pick(
  allowedExtensions: ['flac', 'mp3'],
);
// For a directory: pick(directory: true, multiple: false).
// Persist refs.single.bookmark, not its current URI.
final lease = await DarwinDocumentReferences.acquire(refs.single.bookmark);
try {
  // Persist lease.reference.bookmark again: stale bookmarks are refreshed.
  // Use lease.reference.uri while the lease is alive.
  // Coordinate document reads as required by the provider.
} finally {
  await lease.release();
}
```

The API reuses the existing document picker and macOS panel, with opt-in native
arguments. It retains no selection-time scopes; acquire/release pairs hold each
playback/read scope explicitly, including while playback is paused. Bookmark
resolution and file coordination run off the UI thread. Error codes include
`not_found`, `permission_denied`, `authorization_required`, `provider_unavailable` and
`document_access_failed`; unknown native errors retain domain/code only.

macOS consumers need user-selected read access and app-scoped bookmark access
entitlements. iOS bookmarks use the platform's minimal-bookmark mechanism;
macOS uses a read-only security-scoped bookmark. This does not grant access to
arbitrary unselected paths. A cloud provider can download/cache its own content.

## Android references

```dart
final files = await FilePicker.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['flac', 'mp3'],
  androidOptions: const FilePickerAndroidOptions(
    safOptions: AndroidSAFOptions(
      grant: AndroidSAFGrant.lifetime,
      cacheFiles: false,
    ),
  ),
);
```

Import Android options from `package:android_file_picker/android_file_picker.dart`.
Reference selection uses OPEN_DOCUMENT, requires automatic persistent grants,
and returns before opening an input stream or allocating a cached audio path.
The URI is `content://`; `path` is null. Read/play through ContentResolver or a
URI-capable player, not dart:io File/XFile. Existing lifetime/release-grant APIs
are reused. Grant failures are errors, never a fallback to copying.
`cacheFiles` defaults to true. Reference mode bypasses media compression.

## Validation

- Dart: `flutter test --no-pub packages/file_picker_darwin/test packages/file_picker_android/test`
  (42 passed, including defaults, cancellation, bookmark refresh/release and URI mode).
- Dart analysis of both platform packages passed.
- Android: Vyn isolated checkout `./gradlew :android_file_picker:testDebugUnitTest`
  passed, including Kotlin compilation and SAF option policy tests.
- iOS: isolated Vyn workspace and separate reference probe compiled for Simulator
  with explicit external DerivedData directories; no real-device installation.
- Simulator: a separate fixture app exposes a 225-file, 6,365,199,742-byte music
  directory. Source audio stays in that app; a separate probe acquired the directory,
  recursively read 225 files through a persisted bookmark and played external FLAC.
  Its own container contained no imported FLAC/MP3 copy. Directory and single-file
  bookmarks survived process termination/relaunch; a BEYOND FLAC played again.
- Native Swift error-policy regression: 6 classifications passed, including
  File Provider noSuchItem (-1005), authentication, network and nested errors.
- Android failed reference selections roll back only newly acquired grant bits;
  existing grants are preserved (native JVM regression included).

Simulator evidence does not certify cloud/offline behavior or permission revocation
on real hardware. Android device behavior and sandboxed macOS persistence still
need native acceptance. Vyn's macOS host build currently has unrelated missing
PlayingMusicQueue.swift/PlayingWindowPreparation.swift inputs; the Darwin plugin
compiled before the host failed.

## Maintenance and module boundary

Keep the facade/interface packages official. Consumers override only these platform
packages to a reviewed full Git SHA, because the facade's hosted dependencies
otherwise conflict with direct Git dependencies of another source. Never depend
on a floating branch or local absolute paths in production.

DocumentReferenceStore owns the new Apple lifetime state in a separate file.
The upstream large picker handlers only receive selection/routing glue. Android's
existing FileUtils is slightly over 800 lines; the narrow no-cache branch and SAF
plumbing intentionally stay beside its existing selection pipeline to avoid a broad
upstream refactor. No task/scanner/library business logic belongs in this fork.
