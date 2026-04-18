/// Minimal example for simple_telephony_native.
///
/// Demonstrates the plugin's public API surface:
///   * `initializeForeground` + event-stream subscription for live call
///     state updates,
///   * the default-dialer role dance — observed + requested via
///     `simple_permissions_native` (role state is not this plugin's
///     concern),
///   * `getDeviceInfo`, `listSimCards`, `listCallLog` for read-only
///     telephony data.
///
/// Run on a real Android device; SIM and call-log queries return empty
/// on an emulator without a provisioned SIM.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_permissions_native/simple_permissions_native.dart';
import 'package:simple_telephony_native/simple_telephony_native.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimplePermissionsNative.initialize();
  await TelephonyBootstrap.initialize();
  runApp(const _App());
}

/// Centralized plugin initialization — called once from `main()` and
/// again from the foreground event-stream hydration on app resume.
class TelephonyBootstrap {
  static bool _foregroundInitialized = false;

  static Future<void> initialize() async {
    if (_foregroundInitialized) return;
    await SimpleTelephonyNative.initializeForeground(
      onCallEvent: (event) async {
        // The event stream below is the primary consumer; this callback
        // is required by the API but can be a no-op if you render call
        // state purely from `SimpleTelephonyNative.instance.events`.
      },
    );
    _foregroundInitialized = true;
  }
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'simple_telephony_native example',
      theme: ThemeData(useMaterial3: true),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  DeviceInfo? _deviceInfo;
  List<SimCard> _simCards = const [];
  List<CallLogEntry> _callLog = const [];
  PhoneCallEvent? _latestEvent;
  bool _isDefaultDialer = false;
  StreamSubscription<PhoneCallEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _eventSub = SimpleTelephonyNative.instance.events.listen((event) {
      setState(() => _latestEvent = event);
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    SimpleTelephonyNative.disposeForegroundListener();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final dialerGrant = await SimplePermissionsNative.instance
        .check(const DefaultDialerApp());
    final isDefault = dialerGrant == PermissionGrant.granted;
    DeviceInfo? device;
    var sims = const <SimCard>[];
    var callLog = const <CallLogEntry>[];
    try {
      device = await SimpleTelephonyNative.instance.getDeviceInfo();
    } catch (_) {/* swallow on permission-denied */}
    try {
      sims = await SimpleTelephonyNative.instance.listSimCards();
    } catch (_) {/* swallow */}
    try {
      callLog = await SimpleTelephonyNative.instance.listCallLog();
    } catch (_) {/* swallow */}

    if (!mounted) return;
    setState(() {
      _isDefaultDialer = isDefault;
      _deviceInfo = device;
      _simCards = sims;
      _callLog = callLog;
    });
  }

  Future<void> _requestDialerRole() async {
    await SimplePermissionsNative.instance.request(const DefaultDialerApp());
    await _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('simple_telephony_native')),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Default dialer', [
              Text(_isDefaultDialer ? 'YES' : 'NO'),
              const SizedBox(height: 8),
              if (!_isDefaultDialer)
                FilledButton(
                  onPressed: _requestDialerRole,
                  child: const Text('Request default dialer role'),
                ),
            ]),
            _section('Latest call event', [
              Text(_latestEvent == null
                  ? '(waiting for a call)'
                  : 'callId=${_latestEvent!.callId}\n'
                      'state=${_latestEvent!.state}\n'
                      'isIncoming=${_latestEvent!.isIncoming}\n'
                      'number=${_latestEvent!.phoneNumber ?? "—"}'),
            ]),
            _section('Device info', [
              Text(_deviceInfo == null
                  ? '(unavailable)'
                  : 'manufacturer: ${_deviceInfo!.manufacturer}\n'
                      'model: ${_deviceInfo!.model}\n'
                      'androidVersion: ${_deviceInfo!.androidVersion}'),
            ]),
            _section('SIM cards (${_simCards.length})', [
              for (final sim in _simCards)
                Text('slot ${sim.slotIndex}: ${sim.carrierName ?? "?"} '
                    '(${sim.countryIso ?? "?"})'),
            ]),
            _section('Call log (latest ${_callLog.take(5).length} of '
                '${_callLog.length})', [
              for (final entry in _callLog.take(5))
                Text('${entry.type.name}: ${entry.number} '
                    '@ ${entry.date} (${entry.duration.inSeconds}s)'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
