// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Compiled ahead of time by test/aot/aot_compile_test.dart, never run: apps
// of the aud_midi family build release snapshots for Android, iOS, macOS
// and Linux that contain the Windows backend and its dnsapi.dll binding.
//
// The shape follows the platform selection of aud_midi: the backend is
// created, the advertiser only torn off into a lazy wrapper whose register
// is never called. With a completion callback typed by win32's
// PDNS_SERVICE_REGISTER_COMPLETE this failed in the snapshotter with
// "Class with illegal cid" for DNS_SERVICE_INSTANCE.

// ignore_for_file: avoid_print

import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:aud_midi_windows/aud_midi_windows.dart';

void main() {
  print([
    WindowsMidiBackend(),
    _LazyAdvertiser(WindowsMidiServiceAdvertiser.new),
  ]);
}

// #############################################################################
/// Creates the advertiser at the first registration, as aud_midi does.
final class _LazyAdvertiser implements MidiServiceAdvertiser {
  /// Wraps the advertiser that [_create] returns.
  _LazyAdvertiser(this._create);

  // ...........................................................................
  @override
  Future<MidiServiceRegistration> register({
    required String name,
    required String type,
    required int port,
    Map<String, String> txt = const {},
  }) => (_advertiser ??= _create()).register(
    name: name,
    type: type,
    port: port,
    txt: txt,
  );

  final MidiServiceAdvertiser Function() _create;
  MidiServiceAdvertiser? _advertiser;
}
