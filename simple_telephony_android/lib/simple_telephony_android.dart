import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:simple_query/simple_query.dart' as sq;
import 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart';

/// Android implementation of [SimpleTelephonyPlatform].
///
/// Registered via `dartPluginClass: SimpleTelephonyAndroid` in pubspec.yaml.
/// The generated plugin registrant calls [registerWith] at startup; this
/// binds [SimpleTelephonyPlatform.instance] to this subclass so the native
/// facade reaches Android-specific behaviour (call log via `simple_query`,
/// device / SIM info via a dedicated MethodChannel).
class SimpleTelephonyAndroid extends MethodChannelSimpleTelephony {
  SimpleTelephonyAndroid();

  /// Method channel for device / SIM introspection calls that don't fit the
  /// content-provider query shape. Handled in Kotlin by `DeviceInfoHandler`.
  @visibleForTesting
  static const MethodChannel deviceInfoChannel = MethodChannel(
    'io.simplezen.simple_telephony/device_info',
  );

  /// Registers this class as the platform implementation.
  static void registerWith() {
    SimpleTelephonyPlatform.instance = SimpleTelephonyAndroid();
  }

  // ---- Call log (implemented via simple_query) ----------------------------

  @override
  Future<List<CallLogEntry>> listCallLog({
    CallLogFilter? filter,
    CallLogSort? sort,
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await sq.SimpleQuery.instance.query(
        sq.QueryRequest(
          domain: sq.QueryDomain.calls,
          filters: _buildCallLogFilters(filter),
          sort: _buildCallLogSort(sort ?? CallLogSort.mostRecent),
          page: (limit != null || offset != null)
              ? sq.QueryPage(limit: limit, offset: offset)
              : null,
        ),
      );
      return response.records
          .map((row) => _callLogEntryFromRaw(Map<String, Object?>.from(row)))
          .toList(growable: false);
    } catch (e, s) {
      debugPrint('simple_telephony: Failed to list call log ($filter): $e');
      debugPrint(s.toString());
      return const [];
    }
  }

  List<sq.QueryFilterCondition> _buildCallLogFilters(CallLogFilter? filter) {
    if (filter == null) return const [];
    final conditions = <sq.QueryFilterCondition>[];

    final types = filter.types;
    if (types != null && types.isNotEmpty) {
      conditions.add(sq.QueryFilterCondition(
        field: 'type',
        operator: sq.QueryFilterOperator.inList,
        value: types.map(_callTypeToValue).map((v) => v.toString()).toList(),
      ));
    }
    if (filter.dateFrom != null) {
      conditions.add(sq.QueryFilterCondition(
        field: 'date',
        operator: sq.QueryFilterOperator.greaterThanOrEqual,
        value: filter.dateFrom!.millisecondsSinceEpoch.toString(),
      ));
    }
    if (filter.dateTo != null) {
      conditions.add(sq.QueryFilterCondition(
        field: 'date',
        operator: sq.QueryFilterOperator.lessThanOrEqual,
        value: filter.dateTo!.millisecondsSinceEpoch.toString(),
      ));
    }
    if (filter.numberContains != null && filter.numberContains!.isNotEmpty) {
      conditions.add(sq.QueryFilterCondition(
        field: 'number',
        operator: sq.QueryFilterOperator.contains,
        value: filter.numberContains,
      ));
    }
    if (filter.subscriptionId != null) {
      conditions.add(sq.QueryFilterCondition(
        field: 'subscription_id',
        operator: sq.QueryFilterOperator.equals,
        value: filter.subscriptionId.toString(),
      ));
    }
    if (filter.isNew != null) {
      conditions.add(sq.QueryFilterCondition(
        field: 'new',
        operator: sq.QueryFilterOperator.equals,
        value: filter.isNew! ? '1' : '0',
      ));
    }
    return conditions;
  }

