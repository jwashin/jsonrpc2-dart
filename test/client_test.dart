library client_test;

import 'package:test/test.dart';
import 'package:jsonrpc2/jsonrpc_client.dart';
//import 'package:test/html_enhanced_config.dart';
import "package:jsonrpc2/src/classb.dart";

class MyClass {
  MyClass();
}

void main() {
  ServerProxy proxy = new ServerProxy('http://127.0.0.1:8394/sum');
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
      try {
        proxy.call('subtract', [3, 0 / 0]);
      } catch (e) {
        expect(e, isUnsupportedError);
      }
    });

    test("class instance not JSON-serializable", () {
      try {
        proxy.call('subtract', [3, new MyClass()]);
      } catch (e) {
        expect(e, isUnsupportedError);
      }
    });

    test("serializable class - see classb.dart", () {
      proxy.call('s1', [new ClassB("hello", "goodbye")]).then((result) {
        expect(result, equals('hello'));
      });
    });

    test("custom error", () {
      proxy.call('baloo', ['sam']).then((result) {
        expect(result, equals('Balooing sam, as requested.'));
      });
      proxy
          .call('baloo', ['frotz'])
          .then((result) => result)
          .then((returned) => proxy.checkError(returned))
          .then((result) {
            // shouldn't get here
            throw new Exception(result);
          })
          .catchError((e) {
            print("$e, ${e.runtimeType}");
            expect(e.code, equals(34));
          });
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
      BatchServerProxy proxy =
          new BatchServerProxy('http://127.0.0.1:8394/sum');
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
      BatchServerProxy proxy =
          new BatchServerProxy('http://127.0.0.1:8394/sum');
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
      ServerProxy proxy = new ServerProxy('http://127.0.0.1:8394/friend/Bob');
      proxy.call('hello').then((result) {
        expect(result, equals("Hello from Bob!"));
      });
      proxy = new ServerProxy('http://127.0.0.1:8394/friend/Mika');
      proxy.call('hello').then((result) {
        expect(result, equals("Hello from Mika!"));
      });
    });
  });
}
