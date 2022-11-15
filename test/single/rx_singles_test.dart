// ignore_for_file: prefer_function_declarations_over_variables

import 'dart:async';

import 'package:dart_either/dart_either.dart';
import 'package:rxdart_ext/rxdart_ext.dart';
import 'package:test/test.dart';

import 'utils.dart';

class TestResource {
  var _isClosed = false;

  void close() {
    if (_isClosed) {
      throw StateError('Already closed');
    }
    _isClosed = true;
  }

  bool get isClosed => _isClosed;
}

void main() {
  group('RxSingles.zip2', () {
    test('success + success', () async {
      final build = () => RxSingles.zip2(
            Single.value(1),
            Single.timer(2, Duration(milliseconds: 100)),
            (int a, int b) => a + b,
          );
      await singleRule(
        build(),
        Either.right(3),
      );
      broadcastRule(build(), false);
      await cancelRule(build());
    });

    test('success + failure', () async {
      final build = () => RxSingles.zip2(
            Single.value(1),
            Single<int>.error(Exception()),
            (int a, int b) => a + b,
          );
      await singleRule(
        build(),
        exceptionLeft,
      );
      broadcastRule(build(), false);
      await cancelRule(build());
    });

    test('failure + success', () async {
      final build = () => RxSingles.zip2(
            Single<int>.error(Exception()),
            Single.timer(2, Duration(milliseconds: 100)),
            (int a, int b) => a + b,
          );
      await singleRule(build(), exceptionLeft);
      broadcastRule(build(), false);
      await cancelRule(build());
    });

    test('failure + failure', () async {
      final build = () => RxSingles.zip2(
            Single<int>.error(Exception()),
            Single<int>.error(Exception()).delay(Duration(milliseconds: 10)),
            (int a, int b) => a + b,
          );
      await singleRule(build(), exceptionLeft);
      broadcastRule(build(), false);
      await cancelRule(build());
    });
  });

  group('RxSingles.forkJoin2', () {
    test('success + success', () async {
      final build = () => RxSingles.forkJoin2(
            Single.value(1),
            Single.timer(2, Duration(milliseconds: 100)),
            (int a, int b) => a + b,
          );
      await singleRule(
        build(),
        Either.right(3),
      );
      broadcastRule(build(), false);
      await cancelRule(build());
    });

    test('success + failure', () async {
      final build = () => RxSingles.forkJoin2(
            Single.value(1),
            Single<int>.error(Exception()),
            (int a, int b) => a + b,
          );
      await singleRule(
        build(),
        exceptionLeft,
      );
      broadcastRule(build(), false);
      await cancelRule(build());
    });

    test('failure + success', () async {
      final build = () => RxSingles.forkJoin2(
            Single<int>.error(Exception()),
            Single.timer(2, Duration(milliseconds: 100)),
            (int a, int b) => a + b,
          );
      await singleRule(build(), exceptionLeft);
      broadcastRule(build(), false);
      await cancelRule(build());
    });

    test('failure + failure', () async {
      final build = () => RxSingles.forkJoin2(
            Single<int>.error(Exception()),
            Single<int>.error(Exception()).delay(Duration(milliseconds: 10)),
            (int a, int b) => a + b,
          );
      await singleRule(build(), exceptionLeft);
      broadcastRule(build(), false);
      await cancelRule(build());
    });
  });

  group('RxSingles.using', () {
    test('resourceFactory throws', () async {
      final build = () => RxSingles.using<int, TestResource>(
            () => throw Exception(),
            (r) => fail('should not be called'),
            (r) => fail('should not be called'),
          );

      await singleRule(build(), exceptionLeft);
      broadcastRule(build(), false);
      await cancelRule(build());
    });

    test('success', () async {
      TestResource? resource;

      void clear() {
        resource = null;
      }

      final build = () {
        if (resource != null) {
          throw StateError('Resource already created');
        }
        return RxSingles.using<TestResource, TestResource>(
          () => resource = TestResource(),
          (r) => Single.value(r),
          (r) => r.close(),
        );
      };

      await singleRule(build(), isA<TestResource>().right());
      expect(resource!.isClosed, true);

      clear();
      broadcastRule(build(), false);

      clear();
      await cancelRule(build());
      expect(resource == null || resource!.isClosed, true);

      clear();
      await cancelRule(build(), Duration.zero);
      expect(resource == null || resource!.isClosed, true);
    });

    test('failure', () async {
      TestResource? resource;

      void clear() {
        resource = null;
      }

      final build = () {
        if (resource != null) {
          throw StateError('Resource already created');
        }
        return RxSingles.using<TestResource, TestResource>(
          () => resource = TestResource(),
          (r) => Single.error(Exception()),
          (r) => r.close(),
        );
      };

      await singleRule(build(), exceptionLeft);
      expect(resource!.isClosed, true);

      clear();
      broadcastRule(build(), false);

      clear();
      await cancelRule(build());
      expect(resource == null || resource!.isClosed, true);

      clear();
      await cancelRule(build(), Duration.zero);
      expect(resource == null || resource!.isClosed, true);
    });

    test('disposer throws', () async {
      final build = () => RxSingles.using<TestResource, TestResource>(
            () => TestResource(),
            (r) => Single.value(r),
            (r) => throw Exception('Disposer'),
          );

      final onError = (Object error, StackTrace stack) {
        expect(error, isA<Exception>());
        expect(error.toString(), 'Exception: Disposer');
      };
      await runZonedGuarded(
        () => singleRule(build(), isA<TestResource>().right()),
        onError,
      );
      runZonedGuarded(
        () => broadcastRule(build(), false),
        onError,
      );
      await runZonedGuarded(
        () => cancelRule(build()),
        onError,
      );
    });
  });
}