  List<sq.QuerySort> _buildCallLogSort(CallLogSort sort) {
    final column = switch (sort.field) {
      CallLogSortField.date => 'date',
      CallLogSortField.duration => 'duration',
    };
    final dir = sort.direction == SortDirection.ascending
        ? sq.QuerySortDirection.ascending
        : sq.QuerySortDirection.descending;
    return [sq.QuerySort(field: column, direction: dir)];
  }

  CallLogEntry _callLogEntryFromRaw(Map<String, Object?> raw) {
    int? asInt(Object? v) =>
        v is int ? v : (v is String ? int.tryParse(v) : null);
    bool asBool(Object? v) =>
        v == 1 || v == true || v == '1' || v == 'true';

    return CallLogEntry(
      id: asInt(raw['_id'] ?? raw['id']) ?? 0,
      number: raw['number'] as String?,
      name: raw['name'] as String?,
      type: _valueToCallType(asInt(raw['type']) ?? 0),
      date: DateTime.fromMillisecondsSinceEpoch(asInt(raw['date']) ?? 0),
      duration: Duration(seconds: asInt(raw['duration']) ?? 0),
      isNew: asBool(raw['new']),
      isRead: asBool(raw['is_read']),
      geocodedLocation: raw['geocoded_location'] as String?,
      subscriptionId: asInt(raw['subscription_id']),
      sourceMap: raw,
    );
  }

  /// Android `CallLog.Calls.TYPE` integer → [CallType].
  /// Constants: INCOMING=1, OUTGOING=2, MISSED=3, VOICEMAIL=4,
  /// REJECTED=5, BLOCKED=6, ANSWERED_EXTERNALLY=7.
  CallType _valueToCallType(int v) {
    switch (v) {
      case 1:
        return CallType.incoming;
      case 2:
        return CallType.outgoing;
      case 3:
        return CallType.missed;
      case 4:
        return CallType.voicemail;
      case 5:
        return CallType.rejected;
      case 6:
        return CallType.blocked;
      default:
        return CallType.unknown;
    }
  }

  int _callTypeToValue(CallType t) {
    switch (t) {
      case CallType.incoming:
        return 1;
      case CallType.outgoing:
        return 2;
      case CallType.missed:
        return 3;
      case CallType.voicemail:
        return 4;
      case CallType.rejected:
        return 5;
      case CallType.blocked:
        return 6;
      case CallType.unknown:
        return 0;
    }
  }

  // ---- Device info / SIM cards (native MethodChannel) ---------------------

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    final raw = await deviceInfoChannel
        .invokeMapMethod<String, Object?>('getDeviceInfo');
    if (raw == null) {
      throw StateError('simple_telephony: getDeviceInfo returned null');
    }
    return DeviceInfo(
      model: (raw['model'] as String?) ?? '',
      manufacturer: (raw['manufacturer'] as String?) ?? '',
      androidVersion: (raw['androidVersion'] as String?) ?? '',
      androidSdkInt: (raw['androidSdkInt'] as int?) ?? 0,
      simSlotCount: (raw['simSlotCount'] as int?) ?? 0,
      deviceId: raw['deviceId'] as String?,
      sourceMap: raw,
    );
  }

  @override
  Future<List<SimCard>> listSimCards() async {
    final raw = await deviceInfoChannel
        .invokeListMethod<Map<Object?, Object?>>('listSimCards');
    if (raw == null) return const [];
    return raw
        .map((row) => Map<String, Object?>.from(row))
        .map(
          (m) => SimCard(
            slotIndex: (m['slotIndex'] as int?) ?? 0,
            subscriptionId: (m['subscriptionId'] as int?) ?? 0,
            isDefault: (m['isDefault'] as bool?) ?? false,
            carrierName: m['carrierName'] as String?,
            displayName: m['displayName'] as String?,
            number: m['number'] as String?,
            countryIso: m['countryIso'] as String?,
            mcc: m['mcc'] as String?,
            mnc: m['mnc'] as String?,
            sourceMap: m,
          ),
        )
        .toList(growable: false);
  }
}
