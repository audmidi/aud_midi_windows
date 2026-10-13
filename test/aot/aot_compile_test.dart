// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('aud_midi_windows.dart', () {
    // Apps of the aud_midi family contain the Windows backend in their
    // release builds for every platform, see test/fixtures/aot/main.dart.
    test('compiles ahead of time where it does not run', () async {
      final out = await Directory.systemTemp.createTemp('aud_aot_');
      try {
        final result = await Process.run(Platform.resolvedExecutable, [
          'compile',
          'exe',
          '-o',
          '${out.path}/main.exe',
          'test/fixtures/aot/main.dart',
        ]);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      } finally {
        await out.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
