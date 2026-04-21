# Handoff: `simple-query` `calls` domain gaps

**Owner:** work on `simple-query`, then update `simple-telephony` to match.
**Discovered:** 2026-04-20, while auditing `simple-telephony` for the `v0.5.1` release candidate.
**Severity:** high — `simple_telephony_android.listCallLog()` is returning structurally-degraded records today.

---

## The bug in `simple-telephony`

`simple_telephony_android/lib/simple_telephony_android.dart` calls
`sq.SimpleQuery.instance.query(QueryRequest(domain: QueryDomain.calls, ...))`
and then reads the returned records by **raw Android CallLog column names**:

```dart
// simple_telephony_android.dart  _callLogEntryFromRaw (lines ~119–137)
id: asInt(raw['_id'] ?? raw['id']) ?? 0,
number: raw['number'] as String?,
name: raw['name'] as String?,
type: _valueToCallType(asInt(raw['type']) ?? 0),                // ← miss
date: DateTime.fromMillisecondsSinceEpoch(asInt(raw['date']) ?? 0), // ← miss
duration: Duration(seconds: asInt(raw['duration']) ?? 0),       // ← miss
isNew: asBool(raw['new']),                                      // ← miss
isRead: asBool(raw['is_read']),                                 // ← miss
geocodedLocation: raw['geocoded_location'] as String?,          // ← miss
subscriptionId: asInt(raw['subscription_id']),                  // ← miss
```

But `simple_query_android` normalizes rows to canonical keys before returning
them — see `simple_query_android/lib/src/simple_query_android_api.dart:744–755`:

```dart
case iface.QueryDomain.calls:
  return <String, Object?>{
    'id': _firstString(row, const <String>['_id', 'id']) ?? '',
    'number': _firstString(row, const <String>['number']),
    'callType': _firstString(row, const <String>['type', 'callType']) ?? 'unknown',
    'durationSec': _firstInt(row, const <String>['duration', 'durationSec']),
    'timestamp': _firstString(row, const <String>['date', 'timestamp']) ?? '',
    'name': _firstString(row, const <String>['name', 'cached_name']),
  };
```

**Canonical `calls` record keys today:** `id`, `number`, `callType`,
`durationSec`, `timestamp`, `name`.

**Fields simple-telephony wants that are not in the canonical schema:**
`isNew`, `isRead`, `geocodedLocation`, `subscriptionId`.

Result: every `CallLogEntry.type` is `CallType.unknown`, every `.date` is epoch
0, every `.duration` is zero, and the four extra fields are always defaults.

---

## The deeper API issue in `simple-query`

`simple_query_android` has an **asymmetric contract** between filter/sort
fields and returned record keys:

- **Output records** use canonical keys (`callType`, `timestamp`, `durationSec`).
- **Filter / sort field names** are passed through verbatim as SQL column names
  (`simple_query_android_api.dart:578–614`, `625–637`). So callers currently
  must supply raw Android column names (`type`, `date`, `duration`) in
  `QueryFilterCondition.field` and `QuerySort.field`.

That asymmetry means consumers have to know two schemas — the canonical one
for reads, the Android one for writes/filters. It's also a leak of the Android
provider schema into any cross-platform caller, defeating the point of the
federated interface.

---

## What to change in `simple-query`

### 1. Extend the `calls` canonical schema

`simple_query_platform_interface/lib/src/contracts.dart` — add to
`optionalKeys[QueryDomain.calls]`:

- `isNew` (bool)
- `isRead` (bool)
- `geocodedLocation` (String)
- `subscriptionId` (int)

