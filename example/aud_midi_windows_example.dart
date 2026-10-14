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
  print(backend.capabilities);

  for (final port in backend.ports) {
    print(
      '${port.id} ${port.direction.name} ${port.name} '
      '(${port.transport.name}, ${port.protocol.name}, ${port.state.name})',
    );
    if (port.isInput) await backend.openPort(port.id);
  }

  final virtualPorts = backend.virtualPorts;
  if (virtualPorts != null) {
    final source = await virtualPorts.create(
      MidiVirtualPortSpec(
        name: 'aud_midi_windows example',
        direction: MidiDirection.output,
        protocol: MidiProtocol.midi2,
      ),
    );
    // MIDI 2.0 Note On and Note Off of middle C on group 0, channel 0.
    const clock = MidiSystemClock();
    await backend.send(
      source.id,
      MidiUmpPacket(words: const [0x40903c00, 0xc8000000], time: clock.now()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await backend.send(
      source.id,
      MidiUmpPacket(words: const [0x40803c00, 0x00000000], time: clock.now()),
    );
  }

  await Future<void>.delayed(const Duration(seconds: 1));
  await backend.stop();
}

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
