// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// coverage:ignore-file
// Reason: calls dnsapi.dll, which exists on Windows only; covered by the
// @TestOn('windows') tests in test/windows.

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'windows_dns_sd_api.dart';

// #############################################################################
/// The [WindowsDnsSdApi] of dnsapi.dll, bound through `package:win32`.
///
/// Every registration owns its native request, instance and strings until
/// [release]. The completion callback is a `NativeCallable.listener`, so it
/// runs later in this isolate; the instance Windows hands to it stays valid
/// until `DnsServiceFreeInstance`.
///
/// The native signatures of the callback and of `DnsServiceFreeInstance`
/// take the instance as `Pointer<Void>`, see [_RegisterComplete].
final class WindowsDnsSdFfiApi implements WindowsDnsSdApi {
  /// Creates the binding; nothing native happens before [listen].
  WindowsDnsSdFfiApi();

  // ...........................................................................
  @override
  void listen(
    void Function(int id, int status, String? instanceName) onCompleted,
  ) {
    _onCompleted = onCompleted;
    _callable ??= NativeCallable<_RegisterComplete>.listener(_complete);
  }

  @override
  void close() {
    _callable?.close();
    _callable = null;
    _onCompleted = null;
  }

  // ...........................................................................
  @override
  int register({
    required int id,
    required String instanceName,
    required String hostName,
    required int port,
    required Map<String, String> txt,
  }) {
    // An empty TXT record needs one empty entry: Windows then sends one
    // empty string, as RFC 6763 6.1 demands.
    final count = txt.isEmpty ? 1 : txt.length;
    final keys = calloc<Pointer<Utf16>>(count);
    final values = calloc<Pointer<Utf16>>(count);
    var index = 0;
    for (final MapEntry(:key, :value) in txt.entries) {
      keys[index] = key.toNativeUtf16();
      values[index] = value.toNativeUtf16();
      index++;
    }
    final instance = calloc<DNS_SERVICE_INSTANCE>();
    instance.ref
      ..pszInstanceName = PWSTR(instanceName.toNativeUtf16())
      ..pszHostName = PWSTR(hostName.toNativeUtf16())
      ..wPort = port
      ..dwPropertyCount = count
      ..keys = keys
      ..values = values;
    final memory = _Memory(instance: instance, count: count)
      ..register = _request(id, instance);
    _memory[id] = memory;
    return DnsServiceRegister(memory.register, null).value;
  }

  @override
  int deregister(int id) {
    final memory = _memory[id]!;
    memory.deregistering = true;
    final instance = memory.registered == nullptr
        ? memory.instance
        : memory.registered;
    memory.deregister = _request(id, instance);
    return DnsServiceDeRegister(memory.deregister, null).value;
  }

  @override
  void release(int id) {
    final memory = _memory.remove(id);
    if (memory == null) return;
    final instance = memory.instance.ref;
    for (var i = 0; i < memory.count; i++) {
      if (instance.keys[i] != nullptr) calloc.free(instance.keys[i]);
      if (instance.values[i] != nullptr) calloc.free(instance.values[i]);
    }
    calloc
      ..free(instance.keys)
      ..free(instance.values)
      ..free(instance.pszInstanceName)
      ..free(instance.pszHostName)
      ..free(memory.instance);
    if (memory.registered != nullptr) _freeInstance(memory.registered);
    if (memory.register != nullptr) calloc.free(memory.register);
    if (memory.deregister != nullptr) calloc.free(memory.deregister);
  }

  // ...........................................................................
  // DNS_QUERY_REQUEST_VERSION1 of windns.h.
  static const int _requestVersion1 = 1;

  // DnsServiceFreeInstance with the instance as a void pointer, see
  // [_RegisterComplete].
  static final void Function(Pointer<Void>) _freeInstanceNative =
      DynamicLibrary.open('dnsapi.dll').lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('DnsServiceFreeInstance');

  static void _freeInstance(Pointer<DNS_SERVICE_INSTANCE> instance) =>
      _freeInstanceNative(instance.cast());

  Pointer<DNS_SERVICE_REGISTER_REQUEST> _request(
    int id,
    Pointer<DNS_SERVICE_INSTANCE> instance,
  ) {
    final request = calloc<DNS_SERVICE_REGISTER_REQUEST>();
    request.ref
      ..Version = _requestVersion1
      ..InterfaceIndex = 0
      ..pServiceInstance = instance
      // The same native signature as PDNS_SERVICE_REGISTER_COMPLETE.
      ..pRegisterCompletionCallback = _callable!.nativeFunction.cast()
      ..pQueryContext = Pointer.fromAddress(id)
      ..unicastEnabled = false;
    return request;
  }

  void _complete(int status, Pointer<Void> context, Pointer<Void> raw) {
    final Pointer<DNS_SERVICE_INSTANCE> instance = raw.cast();
    final id = context.address;
    final name = instance == nullptr
        ? null
        : instance.ref.pszInstanceName.toDartString();
    final memory = _memory[id];
    if (memory == null || memory.deregistering) {
      if (instance != nullptr &&
          (memory == null || instance != memory.registered)) {
        _freeInstance(instance);
      }
    } else {
      if (memory.registered != nullptr) _freeInstance(memory.registered);
      memory.registered = instance;
    }
    _onCompleted?.call(id, status, name);
  }

  NativeCallable<_RegisterComplete>? _callable;
  void Function(int id, int status, String? instanceName)? _onCompleted;
  final Map<int, _Memory> _memory = {};
}

// #############################################################################
/// The native memory of one registration.
final class _Memory {
  _Memory({required this.instance, required this.count});

  final Pointer<DNS_SERVICE_INSTANCE> instance;
  final int count;
  Pointer<DNS_SERVICE_REGISTER_REQUEST> register = nullptr;
  Pointer<DNS_SERVICE_REGISTER_REQUEST> deregister = nullptr;
  Pointer<DNS_SERVICE_INSTANCE> registered = nullptr;
  bool deregistering = false;
}

// #############################################################################
/// The completion callback of `DnsServiceRegister` and
/// `DnsServiceDeRegister`: win32's `PDNS_SERVICE_REGISTER_COMPLETE` with the
/// context and the instance as void pointers.
///
/// Apps of the aud_midi family build release snapshots for Android, iOS,
/// macOS and Linux that contain this binding. When the advertiser is only
/// torn off there, never called, the AOT compiler of Dart 3.13 drops the
/// struct class `DNS_SERVICE_INSTANCE` but keeps a native signature that
/// names it, and the snapshot fails with "Class with illegal cid". Native
/// signatures without the struct avoid that; the struct is read through
/// `cast()` in Dart code only. test/aot/aot_compile_test.dart guards it.
typedef _RegisterComplete =
    Void Function(Uint32 status, Pointer<Void> context, Pointer<Void> instance);
