import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../signature.dart';
import 'utils.dart';

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

  /// Single color of paint.
  final Color color;

  /// Minimal size of path.
  final double width;

  /// Maximal size of path.
  final double maxWidth;

  //TODO: remove this and move size changes to Widget side..
  /// Callback when canvas size is changed.
  final bool Function(Size size)? onSize;

  /// Type of signature path.
  final SignatureDrawType type;

  /// Returns [PaintingStyle.stroke] based paint.
  Paint get strokePaint => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = width;

  /// Returns [PaintingStyle.fill] based paint.
  Paint get fillPaint => Paint()
    ..color = color
    ..strokeWidth = 0.0;

  /// [Path] painter.
  PathSignaturePainter({
    required this.paths,
    this.color: Colors.black,
    this.width: 1.0,
    this.maxWidth: 10.0,
    this.onSize,
    this.type: SignatureDrawType.shape,
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

    switch (type) {
      case SignatureDrawType.line:
        final paint = strokePaint;

        paths.forEach((path) {
          if (path.isFilled) {
            canvas.drawPath(PathUtil.toLinePath(path.lines), paint);
          }
        });
        break;
      case SignatureDrawType.arc:
        final paint = strokePaint;

        paths.forEach((path) {
          path.arcs.forEach((arc) {
            paint.strokeWidth = width + (maxWidth - width) * arc.size;
            canvas.drawPath(arc.path, paint);
          });
        });
        break;
      case SignatureDrawType.shape:
        final paint = fillPaint;

        paths.forEach((path) {
          if (path.isFilled) {
            if (path.isDot) {
              canvas.drawCircle(path.lines[0],
                  path.lines[0].startRadius(width, maxWidth), paint);
            } else {
              canvas.drawPath(
                  PathUtil.toShapePath(path.lines, width, maxWidth), paint);

              final first = path.lines.first;
              final last = path.lines.last;

              canvas.drawCircle(
                  first.start, first.startRadius(width, maxWidth), paint);
              canvas.drawCircle(
                  last.end, last.endRadius(width, maxWidth), paint);
            }
          }
        });

        break;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

/// [CustomPainter] of [Drawable].
/// Used on parsed svg data.
class DrawableSignaturePainter extends CustomPainter {
  /// Root [Drawable].
  final DrawableParent drawable;

  /// Path color. Overrides color of [Drawable].
  final Color? color;

  /// Path size modifier.
  final double Function(double width)? strokeWidth;

  /// [Drawable] painter.
  DrawableSignaturePainter({
    required this.drawable,
    this.color,
    this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _draw(
      drawable,
      canvas,
      Paint()
        ..color = color ?? Colors.black
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Recursive function to draw all shapes as [Path].
  void _draw(DrawableParent root, Canvas canvas, Paint paint) {
    if (root.children != null) {
      root.children!.forEach((drawable) {
        if (drawable is DrawableShape) {
          final stroke = drawable.style.stroke;
          final fill = drawable.style.fill;

          if (fill != null && !DrawablePaint.isEmpty(fill)) {
            paint.style = PaintingStyle.fill;
            if (color == null && fill.color != null) {
              paint.color = fill.color!;
            }
          } else if (stroke != null && !DrawablePaint.isEmpty(stroke)) {
            paint.style = PaintingStyle.stroke;

            if (color == null && stroke.color != null) {
              paint.color = stroke.color!;
            }

            if (stroke.strokeWidth != null) {
              if (strokeWidth != null) {
                paint.strokeWidth = strokeWidth!.call(stroke.strokeWidth!);
              } else {
                paint.strokeWidth = stroke.strokeWidth!;
              }
            }
          }

          canvas.drawPath(drawable.path, paint);
        } else if (drawable is DrawableParent) {
          _draw(drawable, canvas, paint);
        }
      });
    }
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

  DebugSignaturePainterCP({
    required this.control,
    this.cp: false,
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
