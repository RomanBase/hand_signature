import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hand_signature/signature_control.dart';

class LineSignaturePainter extends CustomPainter {
  final List<CubicLine> paths;
  final Color color;
  final double width;
  final double maxWidth;
  final bool Function(Size size) onSize;

  LineSignaturePainter({
    @required this.paths,
    this.color: Colors.black,
    this.width: 1.0,
    this.maxWidth: 10.0,
    this.onSize,
  }) : assert(paths != null);

  @override
  void paint(Canvas canvas, Size size) {
    if (onSize != null) {
      if (onSize(size)) {
        return;
      }
    }

    if (paths.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width;

    double velocity = paths[0].velocity();
    double startWidth = _width(velocity);

    for (int i = 0; i < paths.length; i++) {
      final steps = (paths[i].length() * 2.0).floor();

      final combinedVelocity = paths[i].combineVelocity(velocity, maxFallOf: 0.275);
      final double endWidth = _width(combinedVelocity);

      _drawLine(paths[i], startWidth, endWidth - startWidth, canvas, paint, steps);

      startWidth = endWidth;
      velocity = combinedVelocity;
    }
  }

  double _width(double velocity) {
    velocity = math.pow(velocity, 3) / 3.0;

    return 1.0 + (maxWidth - width) * (1.0 - velocity.clamp(0.0, 1.0));
  }

  void _drawLine(CubicLine line, double width, double widthDelta, Canvas canvas, Paint paint, int steps) {
    Offset start = line.start;
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final loc = line.point(t);
      final size = math.min(maxWidth, width + widthDelta * math.pow(t, 3));

      paint.strokeWidth = size;

      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..arcToPoint(loc, rotation: math.pi * 2.0),
        paint,
      );

      start = loc;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

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

    widget.control.params = SignaturePaintParams(
      color: widget.color,
      width: widget.width,
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
      painter: LineSignaturePainter(
        paths: widget.control.lines,
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

class SignaturePainterCP extends CustomPainter {
  final HandSignatureControl control;
  final bool cpStart;
  final bool cpEnd;
  final bool dot;
  final Color color;

  SignaturePainterCP({
    @required this.control,
    this.cpStart: true,
    this.cpEnd: true,
    this.dot: true,
    this.color: Colors.red,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.0;

    control.lines.forEach((line) {
      if (cpStart) {
        canvas.drawLine(line.start, line.cpStart, paint);
        if (dot) {
          canvas.drawCircle(line.cpStart, 1.0, paint);
          canvas.drawCircle(line.start, 1.0, paint);
        }
      }

      if (cpEnd) {
        canvas.drawLine(line.end, line.cpEnd, paint);
        if (dot) {
          canvas.drawCircle(line.cpEnd, 1.0, paint);
        }
      }
    });
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
