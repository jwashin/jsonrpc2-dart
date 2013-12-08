import 'package:unittest/unittest.dart';
import 'package:jsonrpc2/jsonrpc_client.dart';
import 'package:unittest/html_config.dart';

main(){
  useHtmlConfiguration();
  var proxy = new ServerProxy('http://127.0.0.1:8394/sum');
  group('JSON-RPC Protocol', (){

    test("positional arguments", (){
    proxy.call('subtract', [23, 42]).then(expectAsync1((result){expect(result, equals(-19));}));
    proxy.call('subtract', [42, 23]).then(expectAsync1((result){expect(result, equals(19));}));
    });

    test("named arguments", (){
    proxy.call('nsubtract', {'subtrahend':23, 'minuend':42}).then(expectAsync1((result){expect(result, equals(19));}));
    proxy.call('nsubtract', {'minuend':42, 'subtrahend':23}).then(expectAsync1((result){expect(result, equals(19));}));
    proxy.call('nsubtract', {'minuend':23, 'subtrahend':42}).then(expectAsync1((result){expect(result, equals(-19));}));
    proxy.call('nsubtract', {'subtrahend':42}).then(expectAsync1((result){expect(result, equals(-42));}));
    });

    test("notification", (){
      proxy.notify('update', [[1,2,3,4,5]]).then(expectAsync1((result){expect(result, equals(null));}));
    });

    test("no such method", (){
      proxy.call('foobar').then(expectAsync1((result){expect(result.code, equals(-32601));}));
    });

    test("private method", (){
      proxy.call('_private').then(expectAsync1((result){expect(result.code, equals(-32600));}));
    });

    test("notification had effect", (){
      proxy.call('fetchGlobal').then(expectAsync1((result){expect(result, equals([1,2,3,4,5]));}));
    });

    test("basic batch", (){
      proxy = new BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy.call('subtract', [23, 42]).then(expectAsync1((result){expect(result, equals(-19));}));
      proxy.call('subtract', [42, 23]).then(expectAsync1((result){expect(result, equals(19));}));
      proxy.call('get_data').then(expectAsync1((result){expect(result, equals(['hello',5]));}));
      proxy.notify('update', ['happy Tuesday']);

      proxy.call('nsubtract', {'minuend':23, 'subtrahend':42}).then(expectAsync1((result){expect(result, equals(-19));}));
      proxy.send();
      });

    test("batch with error on a notification", (){
      proxy = new BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy.call('summation', [[1,2,3,4,5]]).then(expectAsync1((result){expect(result, equals(15));}));
      proxy.call('subtract', [42, 23]).then(expectAsync1((result){expect(result, equals(19));}));
      proxy.call('get_data').then(expectAsync1((result){expect(result, equals(['hello',5]));}));
      proxy.notify('update', [[1,2,3,4,5]]);
      proxy.notify('oopsie');
      proxy.call('nsubtract', {'minuend':23, 'subtrahend':42}).then(expectAsync1((result){expect(result, equals(-19));}));
      proxy.send();
      });

    test("variable url", (){
      var proxy = new ServerProxy('http://127.0.0.1:8394/friend/Bob');
      proxy.call('hello').then(expectAsync1((result){expect(result, equals("Hello from Bob!"));}));
      proxy = new ServerProxy('http://127.0.0.1:8394/friend/Mika');
      proxy.call('hello').then(expectAsync1((result){expect(result, equals("Hello from Mika!"));}));
      });

    });

}
