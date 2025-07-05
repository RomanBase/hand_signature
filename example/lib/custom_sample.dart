import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hand_signature/signature.dart';

const aspectRatio = 4 / 3;

final random = Random();

class CustomSample extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => CustomSampleState();
}

class CustomSampleState extends State {
  double pressureRatio = 0.0;
  SignatureDrawType drawType = SignatureDrawType.shape;

  late final control = HandSignatureControl(
    setup: () => SignaturePathSetup(
      pressureRatio: pressureRatio,
      args: {
        'type': drawType.name,
        'color': Color.fromARGB(255, random.nextInt(255), random.nextInt(255), random.nextInt(255)).toARGB32(),
      },
    ),
  );

  final rawImage = ValueNotifier<ByteData?>(null);
  final savedState = ValueNotifier<Map?>(null);

  @override
  void initState() {
    super.initState();

    rawImage.addListener(() {
      setState(() {});
    });

    savedState.addListener(() {
      setState(() {});
    });
  }

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
                    drawer: MultiSignatureDrawer(drawers: [
                      ShapeSignatureDrawer(
                        width: 6.0,
                        maxWidth: 16.0,
                        color: Colors.black,
                      ),
                      CustomSignatureDrawer(),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              spacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: () => control.stepBack(),
                  child: Icon(Icons.navigate_before),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: DropdownButton(
                      value: drawType,
                      items: [
                        DropdownMenuItem(
                          value: SignatureDrawType.line,
                          child: Text('Line'),
                        ),
                        DropdownMenuItem(
                          value: SignatureDrawType.shape,
                          child: Text('Shape'),
                        ),
                        DropdownMenuItem(
                          value: SignatureDrawType.arc,
                          child: Text('Arc'),
                        ),
                      ],
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      onChanged: (value) => setState(() {
                        drawType = value ?? SignatureDrawType.shape;
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: DropdownButton(
                      value: pressureRatio,
                      items: [
                        DropdownMenuItem(
                          value: 0.0,
                          child: Text('Velocity'),
                        ),
                        DropdownMenuItem(
                          value: 0.5,
                          child: Text('Balanced'),
                        ),
                        DropdownMenuItem(
                          value: 1.0,
                          child: Text('Pressure'),
                        ),
                      ],
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      onChanged: (value) => setState(() {
                        pressureRatio = value ?? 0.0;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          //Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              spacing: 8.0,
              children: <Widget>[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (savedState.value == null) {
                        savedState.value = control.toMap();
                        control.clear();
                        rawImage.value = null;
                      } else {
                        control.import(savedState.value!);
                        savedState.value = null;
                      }
                    },
                    child: Text(savedState.value == null ? 'save state' : 'load state'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      rawImage.value = await control.toImage(
                        drawer: CustomSignatureDrawer(),
                        width: 512,
                        height: 384,
                        fit: true,
                      );
                    },
                    child: Text('export'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      control.clear();
                      rawImage.value = null;
                    },
                    child: Text('clear'),
                  ),
                ),
              ],
            ),
          ),
          // Export preview
          Container(
            color: Colors.white,
            height: 120.0,
            child: rawImage.value == null
                ? Container(
                    color: Colors.red,
                    child: Center(
                      child: Text('not signed yet (png)\n no scaling'),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Image.memory(rawImage.value!.buffer.asUint8List()),
                  ),
          ),
        ],
      ),
    );
  }
}

class CustomSignatureDrawer extends HandSignatureDrawer {
  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    for (final path in paths) {
      final color = Color(path.setup.args?['color'] ?? 0xFF000000);

      DynamicSignatureDrawer(
        width: 2.0,
        maxWidth: 12.0,
        color: color,
      ).paint(canvas, size, [path]);
    }
  }
}
