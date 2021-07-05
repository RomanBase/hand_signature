import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/parser.dart';

import '../signature.dart';
import 'utils.dart';

/// Wraps [HandSignaturePaint] to paint signature. And [RawGestureDetector] to send input to [HandSignatureControl].
class HandSignaturePainterView extends StatelessWidget {
  /// Controls path creation.
  final HandSignatureControl control;

  /// Colors of path.
  final Color color;

  /// Minimal size of path.
  final double width;

  /// Maximal size of path.
  final double maxWidth;

  /// Path type.
  final SignatureDrawType type;

  /// Callback when path drawing starts.
  final VoidCallback? onPointerDown;

  /// Callback when path drawing ends.
  final VoidCallback? onPointerUp;

  /// Draws [Path] based on input and stores data in [control].
  HandSignaturePainterView({
    Key? key,
    required this.control,
    this.color: Colors.black,
    this.width: 1.0,
    this.maxWidth: 10.0,
    this.type: SignatureDrawType.shape,
    this.onPointerDown,
    this.onPointerUp,
  }) : super(key: key);

  void _startPath(_SinglePanGestureRecognizer? instance, Offset point) {
    instance?.isDown = true;

    if (!control.hasActivePath) {
      onPointerDown?.call();
      control.startPath(point);
    }
  }

  void _endPath(_SinglePanGestureRecognizer? instance) {
    if (control.hasActivePath) {
      control.closePath();
      onPointerUp?.call();
    }

    instance?.isDown = false;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(debugOwner: this),
            (instance) {
              instance.onTapDown =
                  (args) => _startPath(null, args.localPosition);
              instance.onTapUp = (args) => _endPath(null);
            },
          ),
          _SinglePanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_SinglePanGestureRecognizer>(
            () => _SinglePanGestureRecognizer(debugOwner: this),
            (instance) {
              instance.onStart =
                  (args) => _startPath(instance, args.localPosition);
              instance.onUpdate =
                  (args) => control.alterPath(args.localPosition);
              instance.onEnd = (args) => _endPath(instance);
            },
          ),
        },
        child: HandSignaturePaint(
          control: control,
          color: color,
          width: width,
          maxWidth: maxWidth,
          type: type,
          onSize: control.notifyDimension,
        ),
      ),
    );
  }
}

/// Wraps [DrawableSignaturePainter] to paint svg [Drawable].
class HandSignatureView extends StatelessWidget {
  /// Svg data to draw.
  final Drawable? data;

  /// Path color.
  final Color? color;

  /// Path size modifier.
  final double Function(double width)? strokeWidth;

  /// Canvas padding.
  final EdgeInsets? padding;

  /// Placeholder widget when no data provided.
  final Widget? placeholder;

  /// Draws [Path] based on [Drawable] data.
  const HandSignatureView({
    Key? key,
    required this.data,
    this.color,
    this.strokeWidth,
    this.padding,
    this.placeholder,
  }) : super(key: key);

  /// Draws [Path] based on [svg] data.
  static _HandSignatureViewSvg svg({
    Key? key,
    required String data,
    Color? color,
    double Function(double width)? strokeWidth,
    EdgeInsets? padding,
    Widget? placeholder,
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
          size: PathUtil.getDrawableSize(data as DrawableRoot),
          child: CustomPaint(
            painter: DrawableSignaturePainter(
              drawable: data as DrawableParent,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}

/// Parses [svg] to [Drawable] and pains [DrawableSignaturePainter].
class _HandSignatureViewSvg extends StatefulWidget {
  final String? data;
  final Color? color;
  final double Function(double width)? strokeWidth;
  final EdgeInsets? padding;
  final Widget? placeholder;

  const _HandSignatureViewSvg({
    Key? key,
    required this.data,
    this.color,
    this.strokeWidth,
    this.padding,
    this.placeholder,
  }) : super(key: key);

  @override
  _HandSignatureViewSvgState createState() => _HandSignatureViewSvgState();
}

/// State of [_HandSignatureViewSvg].
class _HandSignatureViewSvgState extends State<_HandSignatureViewSvg> {
  DrawableParent? drawable;

  @override
  void initState() {
    super.initState();

    _parseData(widget.data);
  }

  void _parseData(String? data) async {
    if (data == null) {
      drawable = null;
    } else {
      try {
        final parser = SvgParser();
        drawable = await parser.parse(data);
      } catch (err) {
        print(err.toString());
      }
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

/// Custom [PanGestureRecognizer] that handles just one input touch.
/// Don't allow multi touch.
class _SinglePanGestureRecognizer extends PanGestureRecognizer {
  _SinglePanGestureRecognizer({Object? debugOwner})
      : super(debugOwner: debugOwner);

  bool isDown = false;

  @override
  void addAllowedPointer(PointerEvent event) {
    if (isDown) {
      return;
    }

    //isDown = true;
    super.addAllowedPointer(event);
  }

/*
  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);

    if (!event.down) {
      isDown = false;
    }
  }*/
}
