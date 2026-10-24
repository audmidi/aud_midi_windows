# Changelog

## 0.1.3 - 2026-10-24

### Changed

- Skip the shim build test where cmd cannot find vcvars

## 0.1.2 - 2026-10-14

### Added

- Add void pointers to the DNS-SD callback for AOT builds
- The completion callback and DnsServiceFreeInstance take void pointers; the struct is read through cast()
- An AOT build for another platform crashed on win32's DNS_SERVICE_INSTANCE in the callback signature
- Add test/aot/aot_compile_test.dart: dart compile exe of the backend and the lazy advertiser
- Add the AOT regression test to the README
- README.md and README.de.md list test/aot/aot_compile_test.dart in the verification table
- aot_compile_test.dart releases the temp directory with addTearDown instead of try/finally
- The AOT fixture keeps the create function private, after the methods, and documents the constructor
- Drop the repeated void pointer note from the WindowsDnsSdFfiApi class doc; the binding comments keep it
- Add an example of the Windows backend
- example/aud_midi_windows_example.dart lists the ports, opens the inputs and plays a note on a virtual port
- pana: 160 of 160 points; the example was the missing part
- Point to the example in README.md and README.de.md
- Add a README code example and an SDK-only AOT check
- README.md and README.de.md get a Code Examples section with a runnable snippet and a link to the example
- The example builds its notes with MidiNoteOn2, MidiNoteOff2 and UmpEncoder instead of hand-coded UMP words
- The example opens the inputs side by side, splits main into _openInputs and _playNote and stops the backend in finally
- aot_compile_test.dart runs dart compile aot-snapshot: the same gen_snapshot check without codesign or other tools
- The AOT test skips with a reason when the Dart SDK has no gen_snapshot
- The README verification tables name dart compile aot-snapshot

## 0.1.1 - 2026-10-12

### Added

- Add the constraints of ticket 26

## 0.1.0 - 2026-10-07

### Added

- Add boilerplate
- Add package dependencies

### Changed

- Upgrade dependencies
- Rename the PM repo to aud_midi_pm and move the plan there
- Use git dependencies and set publish_to none
- Implement the Windows MIDI backend
- Reference the aud_midi packages on pub.dev and the audmidi organization
- Plan BLE peripheral support

## 0.0.0 - 2026-10-06

- Initial boilerplate
