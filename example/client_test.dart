@TestOn('browser')
library client_test;

import 'package:jsonrpc2/jsonrpc2.dart';
import 'package:test/test.dart';
import 'jsonrpc_client.dart';
import 'classb.dart';

class MyClass {
  MyClass();
}

dynamic proxy;
void main() {
  proxy = ServerProxy('http://127.0.0.1:8394/sum');
  group('JSON-RPC', () {
    test('positional arguments', () {
      proxy.call('subtract', [23, 42]).then((result) {
        expect(result, equals(-19));
      });
      proxy.call('subtract', [42, 23]).then((result) {
        expect(result, equals(19));
      });
    });

    test('named arguments', () {
      proxy.call('nsubtract', {'subtrahend': 23, 'minuend': 42}).then((result) {
        expect(result, equals(19));
      });
      proxy.call('nsubtract', {'minuend': 42, 'subtrahend': 23}).then((result) {
        expect(result, equals(19));
      });
      proxy.call('nsubtract', {'minuend': 23, 'subtrahend': 42}).then((result) {
        expect(result, equals(-19));
      });
      proxy.call('nsubtract', {'subtrahend': 42}).then((result) {
        expect(result, equals(-42));
      });
      proxy.call('nsubtract').then((result) {
        expect(result, equals(0));
      });
    });

    test('notification', () {
      proxy.notify('update', [
        [1, 2, 3, 4, 5]
      ]).then((result) {
        expect(result, equals(''));
      });
    });

    test('unicode', () {
      proxy.call('echo', 'Îñţérñåţîöñåļîžåţîờñ').then((result) {
        expect(result, equals('Îñţérñåţîöñåļîžåţîờñ'));
      });
    });

    test('unicode2', () {
      proxy.call('echo2', ['Îñţérñåţîöñåļîžåţîờñ']).then((result) {
        expect(result,
            equals('Îñţérñåţîöñåļîžåţîờñ Τη γλώσσα μου έδωσαν ελληνική'));
      });
    });

    test('not JSON-serializable', () {
      expect(proxy.call('subtract', [3, 0 / 0]), throwsUnsupportedError);
    });

    test('class instance not JSON-serializable', () {
      expect(proxy.call('subtract', [3, MyClass()]), throwsUnsupportedError);
    });

    test('serializable class - see classb.dart', () async {
      var result = await proxy.call('s1', [ClassB('hello', 'goodbye')]);
      expect(result, equals('hello'));
    });

    test('custom error', () async {
      dynamic result = await proxy.call('baloo', ['sam']);
      expect(result, equals('Balooing sam, as requested.'));

      result = await proxy.call('baloo', ['frotz']);
      try {
        proxy.checkError(result);
      } on RpcException catch (e) {
        expect(e.code, equals(34));
      }
      ;
    });

    test('no such method', () {
      proxy.call('foobar').then((result) {
        expect(result.code, equals(-32601));
      });
    });

    test('private method', () {
      proxy.call('_private').then((result) {
        expect(result.code, equals(-32601));
      });
    });

    test('notification had effect', () {
      proxy.call('fetchGlobal').then((result) {
        expect(result, equals([1, 2, 3, 4, 5]));
      });
    });

    test('basic batch', () {
      proxy = BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy.call('subtract', [23, 42]).then((result) {
        expect(result, equals(-19));
      });
      proxy.call('subtract', [42, 23]).then((result) {
        expect(result, equals(19));
      });
      proxy.call('get_data').then((result) {
        expect(result, equals(['hello', 5]));
      });
      proxy.notify('update', ['happy Tuesday']);

      proxy.call('nsubtract', {'minuend': 23, 'subtrahend': 42}).then((result) {
        expect(result, equals(-19));
      });
      proxy.send();
    });

    test('batch with error on a notification', () {
      proxy = BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy.call('summation', [
        [1, 2, 3, 4, 5]
      ]).then((result) {
        expect(result, equals(15));
      });
      proxy.call('subtract', [42, 23]).then((result) {
        expect(result, equals(19));
      });
      proxy.call('get_data').then((result) {
        expect(result, equals(['hello', 5]));
      });
      proxy.notify('update', [
        [1, 2, 3, 4, 5]
      ]);
      proxy.notify('oopsie');
      proxy.call('nsubtract', {'minuend': 23, 'subtrahend': 42}).then((result) {
        expect(result, equals(-19));
      });
      proxy.send();
    });

    test('variable url', () {
      var proxy = ServerProxy('http://127.0.0.1:8394/friend/Bob');
      proxy.call('hello').then((result) {
        expect(result, equals('Hello from Bob!'));
      });
      proxy = ServerProxy('http://127.0.0.1:8394/friend/Mika');
      proxy.call('hello').then((result) {
        expect(result, equals('Hello from Mika!'));
      });
    });
  });
}
