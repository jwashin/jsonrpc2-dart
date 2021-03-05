@TestOn('vm')
library jsonrpc2_server_tests;

import 'package:test/test.dart';
import 'package:jsonrpc2/jsonrpc_service.dart';
import 'package:jsonrpc2/rpc_exceptions.dart';
import 'dart:convert';
import 'dart:async';

class Foo {
  String greet_name;
  Foo([this.greet_name = 'Stranger']);

  String hi() => 'Hi!';
  String hello() => 'Hello, $greet_name!';
  String greet([name]) => (name == null) ? 'Hello, $greet_name!' : 'Hi, $name!';
  num sum(a, b, d) => a + b + d;
  num add(num a, num b) => _private_add(a, b);
  void runtimeException(obj) {
    if (obj != 'frob') {
      throw RuntimeException("Custom error. Expected 'frob', got '$obj'", 105);
    }
  }

  num _private_add(num a, num b) => a + b;
  num subtract(num a, num b) => a - b;
  num notify_hello(aNum) => aNum;
  num subtract_named({required num minuend, required num subtrahend}) =>
      minuend - subtrahend;
  dynamic get_data() => ['hello', 5];
  void throwerr(a, num b) {
    throw Zerr('you expected this!');
  }

  void update(a, b, c, d, e) {}
  dynamic echo(something) => something;
  num oops(a) => 3 + a;
  num oops1(a) {
    try {
      return 3 + a;
    } on TypeError {
      throw RuntimeException(
          "Oops! Can't add ${a.runtimeType} to number.", -22, [3, a]);
    }
  }

  dynamic divzero(p) => p / 0;

  Object my_object() => MyObject();

  Future<int> future3() => Future(() {
        return 3;
      });
}

class Zerr implements Exception {
  String message;
  Zerr(this.message);
}

class MyObject {}