These are Android-specific today but conceptually universal (iOS CallKit has
analogues for the first two, Windows doesn't expose call logs at all).

Update `simple_query_android`'s `_normalizeRecord(QueryDomain.calls, …)` to
populate the four new keys from Android column names: `new`, `is_read`,
`geocoded_location`, `subscription_id`.

On platforms that don't expose the concept (iOS, macOS, Linux, Windows, Web),
leave the keys absent. That's what `optionalKeys` means.

### 2. Map filter/sort fields from canonical → native

In `simple_query_android._selectionFromFilters` and `_sortOrderFrom` (lines
568–637), before using `filter.field`/`sort.field` as a SQL column name,
translate from canonical to the Android provider column. For `QueryDomain.calls`:

| Canonical         | Android column       |
|-------------------|----------------------|
| `id`              | `_id`                |
| `number`          | `number`             |
| `callType`        | `type`               |
| `durationSec`     | `duration`           |
| `timestamp`       | `date`               |
| `name`            | `name` or `cached_name` |
| `isNew`           | `new`                |
| `isRead`          | `is_read`            |
| `geocodedLocation`| `geocoded_location`  |
| `subscriptionId`  | `subscription_id`    |

Keep `QueryDomain.platformSpecific` as an escape hatch where fields pass
through unchanged.

Add tests covering: filter by canonical field, sort by canonical field,
unsupported canonical field → clear error message (not a raw SQLite error).

### 3. Bump `simple_query_*` versions, add CHANGELOG entries

Bump minor (not patch) because the optional-key additions are an API contract
expansion, and because callers who were relying on the raw-column-name filter
behaviour will need to migrate.

---

## What to change in `simple-telephony` afterwards

Once `simple-query` ships the above, update
`simple_telephony_android/lib/simple_telephony_android.dart`:

### 1. `_callLogEntryFromRaw` — read canonical keys

```dart
CallLogEntry _callLogEntryFromRaw(Map<String, Object?> raw) {
  int? asInt(Object? v) =>
      v is int ? v : (v is String ? int.tryParse(v) : null);
  bool asBool(Object? v) => v == 1 || v == true || v == '1' || v == 'true';

  return CallLogEntry(
    id: asInt(raw['id']) ?? 0,
    number: raw['number'] as String?,
    name: raw['name'] as String?,
    type: _callTypeFromCanonical(raw['callType'] as String?),
    date: DateTime.fromMillisecondsSinceEpoch(asInt(raw['timestamp']) ?? 0),
    duration: Duration(seconds: asInt(raw['durationSec']) ?? 0),
    isNew: asBool(raw['isNew']),
    isRead: asBool(raw['isRead']),
    geocodedLocation: raw['geocodedLocation'] as String?,
    subscriptionId: asInt(raw['subscriptionId']),
    sourceMap: raw,
  );
}
```

Note `callType` comes back as a **string** from `simple_query_android` today
(it's `_firstString`, not `_firstInt`). Either:

- keep the string form and translate `"1" → CallType.incoming`, etc., or
- ask simple-query to return it as an int (preferred — the Android column is
  an integer; stringifying it is lossy and the other callType consumers will
  want ints too). If changed, coordinate with other `simple-query` consumers.

### 2. `_buildCallLogFilters` — use canonical names

Swap every `QueryFilterCondition(field: 'type', ...)` etc. for canonical keys
(`callType`, `timestamp`, `durationSec`, `isNew`, `subscriptionId`).

### 3. `_buildCallLogSort` — same

```dart
final column = switch (sort.field) {
  CallLogSortField.date => 'timestamp',
  CallLogSortField.duration => 'durationSec',
};
```

### 4. Tests

Add a unit test in `simple_telephony_android/test/` that feeds a stubbed
`SimpleQuery` response with canonical keys and asserts `CallLogEntry` round-trip.
This is the regression test that would have caught the original bug.

---

## Cross-repo coordination

The changes to `simple-query` are source-incompatible for any caller that was
using raw Android column names in filters. Grep the `simplezen` org (or all
sibling checkouts on disk) for `QueryFilterCondition(` with `QueryDomain.calls`
before merging the simple-query PR:

```bash
rg -l "QueryDomain\.calls" --type dart
```

Known consumer today: `simple-telephony`. Treat this as the pilot case.

---

## Why I found this now

This surfaced during the `simple-telephony` v0.5.1 audit when I traced
`listCallLog` against the simple-query contract. The rest of that audit (race
fixes, channel decoding hardening, PII logs) is already landing on
`simple-telephony`'s `release/v0.5.1-rc.1` branch; the `listCallLog` fix is
deliberately held back until `simple-query` ships.
