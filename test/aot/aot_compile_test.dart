// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  // The AOT compiler of the running Dart SDK. An AOT snapshot needs no other
  // tool: no C toolchain, no build hooks and, unlike `dart compile exe` on
  // macOS, no codesign.
  final genSnapshot = File.fromUri(
    Uri.file(Platform.resolvedExecutable).resolve(
      Platform.isWindows ? 'utils/gen_snapshot.exe' : 'utils/gen_snapshot',
    ),
  );

  group('aud_midi_windows.dart', () {
    // Apps of the aud_midi family contain the Windows backend in their
    // release builds for every platform, see test/fixtures/aot/main.dart.
    // gen_snapshot is where such a build fails.
    test(
      'compiles ahead of time where it does not run',
      () async {
        final out = await Directory.systemTemp.createTemp('aud_aot_');
        addTearDown(() => out.delete(recursive: true));
        final result = await Process.run(Platform.resolvedExecutable, [
          'compile',
          'aot-snapshot',
          '-o',
          '${out.path}/main.aot',
          'test/fixtures/aot/main.dart',
        ]);
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      },
      skip: genSnapshot.existsSync()
          ? false
          : 'the Dart SDK has no AOT compiler at ${genSnapshot.path}',
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
