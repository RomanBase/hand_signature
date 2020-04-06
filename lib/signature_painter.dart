import 'package:flutter/material.dart';
import 'package:hand_signature/signature_control.dart';

class HandSignaturePainter extends CustomPainter {
  final List<Path> paths;
  final Color color;
  final double width;
  final bool Function(Size size) onSize;

  HandSignaturePainter({
    @required this.paths,
    this.color: Colors.black,
    this.width: 6.0,
    this.onSize,
  }) : assert(paths != null);

  @override
  void paint(Canvas canvas, Size size) {
    if (onSize != null) {
      if (onSize(size)) {
        return;
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width;

    paths.forEach((path) {
      canvas.drawPath(path, paint);
    });
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class HandSignaturePaint extends StatefulWidget {
  final HandSignatureControl control;
  final Color color;
  final double width;
  final bool Function(Size size) onSize;

  const HandSignaturePaint({
    Key key,
    this.control,
    this.color: Colors.black,
    this.width: 6.0,
    this.onSize,
  }) : super(key: key);

  @override
  _HandSignaturePaintState createState() => _HandSignaturePaintState();
}

class _HandSignaturePaintState extends State<HandSignaturePaint> {
  @override
  void initState() {
    super.initState();

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
      painter: HandSignaturePainter(
        paths: widget.control.paths,
        color: widget.color,
        width: widget.width,
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
