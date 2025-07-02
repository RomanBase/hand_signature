import 'package:flutter/material.dart';

import '../signature.dart';

/// Type of signature path.
/// [line] - simple line with constant size.
/// [arc] - nicest, but worst performance. Creates thousands of small arcs.
/// [shape] - every part of line is created by closed path and filled. Looks good and also have great performance.
enum SignatureDrawType {
  line,
  arc,
  shape,
}

/// [CustomPainter] of [CubicPath].
/// Used during signature painting.
class PathSignaturePainter extends CustomPainter {
  /// Paths to paint.
  final List<CubicPath> paths;

  final HandSignatureDrawer drawer;

  //TODO: remove this and move size changes to Widget side..
  /// Callback when canvas size is changed.
  final bool Function(Size size)? onSize;

  /// [Path] painter.
  const PathSignaturePainter({
    required this.paths,
    required this.drawer,
    this.onSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    //TODO: move to widget/state
    if (onSize != null) {
      if (onSize!.call(size)) {
        return;
      }
    }

    if (paths.isEmpty) {
      return;
    }

    drawer.paint(canvas, size, paths);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class DebugSignaturePainterCP extends CustomPainter {
  final HandSignatureControl control;
  final bool cp;
  final bool cpStart;
  final bool cpEnd;
  final bool dot;
  final Color color;

  const DebugSignaturePainterCP({
    required this.control,
    this.cp = false,
    this.cpStart = true,
    this.cpEnd = true,
    this.dot = true,
    this.color = Colors.red,
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
      } else if (cp) {
        canvas.drawCircle(line.cpStart, 1.0, paint);
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
