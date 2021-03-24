@TestOn('vm')
library io_client_test;

import 'package:rpc_exceptions/rpc_exceptions.dart';
import 'package:test/test.dart';

import 'classb.dart';
import 'jsonrpc_io_client.dart';

class MyClass {
  MyClass();
}

bool persistentConnection = false;

void main() {
  var proxy = ServerProxy('http://127.0.0.1:8394/sum');
  proxy.persistentConnection = persistentConnection;
  group('JSON-RPC', () {
    test('positional arguments', () {
      proxy.call('subtract', [23, 42]).then((result) {
        expect(result, equals(-19));
      });
    });
    test('positional arguments 2', () {
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
      proxy.call('echo', ['Îñţérñåţîöñåļîžåţîờñ']).then((result) {
        expect(result, equals('Îñţérñåţîöñåļîžåţîờñ'));
      });
    });

    test('unicode2', () {
      proxy.call('echo2', ['Îñţérñåţîöñåļîžåţîờñ']).then((result) {
        expect(result,
            equals('Îñţérñåţîöñåļîžåţîờñ Τη γλώσσα μου έδωσαν ελληνική'));
      });
    });

    // test('not JSON-serializable', () async {
    //   var result = await proxy.call('subtract', [3, 0 / 0]);
    //   expect(result, equals(3));
    // });

    test('not JSON-serializable', () {
      expect(proxy.call('subtract', [3, 0 / 0]), throwsUnsupportedError);
    });

    test('class instance not JSON-serializable', () {
      expect(proxy.call('subtract', [3, MyClass()]), throwsUnsupportedError);
    });

    test('serializable class - see classb.dart', () {
      proxy.call('s1', [ClassB('hello', 'goodbye')]).then((result) {
        expect(result, equals('hello'));
      });
    });

    test('custom error', () async {
      // this works. separately.
      // proxy.call('baloo', 'sam').then((result) {
      //   expect(result, equals('Balooing sam, as requested.'));
      // });
      var result2 = await proxy.call('baloo', ['frotz']);
      try {
        proxy.checkError(result2);
      } on RpcException catch (e) {
        expect(e.code, equals(34));
      }
    });

    test('unplanned error', () async {
      dynamic result = await proxy.call('raiseMe', '[Hello]');
      try {
        proxy.checkError(result);
      } on RpcException catch (e) {
        expect(e.code, equals(-32000));
      }
      // FYI
      //expect ('$result', equals('RemoteException -32000: [Hello]'));
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

//    test('notification had effect', () {
//      proxy.call('fetchGlobal').then((result) {
//        expect(result, equals([1, 2, 3, 4, 5]));
//      });
//    });

    test('basic batch', () {
      var proxy2 = BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy2.persistentConnection = persistentConnection;
      proxy2.call('subtract', [23, 42]).then((result) {
        expect(result, equals(-19));
      });
      proxy2.call('subtract', [42, 23]).then((result) {
        expect(result, equals(19));
      });
      proxy2.call('get_data').then((result) {
        expect(result, equals(['hello', 5]));
      });
      proxy2.notify('update', ['happy Tuesday']);

      proxy2
          .call('nsubtract', {'minuend': 23, 'subtrahend': 42}).then((result) {
        expect(result, equals(-19));
      });
      proxy2.send();
    });

    test('batch with error on a notification', () {
      var proxy3 = BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy3.persistentConnection = persistentConnection;
      proxy3.call('summation', [
        [1, 2, 3, 4, 5]
      ]).then((result) {
        expect(result, equals(15));
      });
      proxy3.call('subtract', [42, 23]).then((result) {
        expect(result, equals(19));
      });
      proxy3.call('get_data').then((result) {
        expect(result, equals(['hello', 5]));
      });
      proxy3.notify('update', [
        [1, 2, 3, 4, 5]
      ]);
      proxy3.notify('oopsie');
      proxy3
          .call('nsubtract', {'minuend': 23, 'subtrahend': 42}).then((result) {
        expect(result, equals(-19));
      });
      proxy3.send();
    });

    test('variable url', () {
      var proxy4 = ServerProxy('http://127.0.0.1:8394/friend/Bob');
      proxy4.persistentConnection = persistentConnection;
      proxy4.call('hello').then((result) {
        expect(result, equals('Hello from Bob!'));
      });
      var proxy5 = ServerProxy('http://127.0.0.1:8394/friend/Mika');
      proxy5.persistentConnection = persistentConnection;
      proxy5.call('hello').then((result) {
        expect(result, equals('Hello from Mika!'));
      });
    });
  });
}
