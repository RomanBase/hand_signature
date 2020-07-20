import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

HandSignatureControl control = HandSignatureControl(
  threshold: 5.0,
  smoothRatio: 0.65,
  velocityRange: 2.0,
);

ScrollController scrollController = ScrollController();
FocusNode focusNode = FocusNode();

class ScrollExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      body: ListView(
        controller: scrollController,
        //physics: NeverScrollableScrollPhysics(),
        children: <Widget>[
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
          ),
          Container(
            constraints: BoxConstraints.expand(height: 320.0),
            color: Colors.white,
            child: HandSignaturePainterView(
              control: control,
              type: SignatureDrawType.shape,
              onPointerDown: () {
                focusNode.requestFocus();
                print('down');
              },
              onPointerUp: () {
                print('up');
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
