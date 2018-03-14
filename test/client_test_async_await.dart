library client_test;

import 'package:test/test.dart';
import 'package:jsonrpc2/jsonrpc_client.dart';
//import 'package:unittest/html_enhanced_config.dart';
//import 'dart:async';
import "package:jsonrpc2/src/classb.dart";

class MyClass {
  MyClass();
}

main() {
  dynamic proxy = new ServerProxy('http://127.0.0.1:8394/sum');
  group('JSON-RPC', () {
    test("positional arguments", () async {
      int result = await proxy.call('subtract', [23, 42]);
      expect(result, equals(-19));
      result = await proxy.call('subtract', [42, 23]);
      expect(result, equals(19));
    });

    test("named arguments", () async {
      int result =
          await proxy.call('nsubtract', {'subtrahend': 23, 'minuend': 42});
      expect(result, equals(19));

      result = await proxy.call('nsubtract', {'minuend': 42, 'subtrahend': 23});
      expect(result, equals(19));

      result = await proxy.call('nsubtract', {'minuend': 23, 'subtrahend': 42});

      expect(result, equals(-19));

      result = await proxy.call('nsubtract', {'subtrahend': 42});
      expect(result, equals(-42));

      result = await proxy.call('nsubtract');
      expect(result, equals(0));
    });

    test("notification", () async {
      var result = await proxy.notify('update', [
        [1, 2, 3, 4, 5]
      ]);
      expect(result, equals(null));
    });

    test("unicode", () async {
      var result = await proxy.call('echo', ['Îñţérñåţîöñåļîžåţîờñ']);
      expect(result, equals('Îñţérñåţîöñåļîžåţîờñ'));
    });

    test("unicode2", () async {
      var result = await proxy.call('echo2', ['Îñţérñåţîöñåļîžåţîờñ']);
      expect(
          result, equals('Îñţérñåţîöñåļîžåţîờñ Τη γλώσσα μου έδωσαν ελληνική'));
    });

    test("not JSON-serializable", () async {
      try {
        await proxy.call('subtract', [3, 0 / 0]);
      } catch (e) {
        expect(e, isUnsupportedError);
      }
    });

    test("class instance not JSON-serializable", () async {
      try {
        await proxy.call('subtract', [3, new MyClass()]);
      } catch (e) {
        expect(e, isUnsupportedError);
      }
    });

    test("serializable class - see classb.dart", () async {
      var result = await proxy.call('s1', [new ClassB("hello", "goodbye")]);
      expect(result, equals('hello'));
    });

    test("custom error", () async {
      var result = await proxy.call('baloo', ['sam']);
      expect(result, equals('Balooing sam, as requested.'));

      result = await proxy.call('baloo', ['frotz']);
      try {
        proxy.checkError(result);
        // should not get here
        throw new Exception(result);
      } catch (e) {
        expect(e.code, equals(34));
      }
    });

    test("no such method", () async {
      var result = await proxy.call('foobar');
      expect(result.code, equals(-32601));
    });

    test("private method", () async {
      var result = await proxy.call('_private');
      expect(result.code, equals(-32601));
    });

    test("notification had effect", () async {
      var result = await proxy.call('fetchGlobal');
      expect(result, equals([1, 2, 3, 4, 5]));
    });

    test("basic batch", () async {
      proxy = new BatchServerProxy('http://127.0.0.1:8394/sum');
      var result1 = proxy.call('subtract', [23, 42]);
      var result2 = proxy.call('subtract', [42, 23]);
      var result3 = proxy.call('get_data');
      proxy.notify('update', ['happy Tuesday']);
      var result4 = proxy.call('nsubtract', {'minuend': 23, 'subtrahend': 42});
      proxy.send();
      expect(await result1, equals(-19));
      expect(await result2, equals(19));
      expect(await result3, equals(['hello', 5]));
      expect(await result4, equals(-19));
    });

    test("batch with error on a notification", () async {
      proxy = new BatchServerProxy('http://127.0.0.1:8394/sum');
      var result1 = proxy.call('summation', [
        [1, 2, 3, 4, 5]
      ]);
      var result2 = proxy.call('subtract', [42, 23]);
      var result3 = proxy.call('get_data');
      proxy.notify('update', [
        [1, 2, 3, 4, 5]
      ]);
      proxy.notify('oopsie');
      var result4 = proxy.call('nsubtract', {'minuend': 23, 'subtrahend': 42});
      proxy.send();
      expect(await result4, equals(-19));
      expect(await result3, equals(['hello', 5]));
      expect(await result2, equals(19));
      expect(await result1, equals(15));
    });

    test("variable url", () async {
      var proxy = new ServerProxy('http://127.0.0.1:8394/friend/Bob');
      var result1 = await proxy.call('hello');
      expect(result1, equals("Hello from Bob!"));
      proxy = new ServerProxy('http://127.0.0.1:8394/friend/Mika');
      var result2 = proxy.call('hello');
      expect(await result2, equals("Hello from Mika!"));
    });
  });
}
