//import 'dart:convert';
import 'dart:html';
//import 'dart:async';
import 'package:polymer/polymer.dart';
import 'package:jsonrpc_client/jsonrpc_client.dart';
import 'dart:math';

//@MirrorsUsed(symbols: const ['uppercase','lowercase'], override:'*')
//import 'dart:mirrors';

//MirrorSystem mirrorSystem = currentMirrorSystem();



@CustomTag('rpc-test')
class Super extends PolymerElement{

  static var zstr = [196, 140, 101, 115, 107, 195, 161, 32, 109, 97, 114, 105, 195, 161, 110, 115, 107, 195, 161];

  static String cm = new String.fromCharCodes(zstr);


  static var alternatives = ['superlative', 'wicked cool', r'Česká mariánská' ];
//                            'Česká mariánská' , 'sweet','fantastic', 'awesome'];
  var random = new Random();



  Super.created():super.created(){}


  @published var superlative = alternatives[0];
  @published var countx = "";
  int curridx = 0;

  var count = 0;

  void changeIt(Event e, var detail, Node target) {

    var neu = curridx;

    while (neu == curridx)
      neu = random.nextInt(alternatives.length);

    String newitem = alternatives[neu];
    curridx = neu;

    var p = new BatchServerProxy('http://127.0.0.1:8394/echo');
    print('in: $neu');

    //p.timeout = 9;

     //var f = p.invokeRpc('reverse', [newitem]);
    var rnd = random.nextInt(7);
    var f = null;
    switch (rnd){
      case 0:
        p.notify("echo",newitem);
        break;
      case 1:
        f = p.call("reverse");
        break;
      case 2:
        f = p.call("uppercase",[newitem]);
        break;
      case 3:
        f = p.call("lowercase", newitem);
        break;
      case 4:
        f = p.call('throwerror', ["random message"]);
        break;

      case 5:
        f = p.call('asyncwait', "$newitem. Tada!");
        superlative = 'Waiting...';
        break;
      case 6:
        f = p.call('_privateMethod', newitem);
        break;
      default:
        f = p.call("blecth", [newitem]);
    }
    count += 1;
    var s = p.call("echo", " ct: ($count)");

    p.send();

    if (f != null){
    f.then((resp){
      if (resp is Exception) throw resp;
      superlative = resp;
        print('return: $resp');
        }).catchError(onFail);
    }
    s.then((resp){
      //print("s is responding");
      countx = resp;});

    //superlative = f;

//     superlative = p.parseResponse(t);



    }
  onFail(error){
    //var req = error.data;
    print(error.toString());
  }


}


