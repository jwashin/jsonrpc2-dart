@TestOn("vm")
library dispatcher_unit_tests;

import 'package:test/test.dart';
import 'package:jsonrpc2/dispatcher.dart';
import 'package:jsonrpc2/rpc_exceptions.dart';

class Foo {
  String greetName;
  Foo([this.greetName = "Stranger"]);
  String hi() => 'Hi!';
  String hello() => "Hello, $greetName!";
  String greet([String name]) =>
      (name == null) ? "Hello, $greetName!" : "Hi, $name!";
  num add(num a, num b) => a + b;
  num _privateAdd(num a, num b) => a + b;
  num subtract(num a, num b) => a - b;
  num subtractNamed({num minuend, num subtrahend}) => minuend - subtrahend;
  dynamic throwError(num a, num b) {
    throw new Zerr('you expected this!');
  }

  dynamic typeerror(dynamic a) {
    try {
      return a + 9;
    } on TypeError {
      throw new RuntimeException('Cannot add string and number', -22, [a, 9]);
    }
  }

  num divzerotest(num a) {
    return a / 0;
  }

  num usePrivateAdd(num a, num b) {
    return _privateAdd(a, b);
  }
}

class Zerr implements Exception {
  String message;
  Zerr(this.message);
}

void main() {
  test("symbolize", () {
    expect(symbolizeKeys({"a": 1}), equals({new Symbol("a"): 1}));
  });

  test("simple object", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('hi').then((dynamic value) => expect(value, equals('Hi!')));
  });

  test("simple object with param", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('greet', ['Mary']).then(
        (dynamic value) => expect(value, equals('Hi, Mary!')));
  });

  test("simple object initialized with param unused", () {
    Dispatcher z = new Dispatcher(new Foo("Bar"));
    z.dispatch('greet', ['Mary']).then(
        (dynamic value) => expect(value, equals('Hi, Mary!')));
  });

  test("simple object initialized with param used", () {
    Dispatcher z = new Dispatcher(new Foo("Bob"));
    z
        .dispatch('hello')
        .then((dynamic value) => expect(value, equals('Hello, Bob!')));
  });

  test("simple object without optional param", () {
    Dispatcher z = new Dispatcher(new Foo());
    z
        .dispatch('greet')
        .then((dynamic value) => expect(value, equals('Hello, Stranger!')));
  });

  test("simple addition", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('add', [3, 4]).then((dynamic value) => expect(value, equals(7)));
  });

  test("simple subtraction a b", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('subtract', [42, 23]).then(
        (dynamic value) => expect(value, equals(19)));
  });
  test("simple subtraction b a", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch(
        'subtract', [23, 42]).then((var value) => expect(value, equals(-19)));
  });

  test("named subtraction in order", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('subtractNamed', [], {"minuend": 23, "subtrahend": 42}).then(
        (var value) => expect(value, equals(-19)));
  });

  test("named subtraction out of order", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('subtractNamed', [], {"subtrahend": 42, "minuend": 23}).then(
        (var value) => expect(value, equals(-19)));
  });

  test("mixed nums", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('add', [3, 4.3]).then((var value) => expect(value, equals(7.3)));
  });

  test("method not found", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('zadd', [3, 4.3]).then(
        (dynamic value) => expect(value, TypeMatcher<MethodNotFound>()));

    ///#new isInstanceOf<MethodNotFound>()));
  });

  test("private method call", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('_privateAdd', [3, 4.3]).then(
        (dynamic value) => expect(value, TypeMatcher<MethodNotFound>()));
  });

  test("invalid parameters too many", () {
    Dispatcher z = Dispatcher(Foo());
    z.dispatch('add', [3, 5, 8]).then(
        (dynamic value) => expect(value, TypeMatcher<InvalidParameters>()));
  });

  test("invalid parameters bad value", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('add', [3, "hello"]).then(
        (dynamic value) => expect(value, TypeMatcher<InvalidParameters>()));
  });

  test("invalid parameters too few", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('add', [3]).then(
        (dynamic value) => expect(value, TypeMatcher<InvalidParameters>()));
  });

  test("internal error", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('throwError', [3, 0]).then(
        (dynamic value) => expect(value, TypeMatcher<RuntimeException>()));
  });

  test("private method invocation", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('_private_add', [3, 4.3]).then(
        (dynamic value) => expect(value, TypeMatcher<MethodNotFound>()));
  });

  test("attempt property invocation", () {
    Dispatcher z = new Dispatcher(new Foo());
    z
        .dispatch('greet_name')
        .then((dynamic value) => expect(value, TypeMatcher<MethodNotFound>()));
  });

  test("catch TypeError in application code", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('typeerror', ['a']).then(
        (dynamic value) => expect(value, TypeMatcher<RuntimeException>()));
  });

  test("divide by zero", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch('divzerotest', [3]).then(
        (dynamic value) => expect(value, double.infinity));
  });

  test("zero over zero", () {
    Dispatcher z = new Dispatcher(new Foo());
    z.dispatch(
        'divzerotest', [0]).then((var value) => expect(value.isNaN, true));
  });
}
