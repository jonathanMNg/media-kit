/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: library_private_types_in_public_api
import 'dart:io';
import 'dart:collection';
import 'package:safe_local_storage/safe_local_storage.dart';
import 'package:media_kit/src/player/native/utils/android_content_uri_provider.dart';

import '../../../media_kit.dart';

/// {@template media}
///
/// LazyMedia
/// -----
///
/// A [LazyMedia] object to open inside a [Player] for playback.
///
/// ```dart
/// final player = Player();
/// final playable = LazyMedia('https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4');
/// await player.open(playable);
/// ```
///
/// {@endtemplate}
class LazyMedia extends Media {
  /// The [Finalizer] is invoked when the [LazyMedia] instance is garbage collected.
  /// This has been done to:
  /// 1. Evict the [LazyMedia] instance from [cache].
  /// 2. Close the file descriptor created by [AndroidContentUriProvider] to handle content:// URIs on Android.
  /// 3. Delete the temporary file created by [LazyMedia.memory].
  static final Finalizer<_LazyMediaFinalizerContext> _finalizer =
      Finalizer<_LazyMediaFinalizerContext>(
    (context) async {
      final uri = context.uri;
      final memory = context.memory;
      // Decrement reference count.
      ref[uri] = ((ref[uri] ?? 0) - 1).clamp(0, 1 << 32);
      // Remove [LazyMedia] instance from [cache] if reference count is 0.
      if (ref[uri] == 0) {
        cache.remove(uri);
      }
      // content:// : Close the possible file descriptor on Android.
      try {
        if (Platform.isAndroid) {
          final data = Uri.parse(uri);
          if (data.isScheme('FD')) {
            final fd = int.parse(data.authority);
            if (fd > 0) {
              await AndroidContentUriProvider.closeFileDescriptor(uri);
            }
          }
        }
      } catch (exception, stacktrace) {
        print(exception);
        print(exception);
      }
      // LazyMedia.memory : Delete the temporary file.
      try {
        if (memory) {
          await File(uri).delete_();
        }
      } catch (exception, stacktrace) {
        print(exception);
        print(stacktrace);
      }
    },
  );

  /// {@macro media}
  LazyMedia(
    super.resource, {
    Map<String, dynamic>? extras,
    Map<String, String>? httpHeaders,
    super.start,
    super.end,
  })  {
    // Increment reference count.
    ref[uri] = ((ref[uri] ?? 0) + 1).clamp(0, 1 << 32);
    // Store [this] instance in [cache].
    cache[uri] = _LazyMediaCache(
      extras: this.extras,
      httpHeaders: this.httpHeaders,
    );
    // Attach [this] instance to [Finalizer].
    _finalizer.attach(
      this,
      _LazyMediaFinalizerContext(
        uri,
        false,
      ),
    );
  }


  /// For comparing with other [LazyMedia] instances.
  @override
  bool operator ==(Object other) {
    if (other is LazyMedia) {
      return other.uri == uri;
    }
    return false;
  }

  /// For comparing with other [LazyMedia] instances.
  @override
  int get hashCode => uri.hashCode;

  /// Creates a copy of [this] instance with the given fields replaced with the new values.
  // LazyMedia copyWith({
  //   String? uri,
  //   Map<String, dynamic>? extras,
  //   Map<String, String>? httpHeaders,
  //   Duration? start,
  //   Duration? end,
  // }) {
  //   return LazyMedia(
  //     uri ?? this.uri,
  //     extras: extras ?? this.extras,
  //     httpHeaders: httpHeaders ?? this.httpHeaders,
  //     start: start ?? this.start,
  //     end: end ?? this.end,
  //   );
  // }

  @override
  String toString() =>
      'LazyMedia($uri, extras: $extras, httpHeaders: $httpHeaders, start: $start, end: $end)';

  /// Previously created [LazyMedia] instances.
  /// This [HashMap] is used to retrieve previously set [extras] & [httpHeaders].
  static final HashMap<String, _LazyMediaCache> cache =
      HashMap<String, _LazyMediaCache>();

  /// Previously created [LazyMedia] instances' reference count.
  static final HashMap<String, int> ref = HashMap<String, int>();
}

/// {@template _media_cache}
/// A simple class to pack optional arguments in [LazyMedia] together.
/// {@endtemplate}
class _LazyMediaCache {
  /// Additional optional user data.
  ///
  /// Default: `null`.
  final Map<String, dynamic>? extras;

  /// HTTP headers.
  ///
  /// Default: `null`.
  final Map<String, String>? httpHeaders;

  /// {@macro _media_cache}
  const _LazyMediaCache({
    this.extras,
    this.httpHeaders,
  });

  @override
  String toString() => '_LazyMediaCache('
      'extras: $extras, '
      'httpHeaders: $httpHeaders'
      ')';
}

/// {@template _media_finalizer_context}
/// A simple class to pack the required attributes into [Finalizer] argument.
/// {@endtemplate}
class _LazyMediaFinalizerContext {
  final String uri;
  final bool memory;

  const _LazyMediaFinalizerContext(this.uri, this.memory);

  @override
  String toString() => '_LazyMediaFinalizerContext(uri: $uri, memory: $memory)';
}
