import 'package:flutter/material.dart';

import '../signature.dart';
import 'utils.dart';

/// An abstract base class for custom signature drawing logic.
///
/// Subclasses must implement the [paint] method to define how a signature path is rendered on a canvas.
abstract class HandSignatureDrawer {
  /// Creates a [HandSignatureDrawer] instance.
  const HandSignatureDrawer();

  /// Paints the given [paths] onto the [canvas].
  ///
  /// [canvas] The canvas to draw on.
  /// [size] The size of the canvas.
  /// [paths] A list of [CubicPath] objects representing the signature to be drawn.
  void paint(Canvas canvas, Size size, List<CubicPath> paths);
}

/// A concrete implementation of [HandSignatureDrawer] that draws signature as simple lines.
class LineSignatureDrawer extends HandSignatureDrawer {
  /// The color used to paint the lines.
  final Color color;

  /// The stroke width of the lines.
  final double width;

  /// Creates a [LineSignatureDrawer] with the specified [width] and [color].
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

/// A concrete implementation of [HandSignatureDrawer] that draws signatures as arcs,
/// with varying width based on the arc's size property.
class ArcSignatureDrawer extends HandSignatureDrawer {
  /// The color used to paint the arcs.
  final Color color;

  /// The minimal stroke width of the arcs.
  final double width;

  /// The maximal stroke width of the arcs.
  final double maxWidth;

  /// Creates an [ArcSignatureDrawer] with the specified [width], [maxWidth], and [color].
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
      final arcs = path.toArcs();
      for (final arc in arcs) {
        paint.strokeWidth = width + (maxWidth - width) * arc.size;
        canvas.drawPath(arc.path, paint);
      }
    }
  }
}

/// A concrete implementation of [HandSignatureDrawer] that draws signature as filled Path.
class ShapeSignatureDrawer extends HandSignatureDrawer {
  /// The color used to fill the shapes.
  final Color color;

  /// The base width of the shape.
  final double width;

  /// The maximum width of the shape.
  final double maxWidth;

  /// Creates a [ShapeSignatureDrawer] with the specified [width], [maxWidth], and [color].
  const ShapeSignatureDrawer({
    this.width = 1.0,
    this.maxWidth = 10.0,
    this.color = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.0; // Stroke width is handled by the shape path itself

    for (final path in paths) {
      if (path.isFilled) {
        if (path.isDot) {
          // If it's a dot, draw a circle
          canvas.drawCircle(path.lines[0], path.lines[0].startRadius(width, maxWidth), paint);
        } else {
          // Otherwise, draw the filled shape path
          canvas.drawPath(PathUtil.toShapePath(path.lines, width, maxWidth), paint);

          // Draw circles at the start and end of the path for a smoother look
          final first = path.lines.first;
          final last = path.lines.last;

          canvas.drawCircle(first.start, first.startRadius(width, maxWidth), paint);
          canvas.drawCircle(last.end, last.endRadius(width, maxWidth), paint);
        }
      }
    }
  }
}

/// A [HandSignatureDrawer] that dynamically selects the drawing type based on
/// arguments provided in the [CubicPath]'s setup.
class DynamicSignatureDrawer extends HandSignatureDrawer {
  final SignatureDrawType type;

  /// The color used to paint the arcs.
  final Color color;

  /// The minimal stroke width of the arcs.
  final double width;

  /// The maximal stroke width of the arcs.
  final double maxWidth;

  const DynamicSignatureDrawer({
    this.type = SignatureDrawType.shape,
    this.width = 1.0,
    this.maxWidth = 10.0,
    this.color = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    for (final path in paths) {
      // Retrieve drawing parameters from path arguments, with fallbacks
      final type = path.setup.args?['type'] ?? this.type.name;
      final color = Color(path.setup.args?['color'] ?? this.color.toHex32());
      final width = path.setup.args?['width'] ?? this.width;
      final maxWidth = path.setup.args?['max_width'] ?? this.maxWidth;

      HandSignatureDrawer drawer;

      // Select the appropriate drawer based on the 'type' argument
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
          // Default to ShapeSignatureDrawer if type is unknown or not provided
          drawer = ShapeSignatureDrawer(color: color, width: width, maxWidth: maxWidth);
      }

      // Paint the current path using the selected drawer
      drawer.paint(canvas, size, [path]);
    }
  }
}

/// A [HandSignatureDrawer] that combines multiple drawers, allowing for complex
/// drawing effects by applying each drawer in sequence.
class MultiSignatureDrawer extends HandSignatureDrawer {
  /// The collection of [HandSignatureDrawer]s to be applied.
  final Iterable<HandSignatureDrawer> drawers;

  /// Creates a [MultiSignatureDrawer] with the given [drawers].
  const MultiSignatureDrawer({required this.drawers});

  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    for (final drawer in drawers) {
      drawer.paint(canvas, size, paths);
    }
  }
}
