import 'package:flutter/material.dart';

import '../signature.dart';
import 'utils.dart';

abstract class HandSignatureDrawer {
  const HandSignatureDrawer();

  void paint(Canvas canvas, Size size, List<CubicPath> paths);
}

class LineSignatureDrawer extends HandSignatureDrawer {
  final Color color;
  final double width;

  const LineSignatureDrawer({
    this.width = 1.0,
    this.color = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width;

    for (final path in paths) {
      if (path.isFilled) {
        canvas.drawPath(PathUtil.toLinePath(path.lines), paint);
      }
    }
  }
}

class ArcSignatureDrawer extends HandSignatureDrawer {
  final Color color;
  final double width;
  final double maxWidth;

  const ArcSignatureDrawer({
    this.width = 1.0,
    this.maxWidth = 10.0,
    this.color = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width;

    for (final path in paths) {
      path.arcs.forEach((arc) {
        paint.strokeWidth = width + (maxWidth - width) * arc.size;
        canvas.drawPath(arc.path, paint);
      });
    }
  }
}

class ShapeSignatureDrawer extends HandSignatureDrawer {
  final Color color;
  final double width;
  final double maxWidth;

  const ShapeSignatureDrawer({
    this.width = 1.0,
    this.maxWidth = 10.0,
    this.color = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.0;

    for (final path in paths) {
      if (path.isFilled) {
        if (path.isDot) {
          canvas.drawCircle(path.lines[0], path.lines[0].startRadius(width, maxWidth), paint);
        } else {
          canvas.drawPath(PathUtil.toShapePath(path.lines, width, maxWidth), paint);

          final first = path.lines.first;
          final last = path.lines.last;

          canvas.drawCircle(first.start, first.startRadius(width, maxWidth), paint);
          canvas.drawCircle(last.end, last.endRadius(width, maxWidth), paint);
        }
      }
    }
  }
}

class DynamicSignatureDrawer extends HandSignatureDrawer {
  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    for (final path in paths) {
      final type = path.setup.args?['type'] ?? SignatureDrawType.shape.name;
      final color = Color(path.setup.args?['color'] ?? 0xFF000000);
      final width = path.setup.args?['width'] ?? 2.0;
      final maxWidth = path.setup.args?['max_width'] ?? 10.0;

      HandSignatureDrawer drawer;

      switch (type) {
        case 'line':
          drawer = LineSignatureDrawer(color: color, width: width);
          break;
        case 'arc':
          drawer = ArcSignatureDrawer(color: color, width: width, maxWidth: maxWidth);
          break;
        case 'shape':
          drawer = ShapeSignatureDrawer(color: color, width: width, maxWidth: maxWidth);
          break;
        default:
          drawer = ShapeSignatureDrawer(color: color, width: width, maxWidth: maxWidth);
      }

      drawer.paint(canvas, size, [path]);
    }
  }
}

class MultiSignatureDrawer extends HandSignatureDrawer {
  final Iterable<HandSignatureDrawer> drawers;

  const MultiSignatureDrawer({required this.drawers});

  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    for (final drawer in drawers) {
      drawer.paint(canvas, size, paths);
    }
  }
}
