import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

void main() => runApp(MyApp());

HandSignatureControl control = new HandSignatureControl(
  threshold: 5.0,
  smoothRatio: 0.65,
  velocityRange: 2.0,
);

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
                        child: Stack(
                          children: <Widget>[
                            Container(
                              constraints: BoxConstraints.expand(),
                              color: Colors.white,
                              child: HandSignaturePainterView(
                                control: control,
                              ),
                            ),
                            CustomPaint(
                              painter: SignaturePainterCP(
                                control: control,
                                cp: false,
                                cpStart: false,
                                cpEnd: false,
                              ),
                            ),
                          ],
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
                          final data = control.toSvg(
                            color: Colors.blueGrey,
                            size: 2.0,
                            maxSize: 15.0,
                          );
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
                      return HandSignatureView.svg(
                        data: data,
                        strokeWidth: (width) => width * 0.5,
                      );
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
