// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../../hook/build.dart' as hook;

// native_toolchain_c starts vcvars64.bat by its bare name in its folder,
// which cmd refuses while NoDefaultCurrentDirectoryInExePath is set, as in
// the terminals of the Claude app. Flutter builds are not affected: they
// hand the hooks an environment without it.
final _noVcvars =
    Platform.environment.containsKey('NoDefaultCurrentDirectoryInExePath')
    ? 'native_toolchain_c cannot start vcvars64.bat while '
          'NoDefaultCurrentDirectoryInExePath is set'
    : null;

void main() {
  group('hook/build.dart', () {
    for (final os in [OS.macOS, OS.linux, OS.android, OS.iOS]) {
      test('builds nothing for ${os.name}', () async {
        await testCodeBuildHook(
          mainMethod: hook.main,
          targetOS: os,
          targetArchitecture: Architecture.arm64,
          check: (input, output) {
            expect(output.assets.encodedAssets, isEmpty);
          },
        );
      });
    }

    test(
      'builds the shim for Windows',
      () async {
        await testCodeBuildHook(
          mainMethod: hook.main,
          targetOS: OS.windows,
          check: (input, output) {
            expect([
              for (final asset in output.assets.code) asset.id,
            ], equals(['package:aud_midi_windows/aud_midi_windows_shim']));
          },
        );
      },
      testOn: 'windows',
      skip: _noVcvars,
    );
  });
}
