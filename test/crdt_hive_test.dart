import 'package:crdt_hive/crdt_hive.dart';
import 'package:crdt_hive/hive_adapters.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

import 'crdt_test.dart';

final nodeId = 'test_node_id';

void main() {
  Hive.init('.');
  Hive.registerAdapter(HlcAdapter(42, nodeId));
  Hive.registerAdapter(RecordAdapter<int>(43));

  crdtTests(nodeId,
      asyncSetup: () =>
          CrdtHive.open<String, int>('test', nodeId, path: 'test_store'),
      asyncTearDown: (crdt) => crdt.deleteStore());

  group('Basic tests', () {
    CrdtHive<String, int> crdt;

    setUp(() async {
      crdt = await CrdtHive.open('test', nodeId, path: 'test_store');
    });

    test('Write value', () {
      crdt.put('x', 1);
      expect(crdt.get('x'), 1);
    });

    test('Update value', () {
      crdt.put('x', 1);
      crdt.put('x', 2);
      expect(crdt.get('x'), 2);
    });

    test('Delete value', () {
      crdt.put('x', 1);
      crdt.delete('x');
      expect(crdt.isDeleted('x'), isTrue);
    });

    tearDown(() async {
      // await crdt.deleteStore();
    });
  });

  group('Serialization', () {
    test('Reload box', () async {
      var crdt = await CrdtHive.open('test', nodeId, path: 'test_store');
      crdt.put('x', 1);
      await crdt.close();

      crdt = await CrdtHive.open('test', nodeId, path: 'test_store');
      expect(crdt.get('x'), 1);
      await crdt.deleteStore();
    });
  });

  group('Changeset', () {
    CrdtHive<String, int> crdt;

    setUp(() async {
      crdt = await CrdtHive.open('test', nodeId, path: 'test_store');
    });

    test('From', () {
      crdt.put('a', 1);
      crdt.put('b', 2);
      final hlc = crdt.canonicalTime;
      crdt.put('c', 3);
      final map = crdt.recordMap(modifiedSince: hlc);
      expect(map.length, 2);
      expect(map['a'], isNull);
      expect(map['b'].value, 2);
      expect(map['c'].value, 3);
    });

    test('All', () {
      crdt.put('a', 1);
      crdt.put('b', 2);
      crdt.put('c', 3);
      final values = crdt.recordMap();
      expect(values.values.map((e) => e.value), [1, 2, 3]);
    });

    test('json', () {
      crdt.put('a', 1);
      crdt.put('b', 2);
      final hlc = crdt.canonicalTime;
      crdt.put('c', 3);
      final json = crdt.toJson(modifiedSince: hlc);
      expect(json, startsWith('{"b":{"hlc":'));
      expect(json, endsWith(',"value":3}}'));
    });

    tearDown(() async {
      await crdt.deleteStore();
    });
  });

  group('DateTime key', () {
    CrdtHive<DateTime, int> crdt;

    setUp(() async {
      crdt = await CrdtHive.open('test', nodeId, path: 'test_store');
    });

    test('Datetime key', () {
      crdt.put(DateTime(1974, 04, 25, 00, 20), 42);
      expect(crdt.get(DateTime(1974, 04, 25, 00, 20)), 42);
    });

    test('Read datetime from store', () async {
      crdt.put(DateTime(1974, 04, 25, 00, 20), 42);
      crdt = await CrdtHive.open('test', nodeId, path: 'test_store');
      expect(crdt.get(DateTime(1974, 04, 25, 00, 20)), 42);
    });

    tearDown(() async {
      await crdt.deleteStore();
    });
  });

  group('Watches', () {
    CrdtHive<String, int> crdt;

    setUp(() async {
      crdt = await CrdtHive.open('test', nodeId, path: 'test_store');
    });

    test('Watch all changes', () async {
      final streamTest = expectLater(
          crdt.watch(),
          emitsInAnyOrder([
            (MapEntry<String, int> event) =>
                event.key == 'x' && event.value == 1,
            (MapEntry<String, int> event) =>
                event.key == 'y' && event.value == 2,
          ]));
      crdt.put('x', 1);
      crdt.put('y', 2);
      await streamTest;
    });

    test('Watch key', () async {
      final streamTest = expectLater(
          crdt.watch(key: 'y'),
          emits(
            (event) => event.key == 'y' && event.value == 2,
          ));
      crdt.put('x', 1);
      crdt.put('y', 2);
      await streamTest;
    });

    tearDown(() async {
      await crdt.deleteStore();
    });
  });
}