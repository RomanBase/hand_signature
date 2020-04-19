import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hand_signature/signature_control.dart';

enum SignatureDrawType {
  line,
  arc,
  shape,
}

class PathSignaturePainter extends CustomPainter {
  final List<CubicPath> paths;
  final Color color;
  final double width;
  final double maxWidth;
  final bool Function(Size size) onSize;
  final SignatureDrawType type;

  Paint get strokePaint => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = width;

  Paint get fillPaint => Paint()
    ..color = color
    ..strokeWidth = 0.0;

  PathSignaturePainter({
    @required this.paths,
    this.color: Colors.black,
    this.width: 1.0,
    this.maxWidth: 10.0,
    this.onSize,
    this.type: SignatureDrawType.arc,
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

    switch (type) {
      case SignatureDrawType.line:
        final paint = strokePaint;

        paths.forEach((path) {
          path.lines.forEach((line) {
            canvas.drawPath(line.path, paint);
          });
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
          path.lines.forEach((line) {
            canvas.drawPath(line.shape(width, maxWidth), paint);
          });

          final first = path.lines.first;
          final last = path.lines.last;

          canvas.drawCircle(first.start, (width + (maxWidth - width) * first.startSize) * 0.5, paint);
          canvas.drawCircle(last.end, (width + (maxWidth - width) * last.endSize) * 0.5, paint);
        });

        break;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class DrawableSignaturePainter extends CustomPainter {
  final DrawableParent drawable;
  final Color color;
  final double Function(double width) strokeWidth;

  DrawableSignaturePainter({
    @required this.drawable,
    this.color,
    this.strokeWidth,
  }) : assert(drawable != null);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ?? drawable.style?.stroke?.color ?? Colors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = drawable.style?.stroke?.strokeWidth ?? 1.0;

    _draw(drawable, canvas, paint);
  }

  void _draw(DrawableParent root, Canvas canvas, Paint paint) {
    if (root.children != null) {
      root.children.forEach((drawable) {
        if (drawable is DrawableShape) {
          final style = drawable.style?.stroke;

          if (style != null) {
            if (style.color != null) {
              paint.color = style.color;
            }
            if (style.strokeWidth != null) {
              if (strokeWidth != null) {
                paint.strokeWidth = strokeWidth(style.strokeWidth);
              } else {
                paint.strokeWidth = style.strokeWidth;
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

class SignaturePainterCP extends CustomPainter {
  final HandSignatureControl control;
  final bool cp;
  final bool cpStart;
  final bool cpEnd;
  final bool dot;
  final Color color;

  SignaturePainterCP({
    @required this.control,
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
