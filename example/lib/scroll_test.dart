import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

class ScrollTest extends StatefulWidget {
  @override
  _ScrollTestState createState() => _ScrollTestState();
}

class _ScrollTestState extends State<ScrollTest> {
  final control = HandSignatureControl(
    threshold: 5.0,
    smoothRatio: 0.65,
    velocityRange: 2.0,
  );

  bool scrollEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      body: ListView(
        physics: scrollEnabled
            ? BouncingScrollPhysics()
            : NeverScrollableScrollPhysics(),
        children: <Widget>[
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
          ),
          Container(
            constraints: BoxConstraints.expand(height: 320.0),
            color: Colors.white,
            child: HandSignature(
              control: control,
              type: SignatureDrawType.shape,
              onPointerDown: () {
                setState(() {
                  scrollEnabled = true;
                });
              },
              onPointerUp: () {
                setState(() {
                  scrollEnabled = true;
                });
              },
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.65,
            color: Colors.deepOrange,
          ),
        ],
      ),
    );
  }
}
