import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

class ScrollSample extends StatefulWidget {
  @override
  _ScrollSampleState createState() => _ScrollSampleState();
}

class _ScrollSampleState extends State<ScrollSample> {
  final control = HandSignatureControl();

  /// There is multiple ways how to prevent scrolling during signature drawing.
  /// This is one of the easiest way, but can cause other issues.
  bool scrollEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange,
      child: ListView(
        physics: scrollEnabled ? BouncingScrollPhysics() : NeverScrollableScrollPhysics(),
        children: <Widget>[
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Center(
              child: Text('Scroll Test'),
            ),
          ),
          Container(
            constraints: BoxConstraints.expand(height: 160.0),
            color: Colors.white,
            child: HandSignature(
              control: control,
              type: SignatureDrawType.shape,
              onPointerDown: () {
                setState(() {
                  scrollEnabled = false;
                });
              },
              onPointerUp: () {
                setState(() {
                  scrollEnabled = true;
                });
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () => control.clear(),
              child: Text('clear'),
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
