library rpc_widget;
import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:jsonrpc2/jsonrpc_client.dart';
import 'package:logging/logging.dart';
//import 'package:logging_handlers/browser_logging_handlers.dart';

final _logger = new Logger('rpc_example');


@CustomTag('rpc-widget')
class RPCTest extends PolymerElement{

  @published final List methods = [["Echo", 'echo'],
                                   ['Reverse', 'reverse'],
                                   ['Echo - Wait', 'asyncwait'],
                                   ['UPPERCASE', 'uppercase'],
                                   ['lowercase', 'lowercase'],
                                   ['Throw Error', 'throwerror'],
                                   ['bad call', 'bad call'],
                                   ];

  RPCTest.created():super.created();

  @observable int selectedIndex = 0;

  @published var theText ='Lorem ipsum dolor sit, amet animos horreat levis '
      'magnitudinem nobis orátione parvam prómpta sapientes! Affluérét '
      'aliquando clita contra culpa emolumento epicureis fugiamus physici '
      'platonem principes purus restát. Comparaverit dissensio dissentio '
      'indoctum inducitur perdiscere quaestionem! Admirer aegritudo afférré '
      'beata celeritas diceretur erga ignorant permagna prónuntiaret '
      'satisfacit sunt vetuit. Consiliisque indicaverunt intellegi optinéré!';


  @published var output = '';

  void sendEcho(Event e, var detail, Node target){
     var method = methods[selectedIndex][1];
     var proxy = new ServerProxy('http://127.0.0.1:8395/echo');
     var txt = theText;
     if (method == 'asyncwait') output = "Waiting...";
     if (method == 'throwerror') txt = null;
     proxy.call(method, txt)
       .then((resp)=>proxy.checkError(resp))
       .then((result){output = result;})
       .catchError((e){
         output = "";
         window.alert("Error: $e");
         //_logger.warning(e.toString());
         });
  }
}