void main() {
  group('jsonrpc_2.0', () {
    test('basic call', () {
      jsonRpcExec({'jsonrpc': '2.0', 'method': 'hi', 'id': 1}, Foo())
          .then((result) {
        expect(result, equals({'jsonrpc': '2.0', 'result': 'Hi!', 'id': 1}));
      });
    });

    test('notification', () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'hi',
      }, Foo())
          .then((result) {
        expect(result, const TypeMatcher<Notification>());
      });
    });

    test('positional params', () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'add',
        'id': 1,
        'params': [1, 2]
      }, Foo())
          .then((result) {
        expect(result, equals({'jsonrpc': '2.0', 'result': 3, 'id': 1}));
      });
    });

    test('named params', () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'subtract_named',
        'id': 1,
        'params': {'minuend': 4, 'subtrahend': 2}
      }, Foo())
          .then((result) {
        expect(result, equals({'jsonrpc': '2.0', 'result': 2, 'id': 1}));
      });
    });

    test('named params, other order', () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'subtract_named',
        'id': 1,
        'params': {'subtrahend': 2, 'minuend': 4}
      }, Foo())
          .then((result) {
        expect(result, equals({'jsonrpc': '2.0', 'result': 2, 'id': 1}));
      });
    });

    test('unicode', () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'echo',
        'id': 1,
        'params': ['México: Hello, 世界']
      }, Foo())
          .then((result) {
        expect(result,
            equals({'jsonrpc': '2.0', 'result': 'México: Hello, 世界', 'id': 1}));
      });
    });

    test('method not found', () {
      jsonRpcExec(
              {'jsonrpc': '2.0', 'method': 'bip', 'id': 1, 'params': []}, Foo())
          .then((result) {
        expect(
            result,
            equals({
              'jsonrpc': '2.0',
              'error': {'code': -32601, 'message': 'Method not found: bip'},
              'id': 1
            }));
      });
    });

    test('runtime error1', () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'throwerr',
        'id': 1,
        'params': ['a', 4]
      }, Foo())
          .then((result) {
        expect(
            result,
            equals({
              'jsonrpc': '2.0',
              'error': {'code': -32000, 'message': 'you expected this!'},
              'id': 1
            }));
      });
    });

    test('custom exception', () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'runtimeException',
        'params': ['bar'],
        'id': 3
      }, Foo())
          .then((result) {
        expect(
            result,
            equals({
              'jsonrpc': '2.0',
              'error': {
                'code': 105,
                'message': "Custom error. Expected 'frob', got 'bar'"
              },
              'id': 3
            }));
      });
    });

    test('TypeError in application code, unhandled', () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'oops',
        'params': ['43'],
        'id': 3
      }, Foo())
          .then((result) {
        expect(result['error']['code'], equals(-32602));
      });
    });

    test('TypeError in application code, handled (dart -c checked mode only)',
        () {
      jsonRpcExec({
        'jsonrpc': '2.0',
        'method': 'oops1',
        'params': ['43'],
        'id': 3
      }, Foo())
          .then((result) {
        expect(result['error']['code'], equals(-22));
        expect(result['error']['message'],
            equals('Oops! Can\'t add String to number.'));
        expect(result['error']['data'], equals([3, '43']));
      });
    });

    test('not JSON serializable', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'my_object',
        'params': [],
        'id': 34
      }''', Foo()).then((result) {
        expect(
            json.decode(result),
            equals({
              'jsonrpc': '2.0',
              'error': {
                'code': -32601,
                'message':
                    'Result was not JSON-serializable (Instance of \'MyObject\').'
              },
              'id': null
            }));
      });
    });

    test('divzero', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'divzero',
        'params': [3],
        'id':34
      }''', Foo()).then((result) {
        expect(
            json.decode(result),
            equals({
              'jsonrpc': '2.0',
              'error': {
                'code': -32601,
                'message': 'Result was not JSON-serializable (Infinity).'
              },
              'id': null
            }));
      });
    });

    test('future returned from method', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'future3',
        'params': [],
        'id':19
      }''', Foo()).then((result) {
        expect(json.decode(result),
            equals({'result': 3, 'id': 19, 'jsonrpc': '2.0'}));
      });
    });
  });

  group('jsonrpc_1.0', () {
    test('basic call', () {
      jsonRpcExec({
        'method': 'subtract',
        'id': 1,
        'params': [6, 2]
      }, Foo())
          .then((result) {
        expect(result, equals({'result': 4, 'error': null, 'id': 1}));
      });
    });

    test('notification', () {
      jsonRpcExec({'method': 'hi', 'params': [], 'id': null}, Foo())
          .then((result) {
        expect(result, const TypeMatcher<Notification>());
      });
    });

    test('method not found', () {
      jsonRpcExec({
        'method': 'bip',
        'id': 1,
        'params': [6, 2]
      }, Foo())
          .then((result) {
        expect(
            result,
            equals({
              'result': null,
              'error': {'code': -32601, 'message': 'Method not found: bip'},
              'id': 1
            }));
      });
    });
  });

  group('jsonrpc2_spec', () {
    test('positional 1', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'subtract',
        'params': [42, 23],
        'id': 1
      }''', Foo()).then((result) {
        expect(json.decode(result),
            equals({'jsonrpc': '2.0', 'result': 19, 'id': 1}));
      });
    });

    test('positional 2', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'subtract',
        'params': [23, 42],
        'id': 2
      }''', Foo()).then((result) {
        expect(json.decode(result),
            equals({'jsonrpc': '2.0', 'result': -19, 'id': 2}));
      });
    });

    test('named 1', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'subtract_named',
        'params': {
          'subtrahend': 23,
          'minuend': 42
        },
        'id': 3
      }''', Foo()).then((result) {
        expect(json.decode(result),
            equals({'jsonrpc': '2.0', 'result': 19, 'id': 3}));
      });
    });

    test('named 2', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'subtract_named',
        'params': {
          'minuend': 42,
          'subtrahend': 23
        },
        'id': 4
      }''', Foo()).then((result) {
        expect(json.decode(result),
            equals({'jsonrpc': '2.0', 'result': 19, 'id': 4}));
      });
    });

    test('notification', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'update',
        'params': [1, 2, 3, 4, 5]
      }''', Foo()).then((result) {
        expect(result, equals(null));
      });
    });

    test('nonexistent method', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 'foobar',
        'id': '1'
      }''', Foo()).then((result) {
        expect(
            json.decode(result),
            equals({
              'jsonrpc': '2.0',
              'error': {'code': -32601, 'message': 'Method not found: foobar'},
              'id': '1'
            }));
      });
    });

    test('invalid JSON', () {
      jsonRpc('''{'jsonrpc': '2.0',
                  'method': 'foobar,
                  'params': 'bar',
                  'baz''', Foo()).then((result) {
        expect(
            json.decode(result),
            equals({
              'jsonrpc': '2.0',
              'error': {'code': -32700, 'message': 'Parse error'},
              'id': null
            }));
      });
    });

    test('invalid request object', () {
      jsonRpc('''{
        'jsonrpc': '2.0',
        'method': 1,
        'params': 'bar'
      }''', Foo()).then((result) {
        expect(
            json.decode(result),
            equals({
              'jsonrpc': '2.0',
              'error': {'code': -32600, 'message': 'Invalid request'},
              'id': null
            }));
      });
    });

    test('batch invalid JSON', () {
      jsonRpc('''[{'jsonrpc': '2.0',
              'method': 'sum',
              'params': [1,2,4],
              'id': '1'},
              {'jsonrpc': '2.0', 'method']''', Foo()).then((result) {
        expect(
            json.decode(result),
            equals({
              'jsonrpc': '2.0',
              'error': {'code': -32700, 'message': 'Parse error'},
              'id': null
            }));
      });
    });

    test('batch empty array', () {
      jsonRpc('[]', Foo()).then((result) {
        expect(
            json.decode(result),
            equals({
              'jsonrpc': '2.0',
              'error': {'code': -32600, 'message': 'Invalid request'},
              'id': null
            }));
      });
    });

    test('batch invalid but not empty', () {
      jsonRpc('[1]', Foo()).then((result) {
        expect(
            json.decode(result),
            equals([
              {
                'jsonrpc': '2.0',
                'error': {'code': -32600, 'message': 'Invalid request'},
                'id': null
              }
            ]));
      });
    });

    test('invalid batch', () {
      jsonRpc('[1,2,3]', Foo()).then((result) {
        expect(
            json.decode(result),
            equals([
              {
                'jsonrpc': '2.0',
                'error': {'code': -32600, 'message': 'Invalid request'},
                'id': null
              },
              {
                'jsonrpc': '2.0',
                'error': {'code': -32600, 'message': 'Invalid request'},
                'id': null
              },
              {
                'jsonrpc': '2.0',
                'error': {'code': -32600, 'message': 'Invalid request'},
                'id': null
              }
            ]));
      });
    });

    test('batch', () {
      jsonRpc('''[ {'jsonrpc': '2.0', 'method': 'sum', 'params': [1,2,4], 'id': '1'},
        {'jsonrpc': '2.0', 'method': 'notify_hello', 'params': [7]},
        {'jsonrpc': '2.0', 'method': 'subtract', 'params': [42,23], 'id': '2'},
        {'foo': 'boo'},
        {'jsonrpc': '2.0', 'method': 'foo.get', 'params': {'name': 'myself'}, 'id': '5'},
        {'jsonrpc': '2.0', 'method': 'get_data', 'id': '9'} ]''', Foo())
          .then((result) {
        expect(
            json.decode(result),
            equals([
              {'jsonrpc': '2.0', 'result': 7, 'id': '1'},
              {'jsonrpc': '2.0', 'result': 19, 'id': '2'},
              {
                'jsonrpc': '2.0',
                'error': {'code': -32600, 'message': 'Invalid request'},
                'id': null
              },
              {
                'jsonrpc': '2.0',
                'error': {
                  'code': -32601,
                  'message': 'Method not found: foo.get'
                },
                'id': '5'
              },
              {
                'jsonrpc': '2.0',
                'result': ['hello', 5],
                'id': '9'
              }
            ]));
      });
    });

    test('batch with only notifications', () {
      jsonRpc('''[
      {'jsonrpc': '2.0', 'method': 'notify_sum',   'params': [1,2,4]},
      {'jsonrpc': '2.0', 'method': 'notify_hello', 'params': [7]}
      ]''', Foo()).then((result) {
        expect(result, equals(null));
      });
    });
    //
    test('unicode', () {
      jsonRpc('''{
            'jsonrpc': '2.0',
            'method': 'echo',
            'id': 1,
            'params': ['México: Hello, 世界']
          }''', Foo()).then((result) {
        expect(json.decode(result),
            equals({'jsonrpc': '2.0', 'result': 'México: Hello, 世界', 'id': 1}));
      });
    });
  });
}
