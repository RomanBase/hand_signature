import 'package:flutter/material.dart';

import '../signature.dart';

/// Defines the different types of drawing styles for a signature path.
enum SignatureDrawType {
  /// Draws the signature as a simple line with a constant stroke width.
  /// This is the most basic and performant drawing style.
  line,

  /// Draws the signature as a series of small arcs.
  /// This style can produce a visually appealing result but might have
  /// a higher performance cost due to the large number of individual arcs drawn.
  arc,

  /// Draws the signature by creating a closed shape for each segment of the line and filling it.
  /// This method generally provides a good balance between visual quality and performance,
  /// resulting in a smooth, filled signature appearance.
  shape,
}

/// A [CustomPainter] responsible for rendering [CubicPath]s onto a canvas.
/// This painter is used internally by the signature drawing widgets.
class PathSignaturePainter extends CustomPainter {
  /// The list of [CubicPath]s that need to be painted.
  final List<CubicPath> paths;

  /// The [HandSignatureDrawer] instance that defines the actual drawing logic.
  final HandSignatureDrawer drawer;

  /// Optional callback that is invoked when the canvas size changes.
  ///
  /// TODO: This callback should ideally be handled within the widget's state
  /// or by the [HandSignatureControl] itself.
  final bool Function(Size size)? onSize;

  /// Creates a [PathSignaturePainter].
  ///
  /// [paths] The list of signature paths to draw.
  /// [drawer] The drawer that will perform the actual painting.
  /// [onSize] An optional callback for canvas size changes.
  const PathSignaturePainter({
    required this.paths,
    required this.drawer,
    this.onSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: This size handling logic should be moved to the widget/state.
    if (onSize != null) {
      if (onSize!.call(size)) {
        return;
      }
    }

    // If there are no paths, nothing to draw.
    if (paths.isEmpty) {
      return;
    }

    // Delegate the actual painting to the provided drawer.
    drawer.paint(canvas, size, paths);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // Always repaint to ensure the latest signature is displayed.
    // A more optimized approach might compare old and new paths.
    return true;
  }
}

/// A [CustomPainter] used for debugging purposes, specifically to visualize
/// the control points and segments of a signature path.
class DebugSignaturePainterCP extends CustomPainter {
  /// The [HandSignatureControl] instance providing the signature data.
  final HandSignatureControl control;

  /// Whether to draw all control points.
  final bool cp;

  /// Whether to draw control points related to the start of segments.
  final bool cpStart;

  /// Whether to draw control points related to the end of segments.
  final bool cpEnd;

  /// Whether to draw dots at the control points and segment ends.
  final bool dot;

  /// The color used for drawing the debug elements.
  final Color color;

  /// Creates a [DebugSignaturePainterCP].
  ///
  /// [control] The signature control providing the data to debug.
  /// [cp] Whether to draw all control points.
  /// [cpStart] Whether to draw control points at the start of segments.
  /// [cpEnd] Whether to draw control points at the end of segments.
  /// [dot] Whether to draw dots at the control points and segment ends.
  /// [color] The color for the debug drawings.
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

    // Iterate through each line segment in the control's paths.
    control.lines.forEach((line) {
      // Draw lines and dots for start control points if enabled.
      if (cpStart) {
        canvas.drawLine(line.start, line.cpStart, paint);
        if (dot) {
          canvas.drawCircle(line.cpStart, 1.0, paint);
          canvas.drawCircle(line.start, 1.0, paint);
        }
      } else if (cp) {
        // Draw only the control point dot if cpStart is false but cp is true.
        canvas.drawCircle(line.cpStart, 1.0, paint);
      }

      // Draw lines and dots for end control points if enabled.
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
    // Always repaint to show the latest debug information.
    return true;
  }
}
