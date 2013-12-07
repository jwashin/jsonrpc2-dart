import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:unittest/unittest.dart';
import '../../lib/jsonrpc_client.dart';
import 'package:unittest/html_config.dart';
import 'package:logging/logging.dart';
import 'package:logging_handlers/logging_handlers_shared.dart';


final _logger = new Logger('rpctest');

@CustomTag('rpc-test')
class RPCTest extends PolymerElement{

  @published final List methods = [["Echo", 'echo'],
                                   ['Reverse', 'reverse'],
                                   ['Echo - Wait', 'asyncwait'],
                                   ['UPPERCASE', 'uppercase'],
                                   ['lowercase', 'lowercase'],
                                   ['Throw Error', 'throwerror'],
                                   ['bad call', 'bad_call'],
                                   ];

  RPCTest.created():super.created();

  @observable int selectedIndex = 0;

  @published var theText ='Lorem ipsum dolor sit, amet animos horreat levis'
      'magnitudinem nobis orátione parvam prómpta sapientes! Affluérét '
      'aliquando clita contra culpa emolumento epicureis fugiamus physici '
      'platonem principes purus restát. Comparaverit dissensio dissentio '
      'indoctum inducitur perdiscere quaestionem! Admirer aegritudo afférré '
      'beata celeritas diceretur erga ignorant permagna prónuntiaret '
      'satisfacit sunt vetuit. Consiliisque indicaverunt intellegi optinéré!';


  @published var output = '';

  void sendEcho(Event e, var detail, Node target){
     var method = methods[selectedIndex][1];
     var proxy = new ServerProxy('http://127.0.0.1:8394/echo');
     var txt = theText;
     if (method == 'asyncwait') output = "Waiting...";
     if (method == 'throwerror') txt = "Surprise!!";
     proxy.call(method, txt)
       .then((resp)=>proxy.checkError(resp))
       .then((result){output = result;})
       .catchError((e){
         output = "error -- $e";
         _logger.warning(e.toString());
         });
  }

}

main(){
  useHtmlConfiguration();
  Logger.root.onRecord.listen(new LogPrintHandler());
  Logger.root.level = Level.ALL;
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

    test("basic batch", (){
      proxy = new BatchServerProxy('http://127.0.0.1:8394/sum');
      proxy.call('subtract', [23, 42]).then(expectAsync1((result){expect(result, equals(-19));}));
      proxy.call('subtract', [42, 23]).then(expectAsync1((result){expect(result, equals(19));}));
      proxy.call('get_data').then(expectAsync1((result){expect(result, equals(['hello',5]));}));
      proxy.notify('update', [[1,2,3,4,5]]);

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
