library dispatcher_unit_tests;

import 'package:unittest/unittest.dart';
import '../lib/dispatcher.dart';


class Foo {
  String greet_name;
  Foo([this.greet_name = "Stranger"]);

  hi() => 'Hi!';
  hello() => "Hello, $greet_name!";
  greet([name]) => (name == null) ? "Hello, ${greet_name}!" : "Hi, $name!";
  add(num a, num b) => a + b;
  _private_add(num a, num b) => a + b;
  subtract(num a, num b) => a - b;
  subtract_named({num minuend, num subtrahend}) => minuend - subtrahend;
  throwerr(a, num b) {
    throw new Zerr('you expected this!');
  }
}

class Zerr implements Exception {
  String message;
  Zerr(this.message);
}


main() {

  group('Dispatcher', () {

    test("symbolize", () {
      expect(symbolizeKeys({
        "a": 1
      }), equals({
        new Symbol("a"): 1
      }));
    });

    test("simple object", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('hi').then((value) => expect(value, equals('Hi!')));

    });

    test("simple object with param", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('greet', ['Mary']).then((value) => expect(value, equals('Hi, Mary!')));

    });

    test("simple object initialized with param unused", () {
      var z = new Dispatcher(new Foo("Bar"));
      z.dispatch('greet', ['Mary']).then((value) => expect(value, equals('Hi, Mary!')));

    });

    test("simple object initialized with param used", () {
      var z = new Dispatcher(new Foo("Bob"));
      z.dispatch('hello').then((value) => expect(value, equals('Hello, Bob!')));

    });


    test("simple object without optional param", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('greet').then((value) => expect(value, equals('Hello, Stranger!')));

    });

    test("simple addition", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('add', [3, 4]).then((value) => expect(value, equals(7)));

    });

    test("simple subtraction a b", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('subtract', [42, 23]).then((value) => expect(value, equals(19)));

    });
    test("simple subtraction b a", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('subtract', [23, 42]).then((value) => expect(value, equals(-19)));

    });

    test("named subtraction in order", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('subtract_named', [], {
        "minuend": 23,
        "subtrahend": 42
      }).then((value) => expect(value, equals(-19)));

    });

    test("named subtraction out of order", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('subtract_named', [], {
        "subtrahend": 42,
        "minuend": 23
      }).then((value) => expect(value, equals(-19)));

    });

    test("mixed nums", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('add', [3, 4.3]).then((value) => expect(value, equals(7.3)));
    });

    test("method not found", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('zadd', [3, 4.3]).then((value) => expect(value, new isInstanceOf<MethodNotFound>()));
    });

    test("private method call", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('_private_add', [3, 4.3]).then((value) => expect(value, new isInstanceOf<MethodNotFound>()));
    });

    test("invalid parameters too many", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('add', [3, 5, 8]).then((value) => expect(value, new isInstanceOf<InvalidParameters>()));
    });

    test("invalid parameters bad value", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('add', [3, "hello"]).then((value) => expect(value, new isInstanceOf<InvalidParameters>()));
    });

    test("invalid parameters too few", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('add', [3]).then((value) => expect(value, new isInstanceOf<InvalidParameters>()));
    });

    test("internal error", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('throwerr', [3, 0]).then((value) => expect(value, new isInstanceOf<InternalError>()));
    });

    test("private method invocation", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('_private_add', [3, 4.3]).then((value) => expect(value, new isInstanceOf<MethodNotFound>()));
    });

    test("attempt property invocation", () {
      var z = new Dispatcher(new Foo());
      z.dispatch('greet_name').then((value) => expect(value, new isInstanceOf<MethodNotFound>()));
    });


  });
}
