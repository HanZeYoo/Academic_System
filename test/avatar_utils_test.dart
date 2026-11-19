import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_system/utils/avatar_utils.dart';

void main() {
  group('AvatarUtils.getImageProvider Base64 cache', () {
    // 1x1 transparent PNG bytes
    final sampleBytes = Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
      0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84,
      120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69,
      78, 68, 174, 66, 96, 130,
    ]);
    late String dataUri;

    setUp(() {
      AvatarUtils.clearCache();
      dataUri = 'data:image/png;base64,${base64Encode(sampleBytes)}';
    });

    test('returns identical cached MemoryImage instance on repeated calls', () {
      final first = AvatarUtils.getImageProvider(dataUri);
      final second = AvatarUtils.getImageProvider(dataUri);

      expect(first, isA<MemoryImage>());
      expect(identical(first, second), isTrue);
    });

    test('clearCache evicts cached MemoryImage and decodes fresh instance', () {
      final first = AvatarUtils.getImageProvider(dataUri);
      AvatarUtils.clearCache();
      final second = AvatarUtils.getImageProvider(dataUri);

      expect(first, isA<MemoryImage>());
      expect(second, isA<MemoryImage>());
      expect(identical(first, second), isFalse);
    });

    test('handles empty, invalid base64, and network URLs safely', () {
      expect(AvatarUtils.getImageProvider(null), isNull);
      expect(AvatarUtils.getImageProvider('   '), isNull);
      expect(AvatarUtils.getImageProvider('data:image/png;base64,!!!invalid!!!'), isNull);
      expect(AvatarUtils.getImageProvider('https://example.com/avatar.png'), isA<NetworkImage>());
    });
  });
}
