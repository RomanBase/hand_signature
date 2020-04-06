import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hand_signature/signature_control.dart';
import 'package:hand_signature/signature_painter.dart';

class HandSignaturePainterView extends StatelessWidget {
  final Color color;
  final double width;
  final Widget placeholder;
  final HandSignatureControl control;

  HandSignaturePainterView({
    Key key,
    @required this.control,
    this.color: Colors.black,
    this.width: 6.0,
    this.placeholder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          _SinglePanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_SinglePanGestureRecognizer>(
            () => _SinglePanGestureRecognizer(debugOwner: this),
            (PanGestureRecognizer instance) {
              instance.onStart = (args) => control.startPath(args.localPosition);
              instance.onUpdate = (args) => control.alterPath(args.localPosition);
              instance.onEnd = (args) => control.closePath();
            },
          ),
        },
        child: HandSignaturePaint(
          control: control,
          color: color,
          width: width,
          onSize: control.notifyDimension,
        ),
      ),
    );
  }
}

class _SinglePanGestureRecognizer extends PanGestureRecognizer {
  _SinglePanGestureRecognizer({Object debugOwner}) : super(debugOwner: debugOwner);

  bool isDown = false;

  @override
  void addAllowedPointer(PointerEvent event) {
    if (isDown) {
      return;
    }

    isDown = true;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);

    if (!event.down) {
      isDown = false;
    }
  }
}
