import 'call_log_entry.dart';
import 'sort_direction.dart';

/// Criteria for narrowing a call-log listing query.
///
/// All fields are optional; omitted fields contribute no filter. Fields are
/// combined with AND.
class CallLogFilter {
  const CallLogFilter({
    this.types,
    this.dateFrom,
    this.dateTo,
    this.numberContains,
    this.subscriptionId,
    this.isNew,
  });

  /// Match any of these call types (`type IN (...)`).
  final List<CallType>? types;

  /// Match only entries with `date >= dateFrom`.
  final DateTime? dateFrom;

  /// Match only entries with `date <= dateTo`.
  final DateTime? dateTo;

  /// Substring match against the `number` column.
  final String? numberContains;

  /// Match only entries on a specific SIM subscription.
  final int? subscriptionId;

  /// Match only new (unsurfaced) entries when `true`; seen entries when
  /// `false`; any otherwise.
  final bool? isNew;

  CallLogFilter copyWith({
    List<CallType>? types,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? numberContains,
    int? subscriptionId,
    bool? isNew,
  }) =>
      CallLogFilter(
        types: types ?? this.types,
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        numberContains: numberContains ?? this.numberContains,
        subscriptionId: subscriptionId ?? this.subscriptionId,
        isNew: isNew ?? this.isNew,
      );

  @override
  String toString() => 'CallLogFilter(types: $types, dateFrom: $dateFrom, '
      'dateTo: $dateTo, numberContains: $numberContains, '
      'subscriptionId: $subscriptionId, isNew: $isNew)';
}

/// Sort column for call-log listings.
enum CallLogSortField { date, duration }

/// Ordering rule for a call-log listing.
class CallLogSort {
  const CallLogSort({
    this.field = CallLogSortField.date,
    this.direction = SortDirection.descending,
  });

  final CallLogSortField field;
  final SortDirection direction;

  /// Most-recent-first ordering by `date` — the standard call-history default.
  static const CallLogSort mostRecent = CallLogSort(
    field: CallLogSortField.date,
    direction: SortDirection.descending,
  );

  @override
  String toString() => 'CallLogSort(field: $field, direction: $direction)';
}
