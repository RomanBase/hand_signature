import 'package:flutter/material.dart';

import '../signature.dart';

/// Creates [CustomPaint] and rebuilds whenever signature data are changed.
/// All arguments are passed to [PathSignaturePainter].
///
/// Check [HandSignature] and [HandSignatureView].
class HandSignaturePaint extends StatefulWidget {
  /// Paths controller.
  final HandSignatureControl control;

  /// Color of path.
  final Color color;

  /// Minimal size of path.
  final double strokeWidth;

  /// Maximal size of path.
  final double maxStrokeWidth;

  /// Path type.
  final SignatureDrawType type;

  //TODO: remove this and move size changes to State..
  /// Callback when canvas size is changed.
  final bool Function(Size size)? onSize;

  /// Draws path based on data from [control].
  const HandSignaturePaint({
    Key? key,
    required this.control,
    this.color = Colors.black,
    this.strokeWidth = 1.0,
    this.maxStrokeWidth = 10.0,
    this.type = SignatureDrawType.shape,
    this.onSize,
  }) : super(key: key);

  @override
  _HandSignaturePaintState createState() => _HandSignaturePaintState();
}

/// State of [HandSignaturePaint].
/// Subscribes to [HandSignatureControl] and rebuilds whenever signature data are changed.
class _HandSignaturePaintState extends State<HandSignaturePaint> {
  @override
  void initState() {
    super.initState();

    widget.control.params = SignaturePaintParams(
      color: widget.color,
      strokeWidth: widget.strokeWidth,
      maxStrokeWidth: widget.maxStrokeWidth,
    );

    widget.control.addListener(_updateState);
  }

  void _updateState() {
    setState(() {});
  }

  @override
  void didUpdateWidget(HandSignaturePaint oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.control != widget.control) {
      oldWidget.control.removeListener(_updateState);
      widget.control.addListener(_updateState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PathSignaturePainter(
        paths: widget.control.paths,
        color: widget.color,
        width: widget.strokeWidth,
        maxWidth: widget.maxStrokeWidth,
        type: widget.type,
        onSize: widget.onSize,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();

    widget.control.removeListener(_updateState);
  }
}
