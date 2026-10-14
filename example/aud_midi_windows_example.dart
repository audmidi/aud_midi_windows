// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:aud_midi_standard/aud_midi_standard.dart';
import 'package:aud_midi_windows/aud_midi_windows.dart';

// Lists the Windows MIDI ports, opens all inputs and, where Windows MIDI
// Services offers virtual devices, plays a MIDI 2.0 note on a virtual port
// that other apps can listen to. In apps, the engine of aud_midi_core hosts
// the backend; this host just prints. Runs on Windows only.
Future<void> main() async {
  final backend = WindowsMidiBackend();
  await backend.start(_PrintingHost());
  try {
    print(backend.capabilities);
    await _openInputs(backend);
    await _playNote(backend);
    // Prints what arrives on the inputs for a while.
    await Future<void>.delayed(const Duration(seconds: 1));
  } finally {
    await backend.stop();
  }
}

/// Prints every port of [backend] and opens the inputs side by side.
Future<void> _openInputs(MidiBackend backend) async {
  final ports = backend.ports;
  for (final port in ports) {
    print(
      '${port.id} ${port.direction.name} ${port.name} '
      '(${port.transport.name}, ${port.protocol.name}, ${port.state.name})',
    );
  }
  await Future.wait([
    for (final port in ports)
      if (port.isInput) backend.openPort(port.id),
  ]);
}

/// Plays middle C on group 0, channel 0 of a new virtual MIDI 2.0 port;
/// does nothing when [backend] offers no virtual ports.
Future<void> _playNote(MidiBackend backend) async {
  final virtualPorts = backend.virtualPorts;
  if (virtualPorts == null) return;
  final source = await virtualPorts.create(
    MidiVirtualPortSpec(
      name: 'aud_midi_windows example',
      direction: MidiDirection.output,
      protocol: MidiProtocol.midi2,
    ),
  );
  const clock = MidiSystemClock();
  Future<void> send(MidiMessage message) => backend.send(
    source.id,
    MidiUmpPacket(
      words: UmpEncoder.encode(message).expand((ump) => ump.words),
      time: clock.now(),
    ),
  );

  const note = MidiNoteNumbers.c4;
  await send(const MidiNoteOn2(channel: 0, note: note, velocity: 0xc800));
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await send(const MidiNoteOff2(channel: 0, note: note));
}

// #############################################################################
/// Prints what the backend reports.
final class _PrintingHost implements MidiBackendHost {
  @override
  final MidiClock clock = const MidiSystemClock();

  @override
  void portsChanged(List<MidiPortEvent> events) => events.forEach(print);

  @override
  void received(MidiPortId port, MidiPacket packet) => print('$port $packet');

  @override
  void diagnostic(MidiDiagnostic diagnostic) => print(diagnostic);
}
