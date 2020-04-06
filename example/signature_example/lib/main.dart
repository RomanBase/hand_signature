import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

void main() => runApp(MyApp());

HandSignatureControl control = new HandSignatureControl();

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
          child: Column(
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
              RaisedButton(
                onPressed: control.clear,
                child: Text('clear'),
              ),
              SizedBox(
                height: 16.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
