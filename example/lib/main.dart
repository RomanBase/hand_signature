import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

void main() => runApp(MyApp());

HandSignatureControl control = new HandSignatureControl();

ValueNotifier<String> svg = ValueNotifier<String>(null);

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signature Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        backgroundColor: Colors.orange,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 2.0,
                        child: Container(
                          constraints: BoxConstraints.expand(),
                          margin: EdgeInsets.all(16.0),
                          color: Colors.white,
                          child: HandSignaturePainterView(
                            control: control,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      RaisedButton(
                        onPressed: control.clear,
                        child: Text('clear'),
                      ),
                      RaisedButton(
                        onPressed: () {
                          final data = control.asSvg();
                          svg.value = data;
                        },
                        child: Text('svg'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 16.0,
                  ),
                ],
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: SizedBox(
                  width: 192.0,
                  height: 96.0,
                  child: ValueListenableBuilder<String>(
                    valueListenable: svg,
                    builder: (context, data, child) {
                      return HandSignatureView.svg(data: data);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
