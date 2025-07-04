import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hand_signature/signature.dart';
import 'package:signature_example/custom_sample.dart';
import 'package:signature_example/scroll_sample.dart';

void main() => runApp(MyApp());

HandSignatureControl control = new HandSignatureControl();
ValueNotifier<String?> svg = ValueNotifier<String?>(null);
ValueNotifier<ByteData?> rawImage = ValueNotifier<ByteData?>(null);
ValueNotifier<Map?> savedState = ValueNotifier<Map?>(null);
ValueNotifier<int> pageIndex = ValueNotifier<int>(0);

const aspectRatio = 4 / 3;

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MaterialApp(
        title: 'Signature Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              Container(
                color: Colors.grey,
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  spacing: 8.0,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => pageIndex.value = 0,
                        child: Text('base'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => pageIndex.value = 1,
                        child: Text('custom'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => pageIndex.value = 2,
                        child: Text('scroll'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: pageIndex,
                  builder: (context, index, child) => IndexedStack(
                    index: index,
                    children: [
                      SignatureExample(),
                      CustomSample(),
                      ScrollSample(),
                    ],
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

class SignatureExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        spacing: 24.0,
        children: <Widget>[
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Container(
                  constraints: BoxConstraints.expand(),
                  color: Colors.white,
                  child: HandSignature(
                    control: control,
                    drawer: ShapeSignatureDrawer(),
                  ),
                ),
              ),
            ),
          ),
          //Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              spacing: 8.0,
              children: <Widget>[
                Expanded(
                  child: ValueListenableBuilder(
                      valueListenable: savedState,
                      builder: (context, value, _) {
                        return ElevatedButton(
                          onPressed: () {
                            if (value == null) {
                              savedState.value = control.toMap();
                              control.clear();
                              svg.value = null;
                              rawImage.value = null;
                            } else {
                              control.import(value);
                              savedState.value = null;
                            }
                          },
                          child:
                              Text(value == null ? 'save state' : 'load state'),
                        );
                      }),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      svg.value = control.toSvg(
                        color: Colors.blueGrey,
                        type: SignatureDrawType.shape,
                        fit: true,
                      );

                      rawImage.value = await control.toImage(
                        color: Colors.purple,
                      );
                    },
                    child: Text('export'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      control.clear();
                      svg.value = null;
                      rawImage.value = null;
                    },
                    child: Text('clear'),
                  ),
                ),
              ],
            ),
          ),
          // Export preview
          Row(
            spacing: 16.0,
            children: [
              Expanded(
                child: Container(
                  height: 96.0,
                  color: Colors.white,
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
                ),
              ),
              Expanded(
                child: Container(
                  height: 96.0,
                  color: Colors.white,
                  child: ValueListenableBuilder<ByteData?>(
                    valueListenable: rawImage,
                    builder: (context, data, child) {
                      if (data == null) {
                        return Container(
                          color: Colors.red,
                          child: Center(
                            child: Text('not signed yet (png)\n no scaling'),
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
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
