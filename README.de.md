# aud_midi_windows

[English](README.md) | Deutsch

Windows-Backend für aud_midi: Windows.Devices.Midi und Windows MIDI
Services. Das Windows-Backend von aud_midi: Windows.Devices.Midi und, falls
vorhanden, Windows MIDI Services über einen C++/WinRT-Shim,
Bluetooth-LE-MIDI-Pairing und DNS-SD-Advertising für Netzwerk-Sessions.
Läuft nur unter Windows.

Teil der aud_midi-Familie, siehe [aud_midi](https://github.com/audmidi/aud_midi).

## Motivation

Dart- und Flutter-Apps sollen die MIDI-Geräte ihrer Nutzer auf jeder
Plattform über eine API erreichen, ohne eigene Platform-Channels oder
nativen Code. Dieses Paket holt Windows in diese Familie: die
WinRT-MIDI-APIs hinter demselben `MidiBackend` wie die anderen
Plattformen, mit dem nativen Teil als kleinem Shim, den die App nie
anfassen muss und der nie einen UI-Thread blockiert.

- Windows.Devices.Midi-Ports mit Empfangszeitstempeln und
  DeviceWatcher-Hotplug
- Windows MIDI Services (Midi2) zur Laufzeit erkannt: UMP, Scheduling,
  virtuelle Geräte, Function Blocks
- C++/WinRT-Shim, gebaut per Hook, blockiert nie einen STA-Thread
- Pairing von BLE-MIDI-Peripheriegeräten in der App
- Advertising über DnsServiceRegister
- BLE-Peripheral über GattServiceProvider

## Installation

```bash
dart pub add aud_midi_windows
```

### Bauen unter Windows

Braucht Windows 10 1607+ (DNS-SD-Advertising 1903+) und Visual Studio
2022 oder dessen Build Tools mit „Desktopentwicklung mit C++“ und einem
Windows 11 SDK; native_toolchain_c findet `cl.exe` über vswhere. Der Hook
kompiliert `src/aud_midi_windows.cpp` (C++20, `/EHsc`, `WindowsApp.lib`)
zum Code-Asset `package:aud_midi_windows/aud_midi_windows_shim`.

### Windows MIDI Services einschalten

Der Midi2-Pfad wird nur mit `AUD_MIDI_WITH_MIDI2` kompiliert, weil die
Projektion von `Windows.Devices.Midi2` aus NuGet kommt, nicht aus dem
Windows SDK:

1. Die NuGet-Pakete `Windows.Devices.Midi2` (winmd) und
   `Microsoft.Windows.CppWinRT` 3.x (`cppwinrt.exe`) holen.
2. Die Projektion samt dem referenzierten Windows SDK aus dem entpackten
   Paket `Windows.Devices.Midi2` erzeugen:

   ```powershell
   cppwinrt -input Windows.Devices.Midi2\ref\native\Windows.Devices.Midi2.winmd `
     -reference sdk -output third_party\midi2
   ```

3. In der `pubspec.yaml` der App einschalten:

   ```yaml
   hooks:
     user_defines:
       aud_midi_windows:
         midi2: true
         midi2_include: third_party/midi2
   ```

Zur Laufzeit fragt der Shim `MidiApi` (`try_get_activation_factory`),
`EnsureServiceAvailable` und den API-Modus ab; ohne sie meldet er nur
Byte-Ports. Wo die API noch nicht zu Windows gehört, muss
`Windows.Devices.Midi2.dll` des Pakets (`runtimes\win-<arch>\native`)
neben der ausführbaren Datei liegen. Windows MIDI Services vor dem
Release vom November 2026 kann beim Abbau eines virtuellen Geräts hängen
(microsoft/MIDI#1047).

### Berechtigungen und Paketierung

- Unpaketierte Apps brauchen nichts.
- MSIX: `<DeviceCapability Name="bluetooth" />` für BLE-MIDI sowie
  `<Capability Name="internetClient" />` und
  `<Capability Name="privateNetworkClientServer" />` für
  Netzwerk-Sessions; die Firewall fragt beim ersten Mal nach UDP
  5004/5005.

## Verwendung

Die Windows-MIDI-Ports auflisten, jeden Eingang öffnen und, wo Windows
MIDI Services virtuelle Geräte anbietet, eine MIDI-2.0-Note auf einem
virtuellen Port spielen; läuft unter Windows:

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

## Einschränkungen

- Läuft nur unter Windows; der Hook baut nichts für macOS, Linux, Android
  und iOS.
- Ohne Windows MIDI Services (nicht eingebaut, nicht vorhanden oder im
  Legacy-Modus) meldet das Backend nur Byte-Ports und `virtualPorts` ist
  `null`; WinRT-MIDI-1.0-Ausgänge senden sofort, die Engine plant in
  Software.
- Nicht geprüft: der Shim gegen das echte Windows SDK und die
  C++/WinRT-Header, jeder native Aufruf (FFI-Schicht
  `lib/src/shim/windows_midi_ffi_shim.dart`,
  `lib/src/advertiser/windows_dns_sd_ffi_api.dart`, beide von der
  Abdeckung ausgenommen), echte Geräte, BLE-Pairing, der Midi2-Pfad und
  der Hook-Build mit MSVC. Die Windows-Tests unter Mitwirken decken sie
  ab.

## Dokumentation

- [Guides](doc/guides/)
- Der Plan in [aud_midi_pm](https://github.com/audmidi/aud_midi_pm/blob/main/doc/2026-Q4/tickets/2026-10-06-aud_midi_01-initial-midi-implementation.md)

## Funktionsweise

- `WindowsMidiBackend` (`MidiBackend`, Name `winrt`) mit
  `WindowsMidiApi.auto` (Standard), `midi1` oder `midi2`:
  - WinRT MIDI 1.0: jeder `MidiInPort` ist ein Byte-Eingang mit
    Zeitstempeln, jeder `MidiOutPort` ein Byte-Ausgang, der sofort sendet
    (die Engine plant in Software). Jeder Port ist ein synthetisches
    Gerät mit einem Port. Ids: `winrt:in:<DeviceInformation.Id>`,
    `winrt:out:<…>`.
  - Windows MIDI Services (wenn eingebaut, vorhanden und nicht im
    Legacy-Modus): jeder Endpoint ist ein UMP-Eingang und -Ausgang auf
    einem Gerät, mit Gruppen, Function Blocks und Endpoint-Info; Ausgänge
    planen im Dienst (`scheduledSend`). Ids: `winrt:umpin:<Endpoint-Id>`,
    `winrt:umpout:<…>`. Im Hybrid-Legacy-Modus laufen beide APIs
    nebeneinander.
  - Hotplug: DeviceWatcher / MidiEndpointDeviceWatcher → hinzugefügte,
    entfernte und geänderte Ports; verschwundene Ports werden
    geschlossen; ein getrennter Endpoint wird zu
    `MidiPortState.disconnected`.
  - Zeit: WinRT-MIDI-1.0-Zeitstempel (Zeit seit dem Erzeugen des Ports)
    plus eine beim Öffnen genommene QueryPerformanceCounter-Basis;
    Midi2-Zeitstempel sind QPC-Ticks. `MidiClockMapper` bildet QPC auf die
    Paketuhr ab, alle 10 s und bei Hotplug.
  - `bluetooth`: sucht den BLE-MIDI-Dienst mit einem aktiven
    Advertisement-Watcher, verbindet per Pairing (Bestätigungs-Zeremonie)
    und wartet auf die WinRT-Ports des Geräts; Trennen hebt das Pairing
    auf.
  - `virtualPorts`: virtuelle Geräte von Windows MIDI Services mit je
    einem Function Block; ohne Midi2 `null`.
- `WindowsMidiServiceAdvertiser` (`MidiServiceAdvertiser`):
  `DnsServiceRegister` / `DnsServiceDeRegister` der dnsapi.dll über
  `package:win32`, Abschluss über `NativeCallable.listener`.
- `WindowsMidiFakeShim`: simuliert den Shim für Tests von Apps.

Der Shim:

- `src/aud_midi_windows.h`: eine schlichte C-API mit opaken Handles;
  Ergebnisse sind HRESULTs, Events und Daten verlassen den Shim als
  Little-Endian-Bytepuffer.
- `src/aud_midi_windows.cpp`: ein Worker-Thread im Multithreaded
  Apartment besitzt alle WinRT-Objekte, sodass Aufrufer nie einen
  STA-Thread blockieren. WinRT löst Events auf Threadpool-Threads aus;
  sie kopieren Nachrichten in einen Ringpuffer je Port und Events in eine
  Queue und rufen dann einmal einen `NativeCallable.listener`, bis das
  Backend leert. Ein Callback-Gate lässt `amw_destroy` warten, bis kein
  Callback mehr läuft, bevor die Dart-Seite das Callable schließt.
- `src/aud_midi_windows_core.h`: die portablen Teile, nativ getestet.
- Die Dart-Seite dekodiert die Puffer und enthält die gesamte Logik.

## Status

Vor 1.0 — die API kann sich zwischen Minor-Versionen ändern.

Implementiert; **noch nicht auf Windows gebaut oder ausgeführt**. Die
gesamte Dart-Logik ist auf der Dart-VM getestet, der portable Teil des
Shims auf macOS; der WinRT-Teil ist gegen die Referenz des Windows SDK und
die IDL von Windows MIDI Services geprüft, aber nie gegen die echten
Header kompiliert.

Wie es geprüft ist:

| Prüfung | Ergebnis |
| --- | --- |
| Dart-Unit-Tests, macOS-VM | 100 % Zeilenabdeckung je Datei aus ihrem eigenen Test |
| Portabler Shim-Kern (`tool/test_native_core.sh`) | Ringpuffer, Event-Queue, Callback-Gate, Worker, BLE-Filter, Uhr-Rechnung, MIDI-Zerlegung; ASan/UBSan und TSan sauber |
| Byteformat C++ ↔ Dart | Golden-Dateien schreibt der C++-Test, die Dart-Tests dekodieren sie; die Spezifikation virtueller Geräte umgekehrt |
| WinRT-Shim | kompiliert mit `-Wall -Wextra -Wconversion -Werror` gegen Ersatz-Header der benutzten Projektion (findet Fehler im Shim, keine API-Abweichungen) |
| Hook | baut nichts für macOS, Linux, Android und iOS |
| AOT-Kompilierung (`test/aot/aot_compile_test.dart`) | `dart compile aot-snapshot` des Backends und eines erst bei Bedarf erzeugten Advertisers gelingt; schützt Release-Builds für andere Plattformen vor „Class with illegal cid“ |

## Mitwirken

Siehe [doc/guides/develop-guide.md](doc/guides/develop-guide.md).

### Testen unter Windows

Mit den Build-Voraussetzungen von oben:

```powershell
dart test
```

Tests nur für Windows:

- `test/shim/windows_midi_ffi_shim_test.dart`: Kontext, Uhr, jeder Port
  geöffnet und geschlossen, UMP-Loopback über die Diagnose-Loopback-
  Endpoints (Midi2), Byte-Loopback über einen Treiber wie loopMIDI, eine
  Note auf dem Microsoft GS Wavetable Synth (Smoke-Test).
- `test/advertiser/windows_dns_sd_ffi_api_test.dart`: registriert und
  entfernt `_apple-midi._udp`- und `_midi2._udp`-Dienste.
- `test/hook/build_test.dart`: der Hook liefert den Shim.

### Bindings neu erzeugen

```bash
dart run ffigen --config ffigen.yaml  # bindings of src/aud_midi_windows.h
tool/test_native_core.sh              # native core test, checks the goldens
tool/test_native_core.sh --update     # rewrites test/goldens
```

## Lizenz

MIT — siehe [LICENSE](LICENSE).
