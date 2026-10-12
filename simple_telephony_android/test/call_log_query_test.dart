import 'package:flutter_test/flutter_test.dart';
import 'package:simple_query_platform_interface/simple_query_platform_interface.dart';
import 'package:simple_query_platform_interface/testing.dart';
import 'package:simple_telephony_android/simple_telephony_android.dart';
import 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SimpleQueryPlatform previous;
  late FakeSimpleQueryPlatform query;

  setUp(() {
    previous = SimpleQueryPlatform.instance;
    query = FakeSimpleQueryPlatform(
        queryResult: const QueryResult(records: [
      {
        'id': '42',
        'number': '+15550100',
        'name': 'Caller',
        'callType': '2',
        'timestamp': '1700000000000',
        'durationSec': 75,
        'isNew': true,
        'isRead': true,
        'geocodedLocation': 'Michigan',
        'subscriptionId': 3,
      },
    ]));
    SimpleQueryPlatform.instance = query;
  });

  tearDown(() => SimpleQueryPlatform.instance = previous);

  test('default call history reads canonical records and sorts newest first',
      () async {
    final entries = await SimpleTelephonyAndroid().listCallLog();
    final request = query.queryRequests.single;
    expect(request.domain, QueryDomain.calls);
    expect(request.sort.single.field, 'timestamp');
    expect(request.sort.single.direction, QuerySortDirection.descending);
    final entry = entries.single;
    expect(entry.id, 42);
    expect(entry.number, '+15550100');
    expect(entry.name, 'Caller');
    expect(entry.type, CallType.outgoing);
    expect(entry.date.millisecondsSinceEpoch, 1700000000000);
    expect(entry.duration.inSeconds, 75);
    expect(entry.isNew, isTrue);
    expect(entry.isRead, isTrue);
    expect(entry.geocodedLocation, 'Michigan');
    expect(entry.subscriptionId, 3);
    expect(entry.sourceMap?['callType'], '2');
  });

  test('filtered paged history uses canonical fields and duration sorting',
      () async {
    await SimpleTelephonyAndroid().listCallLog(
      filter: CallLogFilter(
        types: const [CallType.incoming, CallType.missed],
        dateFrom: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        dateTo: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        numberContains: '0100',
        subscriptionId: 3,
        isNew: true,
      ),
      sort: const CallLogSort(
        field: CallLogSortField.duration,
        direction: SortDirection.ascending,
      ),
      limit: 20,
      offset: 40,
    );
    final request = query.queryRequests.single;
    expect(request.filters.map((f) => [f.field, f.operator, f.value]), [
      [
        'callType',
        QueryFilterOperator.inList,
        ['1', '3']
      ],
      ['timestamp', QueryFilterOperator.greaterThanOrEqual, '1700000000000'],
      ['timestamp', QueryFilterOperator.lessThanOrEqual, '1700000001000'],
      ['number', QueryFilterOperator.contains, '0100'],
      ['subscriptionId', QueryFilterOperator.equals, '3'],
      ['isNew', QueryFilterOperator.equals, '1'],
    ]);
    expect(request.sort.single.field, 'durationSec');
    expect(request.sort.single.direction, QuerySortDirection.ascending);
    expect(request.page?.limit, 20);
    expect(request.page?.offset, 40);
  });

  test('seen filter keeps false and absent optional record fields stay absent',
      () async {
    query.queryResultsByCall = [
      const QueryResult(records: [
        {'id': '5', 'callType': 'unknown', 'timestamp': '0', 'durationSec': 0},
      ])
    ];
    final entries = await SimpleTelephonyAndroid().listCallLog(
      filter: const CallLogFilter(isNew: false),
    );
    expect(query.queryRequests.single.filters.single.field, 'isNew');
    expect(query.queryRequests.single.filters.single.value, '0');
    expect(entries.single.type, CallType.unknown);
    expect(entries.single.isNew, isFalse);
    expect(entries.single.isRead, isFalse);
    expect(entries.single.subscriptionId, isNull);
    expect(entries.single.sourceMap?.containsKey('isNew'), isFalse);
  });

  test('query errors reach the caller instead of returning empty history',
      () async {
    const error = SimpleQueryError(
      code: SimpleQueryErrorCode.permissionDenied,
      message: 'Call log permission denied',
    );
    SimpleQueryPlatform.instance = _FailingQuery(error);
    await expectLater(
      SimpleTelephonyAndroid().listCallLog(),
      throwsA(same(error)),
    );
  });
}

class _FailingQuery extends FakeSimpleQueryPlatform {
  _FailingQuery(this.error);
  final SimpleQueryError error;

  @override
  Future<QueryResult> query(QueryRequest request) async => throw error;
}
