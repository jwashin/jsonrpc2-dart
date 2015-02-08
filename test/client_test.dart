library client_test;

import 'package:unittest/unittest.dart';
import 'package:jsonrpc2/jsonrpc_client.dart';
import 'package:unittest/html_enhanced_config.dart';
import "classb.dart";


class MyClass {
  MyClass();
}

main() {
  useHtmlEnhancedConfiguration();
  var proxy = new ServerProxy('http://127.0.0.1:8394/sum');
  group('JSON-RPC', () {

    test("positional arguments", () {
      proxy.call('subtract', [23, 42]).then(expectAsync((result) {
        expect(result, equals(-19));
      }));
      proxy.call('subtract', [42, 23]).then(expectAsync((result) {
        expect(result, equals(19));
      }));
    });

    test("named arguments", () {
      proxy.call('nsubtract', {
        'subtrahend': 23,
        'minuend': 42
      }).then(expectAsync((result) {
        expect(result, equals(19));
      }));
      proxy.call('nsubtract', {
        'minuend': 42,
        'subtrahend': 23
      }).then(expectAsync((result) {
        expect(result, equals(19));
      }));
      proxy.call('nsubtract', {
        'minuend': 23,
        'subtrahend': 42
      }).then(expectAsync((result) {
        expect(result, equals(-19));
      }));
      proxy.call('nsubtract', {
        'subtrahend': 42
      }).then(expectAsync((result) {
        expect(result, equals(-42));
      }));
      proxy.call('nsubtract').then(expectAsync((result) {
        expect(result, equals(0));
      }));
    });

    test("notification", () {
      proxy.notify('update', [[1, 2, 3, 4, 5]]).then(expectAsync((result) {
        expect(result, equals(null));
      }));
    });

    test("unicode", () {
      proxy.call('echo', ['Îñţérñåţîöñåļîžåţîờñ']).then(expectAsync((result) {
        expect(result, equals('Îñţérñåţîöñåļîžåţîờñ'));
      }));
    });

    test("unicode2", () {
      proxy.call('echo2', ['Îñţérñåţîöñåļîžåţîờñ']).then(expectAsync((result) {
        expect(result, equals('Îñţérñåţîöñåļîžåţîờñ Τη γλώσσα μου έδωσαν ελληνική'));
      }));
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
      proxy.call('s1', [new ClassB("hello", "goodbye")]).then(expectAsync((result) {
        expect(result, equals('hello'));
      }));
    });

    test("custom error", () {
      proxy.call('baloo', ['sam']).then(expectAsync((result) {
        expect(result, equals('Balooing sam, as requested.'));
      }));
      proxy.call('baloo', ['frotz']).then(expectAsync((result) => result)).then((returned) => proxy.checkError(returned)).then((result) {
        // shouldn't get here
        throw new Exception(result);
      }).catchError((e) {
        expect(e.code, equals(34));
      });
    });

    test("no such method", () {
      proxy.call('foobar').then(expectAsync((result) {
        expect(result.code, equals(-32601));
      }));
    });

    test("private method", () {
      proxy.call('_private').then(expectAsync((result) {
        expect(result.code, equals(-32601));
      }));
    });

    test("notification had effect", () {
      proxy.call('fetchGlobal').then(expectAsync((result) {
        expect(result, equals([1, 2, 3, 4, 5]));
      }));
    });

    test("basic batch", () {
      proxy = new BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy.call('subtract', [23, 42]).then(expectAsync((result) {
        expect(result, equals(-19));
      }));
      proxy.call('subtract', [42, 23]).then(expectAsync((result) {
        expect(result, equals(19));
      }));
      proxy.call('get_data').then(expectAsync((result) {
        expect(result, equals(['hello', 5]));
      }));
      proxy.notify('update', ['happy Tuesday']);

      proxy.call('nsubtract', {
        'minuend': 23,
        'subtrahend': 42
      }).then(expectAsync((result) {
        expect(result, equals(-19));
      }));
      proxy.send();
    });

    test("batch with error on a notification", () {
      proxy = new BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy.call('summation', [[1, 2, 3, 4, 5]]).then(expectAsync((result) {
        expect(result, equals(15));
      }));
      proxy.call('subtract', [42, 23]).then(expectAsync((result) {
        expect(result, equals(19));
      }));
      proxy.call('get_data').then(expectAsync((result) {
        expect(result, equals(['hello', 5]));
      }));
      proxy.notify('update', [[1, 2, 3, 4, 5]]);
      proxy.notify('oopsie');
      proxy.call('nsubtract', {
        'minuend': 23,
        'subtrahend': 42
      }).then(expectAsync((result) {
        expect(result, equals(-19));
      }));
      proxy.send();
    });

    test("variable url", () {
      var proxy = new ServerProxy('http://127.0.0.1:8394/friend/Bob');
      proxy.call('hello').then(expectAsync((result) {
        expect(result, equals("Hello from Bob!"));
      }));
      proxy = new ServerProxy('http://127.0.0.1:8394/friend/Mika');
      proxy.call('hello').then(expectAsync((result) {
        expect(result, equals("Hello from Mika!"));
      }));
    });

  });

}
