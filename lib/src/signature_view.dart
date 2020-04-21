import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/parser.dart';

import '../signature.dart';
import 'utils.dart';

class HandSignaturePainterView extends StatelessWidget {
  final HandSignatureControl control;
  final Color color;
  final double width;
  final double maxWidth;
  final SignatureDrawType type;

  HandSignaturePainterView({
    Key key,
    @required this.control,
    this.color: Colors.black,
    this.width: 1.0,
    this.maxWidth: 10.0,
    this.type: SignatureDrawType.shape,
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
          type: type,
          onSize: control.notifyDimension,
        ),
      ),
    );
  }
}

class HandSignatureView extends StatelessWidget {
  final Drawable data;
  final Color color;
  final double Function(double width) strokeWidth;
  final EdgeInsets padding;
  final Widget placeholder;

  const HandSignatureView({
    Key key,
    @required this.data,
    this.color,
    this.strokeWidth,
    this.padding,
    this.placeholder,
  }) : super(key: key);

  static _HandSignatureViewSvg svg({
    Key key,
    @required String data,
    Color color,
    double Function(double width) strokeWidth,
    EdgeInsets padding,
    Widget placeholder,
  }) =>
      _HandSignatureViewSvg(
        key: key,
        data: data,
        color: color,
        strokeWidth: strokeWidth,
        padding: padding,
        placeholder: placeholder,
      );

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return placeholder ?? Container(color: Colors.transparent);
    }

    return Padding(
      padding: padding ?? EdgeInsets.all(8.0),
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox.fromSize(
          size: PathUtil.getDrawableSize(data),
          child: CustomPaint(
            painter: DrawableSignaturePainter(
              drawable: data,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}

class _HandSignatureViewSvg extends StatefulWidget {
  final String data;
  final Color color;
  final double Function(double width) strokeWidth;
  final EdgeInsets padding;
  final Widget placeholder;

  const _HandSignatureViewSvg({
    Key key,
    @required this.data,
    this.color,
    this.strokeWidth,
    this.padding,
    this.placeholder,
  }) : super(key: key);

  @override
  _HandSignatureViewSvgState createState() => _HandSignatureViewSvgState();
}

class _HandSignatureViewSvgState extends State<_HandSignatureViewSvg> {
  DrawableParent drawable;

  @override
  void initState() {
    super.initState();

    _parseData(widget.data);
  }

  void _parseData(String data) async {
    if (data == null) {
      drawable = null;
    } else {
      final parser = SvgParser();
      drawable = await parser.parse(data);
    }

    setState(() {});
  }

  @override
  void didUpdateWidget(_HandSignatureViewSvg oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data != widget.data) {
      if (drawable != null) {
        setState(() {
          drawable = null;
        });
      }

      _parseData(widget.data);
    }
  }

  @override
  Widget build(BuildContext context) => HandSignatureView(
        data: drawable,
        color: widget.color,
        strokeWidth: widget.strokeWidth,
        padding: widget.padding,
        placeholder: widget.placeholder,
      );
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
