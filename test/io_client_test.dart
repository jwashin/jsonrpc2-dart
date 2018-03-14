@TestOn("vm")
library io_client_test;

import 'package:test/test.dart';
import 'package:jsonrpc2/jsonrpc_io_client.dart';
import "package:jsonrpc2/src/classb.dart";

class MyClass {
  MyClass();
}

bool persistentConnection = false;

main() {
  dynamic proxy =
      new ServerProxy('http://127.0.0.1:8394/sum', persistentConnection);
  group('JSON-RPC', () {
    test("positional arguments", () {
      proxy.call('subtract', [23, 42]).then((result) {
        expect(result, equals(-19));
      });
      proxy.call('subtract', [42, 23]).then((result) {
        expect(result, equals(19));
      });
    });

    test("named arguments", () {
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

    test("notification", () {
      proxy.notify('update', [
        [1, 2, 3, 4, 5]
      ]).then((result) {
        expect(result, equals(null));
      });
    });

    test("unicode", () {
      proxy.call('echo', ['Îñţérñåţîöñåļîžåţîờñ']).then((result) {
        expect(result, equals('Îñţérñåţîöñåļîžåţîờñ'));
      });
    });

    test("unicode2", () {
      proxy.call('echo2', ['Îñţérñåţîöñåļîžåţîờñ']).then((result) {
        expect(result,
            equals('Îñţérñåţîöñåļîžåţîờñ Τη γλώσσα μου έδωσαν ελληνική'));
      });
    });

    test("not JSON-serializable", () {
      expect(proxy.call('subtract', [3, 0 / 0]), throwsUnsupportedError);
    });

    test("class instance not JSON-serializable", () {
      expect(
          proxy.call('subtract', [3, new MyClass()]), throwsUnsupportedError);
    });

    test("serializable class - see classb.dart", () {
      proxy.call('s1', [new ClassB("hello", "goodbye")]).then((result) {
        expect(result, equals('hello'));
      });
    });

    test("custom error", () async {
      proxy.call('baloo', ['sam']).then((result) {
        expect(result, equals('Balooing sam, as requested.'));
      });
      dynamic result = await proxy.call('baloo', ['frotz']);
      try {
        proxy.checkError(result);
      } catch (e) {
        expect(e.code, equals(34));
      }
    });

    test("unplanned error", () async {
      dynamic result = await proxy.call('raiseMe', '[Hello]');
      try {
        proxy.checkError(result);
      } catch (e) {
        expect(e.code, equals(-32000));
      }
      // FYI
      //expect ('$result', equals("RemoteException -32000: [Hello]"));
    });

    test("no such method", () {
      proxy.call('foobar').then((result) {
        expect(result.code, equals(-32601));
      });
    });

    test("private method", () {
      proxy.call('_private').then((result) {
        expect(result.code, equals(-32601));
      });
    });

    test("notification had effect", () {
      proxy.call('fetchGlobal').then((result) {
        expect(result, equals([1, 2, 3, 4, 5]));
      });
    });

    test("basic batch", () {
      proxy = new BatchServerProxy(
          'http://127.0.0.1:8394/sum', persistentConnection);
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

    test("batch with error on a notification", () {
      proxy = new BatchServerProxy(
          'http://127.0.0.1:8394/sum', persistentConnection);
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

    test("variable url", () {
      var proxy = new ServerProxy(
          'http://127.0.0.1:8394/friend/Bob', persistentConnection);
      proxy.call('hello').then((result) {
        expect(result, equals("Hello from Bob!"));
      });
      proxy = new ServerProxy(
          'http://127.0.0.1:8394/friend/Mika', persistentConnection);
      proxy.call('hello').then((result) {
        expect(result, equals("Hello from Mika!"));
      });
    });
  });
}
