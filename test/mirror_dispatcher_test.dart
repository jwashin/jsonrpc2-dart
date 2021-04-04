@TestOn('vm')

import 'package:mirror_dispatcher/mirror_dispatcher.dart';
import 'package:rpc_dispatcher/rpc_dispatcher.dart';
import 'package:rpc_exceptions/rpc_exceptions.dart';
import 'package:test/test.dart';

class Foo {
  String greetName;
  Foo([this.greetName = 'Stranger']);
  String hi() => 'Hi!';
  String hello() => 'Hello, $greetName!';
  String greet([String? name]) {
    var tmp = name ?? greetName;
    if (tmp == greetName) {
      return 'Hello, $tmp!';
    }
    return 'Hi, $tmp!';
  }

  num add(num a, num b) => a + b;
  num _privateAdd(num a, num b) => a + b;
  num subtract(num a, num b) => a - b;
  num subtractNamed({required num minuend, required num subtrahend}) =>
      minuend - subtrahend;
  dynamic throwError(num a, num b) {
    throw Zerr('you expected this!');
  }

  dynamic typeerror(dynamic a) {
    try {
      return a + 9;
    } on TypeError {
      throw RuntimeException('Cannot add string and number', -22, [a, 9]);
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
  test('symbolize', () {
    expect(symbolizeKeys({'a': 1}), equals({Symbol('a'): 1}));
  });

  test('simple object', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('hi').then((dynamic value) => expect(value, equals('Hi!')));
  });

  test('simple object with param', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('greet', ['Mary']).then(
        (dynamic value) => expect(value, equals('Hi, Mary!')));
  });

  test('simple object initialized with param unused', () {
    var z = MirrorDispatcher(Foo('Bar'));
    z.dispatch('greet', ['Mary']).then(
        (dynamic value) => expect(value, equals('Hi, Mary!')));
  });

  test('simple object initialized with param used', () {
    var z = MirrorDispatcher(Foo('Bob'));
    z
        .dispatch('hello')
        .then((dynamic value) => expect(value, equals('Hello, Bob!')));
  });

  test('simple object without optional param', () {
    var z = MirrorDispatcher(Foo());
    z
        .dispatch('greet')
        .then((dynamic value) => expect(value, equals('Hello, Stranger!')));
  });

  test('simple addition', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('add', [3, 4]).then((dynamic value) => expect(value, equals(7)));
  });

  test('simple subtraction a b', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('subtract', [42, 23]).then(
        (dynamic value) => expect(value, equals(19)));
  });
  test('simple subtraction b a', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch(
        'subtract', [23, 42]).then((var value) => expect(value, equals(-19)));
  });

  test('named subtraction in order', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('subtractNamed', [], {'minuend': 23, 'subtrahend': 42}).then(
        (var value) => expect(value, equals(-19)));
  });

  test('named subtraction in order no positional placeholder', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('subtractNamed', {'minuend': 23, 'subtrahend': 42}).then(
        (var value) => expect(value, equals(-19)));
  });

  test('named subtraction in order null positional placeholder', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('subtractNamed', null, {'minuend': 23, 'subtrahend': 42}).then(
        (var value) => expect(value, equals(-19)));
  });

  test('named subtraction out of order', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('subtractNamed', [], {'subtrahend': 42, 'minuend': 23}).then(
        (var value) => expect(value, equals(-19)));
  });

  test('mixed nums', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('add', [3, 4.3]).then((var value) => expect(value, equals(7.3)));
  });

  test('method not found', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('zadd', [3, 4.3]).then((dynamic value) =>
        expect(value, TypeMatcher<MethodNotFoundException>()));
  });

  test('private method call', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('_privateAdd', [3, 4.3]).then((dynamic value) =>
        expect(value, TypeMatcher<MethodNotFoundException>()));
  });

  test('invalid parameters too many', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('add', [3, 5, 8]).then((dynamic value) =>
        expect(value, TypeMatcher<InvalidParametersException>()));
  });

  test('invalid parameters bad value', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('add', [3, 'hello']).then((dynamic value) =>
        expect(value, TypeMatcher<InvalidParametersException>()));
  });

  test('invalid parameters too few', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('add', [3]).then((dynamic value) =>
        expect(value, TypeMatcher<InvalidParametersException>()));
  });

  test('internal error', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('throwError', [3, 0]).then(
        (dynamic value) => expect(value, TypeMatcher<RuntimeException>()));
  });

  test('private method invocation', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('_private_add', [3, 4.3]).then((dynamic value) =>
        expect(value, TypeMatcher<MethodNotFoundException>()));
  });

  test('attempt property invocation', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('greet_name').then((dynamic value) =>
        expect(value, TypeMatcher<MethodNotFoundException>()));
  });

  test('catch TypeError in application code', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('typeerror', ['a']).then(
        (dynamic value) => expect(value, TypeMatcher<RuntimeException>()));
  });

  test('divide by zero', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch('divzerotest', [3]).then(
        (dynamic value) => expect(value, double.infinity));
  });

  test('zero over zero', () {
    var z = MirrorDispatcher(Foo());
    z.dispatch(
        'divzerotest', [0]).then((var value) => expect(value.isNaN, true));
  });
}
