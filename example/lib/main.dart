import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hand_signature/signature.dart';

import 'scroll_test.dart';

void main() => runApp(MyApp());

HandSignatureControl control = new HandSignatureControl(
  threshold: 0.01,
  smoothRatio: 0.65,
  velocityRange: 2.0,
);

ValueNotifier<String?> svg = ValueNotifier<String?>(null);

ValueNotifier<ByteData?> rawImage = ValueNotifier<ByteData?>(null);

ValueNotifier<ByteData?> rawImageFit = ValueNotifier<ByteData?>(null);

class MyApp extends StatelessWidget {
  bool get scrollTest => false;

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
        body: scrollTest
            ? ScrollTest()
            : SafeArea(
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
                                    child: HandSignature(
                                      control: control,
                                      type: SignatureDrawType.shape,
                                    ),
                                  ),
                                  CustomPaint(
                                    painter: DebugSignaturePainterCP(
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
                            CupertinoButton(
                              onPressed: () {
                                control.clear();
                                svg.value = null;
                                rawImage.value = null;
                                rawImageFit.value = null;
                              },
                              child: Text('clear'),
                            ),
                            CupertinoButton(
                              onPressed: () async {
                                svg.value = control.toSvg(
                                  color: Colors.blueGrey,
                                  type: SignatureDrawType.shape,
                                  fit: true,
                                );

                                rawImage.value = await control.toImage(
                                  color: Colors.blueAccent,
                                  background: Colors.greenAccent,
                                  fit: false,
                                );

                                rawImageFit.value = await control.toImage(
                                  color: Colors.black,
                                  background: Colors.greenAccent,
                                  fit: true,
                                );
                              },
                              child: Text('export'),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _buildImageView(),
                          _buildScaledImageView(),
                          _buildSvgView(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildImageView() => Container(
        width: 192.0,
        height: 96.0,
        decoration: BoxDecoration(
          border: Border.all(),
          color: Colors.white30,
        ),
        child: ValueListenableBuilder<ByteData?>(
          valueListenable: rawImage,
          builder: (context, data, child) {
            if (data == null) {
              return Container(
                color: Colors.red,
                child: Center(
                  child: Text('not signed yet (png)\nscaleToFill: false'),
                ),
              );
            } else {
              return Padding(
                padding: EdgeInsets.all(8.0),
                child: Image.memory(data.buffer.asUint8List()),
              );
            }
          },
        ),
      );

  Widget _buildScaledImageView() => Container(
        width: 192.0,
        height: 96.0,
        decoration: BoxDecoration(
          border: Border.all(),
          color: Colors.white30,
        ),
        child: ValueListenableBuilder<ByteData?>(
          valueListenable: rawImageFit,
          builder: (context, data, child) {
            if (data == null) {
              return Container(
                color: Colors.red,
                child: Center(
                  child: Text('not signed yet (png)\nscaleToFill: true'),
                ),
              );
            } else {
              return Container(
                padding: EdgeInsets.all(8.0),
                color: Colors.orange,
                child: Image.memory(data.buffer.asUint8List()),
              );
            }
          },
        ),
      );

  Widget _buildSvgView() => Container(
        width: 192.0,
        height: 96.0,
        decoration: BoxDecoration(
          border: Border.all(),
          color: Colors.white30,
        ),
        child: ValueListenableBuilder<String?>(
          valueListenable: svg,
          builder: (context, data, child) {
            if (data == null) {
              return Container(
                color: Colors.red,
                child: Center(
                  child: Text('not signed yet (svg)'),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.all(8.0),
              child: SvgPicture.string(
                data,
                placeholderBuilder: (_) => Container(
                  color: Colors.lightBlueAccent,
                  child: Center(
                    child: Text('parsing data(svg)'),
                  ),
                ),
              ),
            );
          },
        ),
      );
}
