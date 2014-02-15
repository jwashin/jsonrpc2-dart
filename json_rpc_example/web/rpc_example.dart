import 'dart:html';
import 'package:jsonrpc2/jsonrpc_client.dart';

List methods = [["Echo", 'echo'],
                                   ['Reverse', 'reverse'],
                                   ['Echo - Wait', 'asyncwait'],
                                   ['UPPERCASE', 'uppercase'],
                                   ['lowercase', 'lowercase'],
                                   ['Throw Error', 'throwerror'],
                                   ['bad call', 'bad call'],
                                   ];

String theText ='Lorem ipsum dolor sit, amet animos horreat levis '
        'magnitudinem nobis orátione parvam prómpta sapientes! Affluérét '
        'aliquando clita contra culpa emolumento epicureis fugiamus physici '
        'platonem principes purus restát. Comparaverit dissensio dissentio '
        'indoctum inducitur perdiscere quaestionem! Admirer aegritudo afférré '
        'beata celeritas diceretur erga ignorant permagna prónuntiaret '
        'satisfacit sunt vetuit. Consiliisque indicaverunt intellegi optinéré!';

main(){
  
  TextAreaElement sample_text = querySelector('#text1');
  sample_text.value = theText;
  
  SelectElement methodChooser = querySelector('#method_chooser');
  for (List method in methods){
    OptionElement option =  new OptionElement(data:method[0], value:method[1]);
    methodChooser.append(option);
    
  }
  methodChooser.onChange.listen((_)=>sendEcho(_));
  ButtonElement button = querySelector('#submit');
  button.onClick.listen((_)=>sendEcho(_));
  methodChooser.selectedIndex = 0;
  button.click();
  
}

setOutput(text){
  ParagraphElement output = querySelector('#output');
  //output.text = text;
  
  output.setInnerHtml(text, validator:new NodeValidatorBuilder()..allowTextElements());
}
  
sendEcho(Event e){
   ServerProxy proxy = new ServerProxy('http://127.0.0.1:8395/echo');
   TextAreaElement sampleText = querySelector('#text1');
   //sample_text.value = theText;
   String txt = sampleText.value;
   String output = '';
   SelectElement selElement = querySelector('#method_chooser');
   int idx = selElement.selectedIndex;
   String method = methods[idx][1];
   
   // something to show for a couple of seconds
   if (method == 'asyncwait') output = "Waiting...";
   
   // This error is more fun with null text.
   if (method == 'throwerror')txt=null;
   
   proxy.call(method, txt)
     .then((resp)=>proxy.checkError(resp))
     .then((result){setOutput(result);})
     .catchError((e){
       setOutput("");
       window.alert("Error: $e");
       });
   setOutput(output);
}

