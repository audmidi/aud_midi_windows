# Changelog

## Unreleased

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
