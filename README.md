# aud_midi_windows

English | [Deutsch](README.de.md)

Windows backend for aud_midi: Windows.Devices.Midi and Windows MIDI
Services. The Windows backend of aud_midi: Windows.Devices.Midi and, when
present, Windows MIDI Services through a C++/WinRT shim, Bluetooth LE MIDI
pairing and DNS-SD advertising for network sessions. Runs on Windows only.

Part of the aud_midi family, see [aud_midi](https://github.com/audmidi/aud_midi).

## Motivation

Dart and Flutter apps should reach the MIDI devices of their users through
one API on every platform, without platform channels or native code of
their own. This package brings Windows into that family: the WinRT MIDI
APIs behind the same `MidiBackend` as the other platforms, with the native
part as a small shim that the app never has to touch and that never blocks
a UI thread.

- Windows.Devices.Midi ports with receive time stamps and DeviceWatcher
  hotplug
- Windows MIDI Services (Midi2) detected at runtime: UMP, scheduling,
  virtual devices, function blocks
- C++/WinRT shim built by a hook, never blocking an STA thread
- In-app pairing of BLE-MIDI peripherals
- Advertising via DnsServiceRegister
- BLE peripheral through GattServiceProvider

## Installation

```bash
dart pub add aud_midi_windows
```

### Build on Windows

Needs Windows 10 1607+ (DNS-SD advertising 1903+) and Visual Studio 2022
or its Build Tools with "Desktop development with C++" and a Windows 11
SDK; native_toolchain_c finds `cl.exe` through vswhere. The hook compiles
`src/aud_midi_windows.cpp` (C++20, `/EHsc`, `WindowsApp.lib`) into the
code asset `package:aud_midi_windows/aud_midi_windows_shim`.

### Enable Windows MIDI Services

The Midi2 path is compiled only with `AUD_MIDI_WITH_MIDI2`, because the
`Windows.Devices.Midi2` projection comes from NuGet, not from the Windows
SDK:

1. Get the NuGet packages `Windows.Devices.Midi2` (winmd) and
   `Microsoft.Windows.CppWinRT` 3.x (`cppwinrt.exe`).
2. Generate the projection, including the Windows SDK it refers to, from
   the extracted `Windows.Devices.Midi2` package:

   ```powershell
   cppwinrt -input Windows.Devices.Midi2\ref\native\Windows.Devices.Midi2.winmd `
     -reference sdk -output third_party\midi2
   ```

3. Turn it on in the `pubspec.yaml` of the app:

   ```yaml
   hooks:
     user_defines:
       aud_midi_windows:
         midi2: true
         midi2_include: third_party/midi2
   ```

At runtime the shim asks for `MidiApi` (`try_get_activation_factory`),
`EnsureServiceAvailable` and the API mode; without them it reports byte
ports only. Where the API is not in-box yet, `Windows.Devices.Midi2.dll`
of the package (`runtimes\win-<arch>\native`) must lie next to the
executable. Windows MIDI Services before the November 2026 release can
hang when a virtual device is torn down (microsoft/MIDI#1047).

### Permissions and packaging

- Unpackaged apps need nothing.
- MSIX: `<DeviceCapability Name="bluetooth" />` for BLE-MIDI, and
  `<Capability Name="internetClient" />` plus
  `<Capability Name="privateNetworkClientServer" />` for network
  sessions; the firewall asks for UDP 5004/5005 on first use.

## Usage

List the Windows MIDI ports, open every input and, where Windows MIDI
Services offers virtual devices, play a MIDI 2.0 note on a virtual port;
runs on Windows:

```dart
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
```

## Limitations

- Runs on Windows only; the hook builds nothing for macOS, Linux, Android
  and iOS.
- Without Windows MIDI Services (not built in, not present or in legacy
  mode) the backend reports byte ports only and `virtualPorts` is `null`;
  WinRT MIDI 1.0 outputs send at once, the engine schedules in software.
- Not verified: the shim against the real Windows SDK and C++/WinRT
  headers, every native call (FFI glue
  `lib/src/shim/windows_midi_ffi_shim.dart`,
  `lib/src/advertiser/windows_dns_sd_ffi_api.dart`, both
  coverage-ignored), real devices, BLE pairing, the Midi2 path and the
  hook build with MSVC. The Windows tests under Contributing cover them.

## Documentation

- [Guides](doc/guides/)
- The plan in [aud_midi_pm](https://github.com/audmidi/aud_midi_pm/blob/main/doc/2026-Q4/tickets/2026-10-06-aud_midi_01-initial-midi-implementation.md)

## How it works

- `WindowsMidiBackend` (`MidiBackend`, name `winrt`) with
  `WindowsMidiApi.auto` (default), `midi1` or `midi2`:
  - WinRT MIDI 1.0: every `MidiInPort` is a byte input with time stamps,
    every `MidiOutPort` a byte output that sends at once (the engine
    schedules in software). Each port is a synthetic one-port device.
    Ids: `winrt:in:<DeviceInformation.Id>`, `winrt:out:<…>`.
  - Windows MIDI Services (when built in, present and not in legacy
    mode): every endpoint is a UMP input and output on one device, with
    groups, function blocks and endpoint info; outputs schedule in the
    service (`scheduledSend`). Ids: `winrt:umpin:<endpoint id>`,
    `winrt:umpout:<…>`. In hybrid legacy mode both APIs run side by side.
  - Hotplug: DeviceWatcher / MidiEndpointDeviceWatcher → added, removed
    and changed ports; ports that disappear are closed; a disconnected
    endpoint becomes `MidiPortState.disconnected`.
  - Time: WinRT MIDI 1.0 time stamps (time since the port was created)
    plus a QueryPerformanceCounter base taken at open; Midi2 time stamps
    are QPC ticks. `MidiClockMapper` maps QPC to the package clock,
    every 10 s and on hotplug.
  - `bluetooth`: scans the BLE-MIDI service with an active advertisement
    watcher, connects by pairing (confirm-only ceremony) and waits for
    the WinRT ports of the peripheral; disconnect unpairs.
  - `virtualPorts`: virtual devices of Windows MIDI Services, one
    function block each; `null` without Midi2.
- `WindowsMidiServiceAdvertiser` (`MidiServiceAdvertiser`):
  `DnsServiceRegister` / `DnsServiceDeRegister` of dnsapi.dll through
  `package:win32`, completion through `NativeCallable.listener`.
- `WindowsMidiFakeShim`: simulates the shim for tests of apps.

The shim:

- `src/aud_midi_windows.h`: a plain C API with opaque handles; results
  are HRESULTs, events and data leave the shim as little-endian byte
  buffers.
- `src/aud_midi_windows.cpp`: a worker thread in the multithreaded
  apartment owns every WinRT object, so callers never block an STA
  thread. WinRT raises events on thread pool threads; they copy messages
  into a ring buffer per port and events into a queue, then call a
  `NativeCallable.listener` once until the backend drains. A callback
  gate makes `amw_destroy` wait until no callback runs before the Dart
  side closes the callable.
- `src/aud_midi_windows_core.h`: the portable parts, tested natively.
- The Dart side decodes the buffers and owns all logic.

## Status

Before 1.0 — the API may change between minor versions.

Implemented; **not yet built or run on Windows**. All Dart logic is
tested on the Dart VM, the portable half of the shim on macOS; the WinRT
half is reviewed against the Windows SDK reference and the Windows MIDI
Services IDL, but never compiled against the real headers.

How it is verified:

| Check | Result |
| --- | --- |
| Dart unit tests, macOS VM | 100 % line coverage per file from its own test |
| Portable shim core (`tool/test_native_core.sh`) | ring buffer, event queue, callback gate, worker, BLE filter, clock math, MIDI splitting; ASan/UBSan and TSan clean |
| Byte format C++ ↔ Dart | golden files written by the C++ test, decoded by the Dart tests; the virtual device spec the other way round |
| WinRT shim | compiles with `-Wall -Wextra -Wconversion -Werror` against stand-in headers of the used projection surface (catches errors inside the shim, not API mismatches) |
| Hook | builds nothing for macOS, Linux, Android and iOS |
| AOT compile (`test/aot/aot_compile_test.dart`) | `dart compile aot-snapshot` of the backend and a lazily created advertiser succeeds; guards release builds for other platforms against "Class with illegal cid" |

## Contributing

See [doc/guides/develop-guide.md](doc/guides/develop-guide.md).

### Test on Windows

With the build requirements above in place:

```powershell
dart test
```

Windows-only tests:

- `test/shim/windows_midi_ffi_shim_test.dart`: context, clock, every
  port opened and closed, UMP loopback through the diagnostic loopback
  endpoints (Midi2), byte loopback through a loopMIDI-style driver, a
  note on the Microsoft GS Wavetable Synth (smoke test).
- `test/advertiser/windows_dns_sd_ffi_api_test.dart`: registers and
  withdraws `_apple-midi._udp` and `_midi2._udp` services.
- `test/hook/build_test.dart`: the hook emits the shim.

### Regenerate the bindings

```bash
dart run ffigen --config ffigen.yaml  # bindings of src/aud_midi_windows.h
tool/test_native_core.sh              # native core test, checks the goldens
tool/test_native_core.sh --update     # rewrites test/goldens
```

## License

MIT — see [LICENSE](LICENSE).
