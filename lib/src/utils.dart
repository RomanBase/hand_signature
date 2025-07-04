import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../signature.dart';

/// A constant representing 2 * PI (360 degrees in radians).
const pi2 = math.pi * 2.0;

/// Extension methods for [Color] to provide utility functions.
extension ColorEx on Color {
  /// Returns the hexadecimal string representation of this color,
  /// excluding the alpha component (e.g., '#RRGGBB').
  String get hexValue =>
      '#${toARGB32().toRadixString(16)}'.replaceRange(1, 3, '');
}

/// Extension methods for [Offset] to provide vector and geometric utility functions.
extension OffsetEx on Offset {
  /// Calculates the component-wise distance (difference) between this offset and [other].
  /// Returns an [Offset] representing (other.dx - this.dx, other.dy - this.dy).
  Offset axisDistanceTo(Offset other) => other - this;

  /// Calculates the Euclidean distance between this offset and [other].
  double distanceTo(Offset other) {
    final len = axisDistanceTo(other);
    return math.sqrt(len.dx * len.dx + len.dy * len.dy);
  }

  /// Calculates the angle (in radians) from this offset to [other] relative to the positive x-axis.
  double angleTo(Offset other) {
    final len = axisDistanceTo(other);
    return math.atan2(len.dy, len.dx);
  }

  /// Calculates the unit vector (direction) from this offset to [other].
  /// Returns an [Offset] representing the normalized direction.
  /// If the distance is zero, returns an [Offset] of (0,0).
  Offset directionTo(Offset other) {
    final len = axisDistanceTo(other);
    final m = math.sqrt(len.dx * len.dx + len.dy * len.dy);
    return Offset(m == 0 ? 0 : (len.dx / m), m == 0 ? 0 : (len.dy / m));
  }

  /// Rotates this offset by [radians] around the origin (0,0).
  /// Returns a new [Offset] representing the rotated point.
  Offset rotate(double radians) {
    final s = math.sin(radians);
    final c = math.cos(radians);
    final x = dx * c - dy * s;
    final y = dx * s + dy * c;
    return Offset(x, y);
  }

  /// Rotates this offset by [radians] around a specified [center] point.
  /// Returns a new [Offset] representing the rotated point.
  Offset rotateAround(Offset center, double radians) {
    return (this - center).rotate(radians) + center;
  }
}

/// Extension methods for [Path] to provide simplified drawing commands.
extension PathEx on Path {
  /// Moves the current point of the path to the given [offset].
  void start(Offset offset) => moveTo(offset.dx, offset.dy);

  /// Adds a cubic Bezier curve segment to the path.
  ///
  /// [cpStart] The first control point.
  /// [cpEnd] The second control point.
  /// [end] The end point of the curve.
  void cubic(Offset cpStart, Offset cpEnd, Offset end) =>
      cubicTo(cpStart.dx, cpStart.dy, cpEnd.dx, cpEnd.dy, end.dx, end.dy);

  /// Adds a straight line segment from the current point to the given [offset].
  void line(Offset offset) => lineTo(offset.dx, offset.dy);
}

/// Extension methods for [Size] to provide utility functions.
extension SizeExt on Size {
  /// Scales this size down to fit within [other] size while maintaining aspect ratio.
  /// Returns a new [Size] that fits within [other].
  Size scaleToFit(Size other) {
    final scale = math.min(
      other.width / width,
      other.height / height,
    );

    return this * scale;
  }
}

/// A utility class providing static methods for common path manipulation and geometric calculations.
/// This includes bounding box calculations, transformations (translate, scale, normalize),
/// and conversions between different path representations.
///
/// TODO: Consider refactoring and cleaning up this class for better organization and clarity.
class PathUtil {
  /// Private constructor to prevent direct instantiation of this utility class.
  const PathUtil._();

  /// Calculates the bounding box (minimum [Rect]) for a list of [Offset] points.
  ///
  /// [data] The list of [Offset] points.
  /// [minSize] The minimum width/height for the bounding box. If the calculated
  ///   size is smaller, it will be expanded to this minimum.
  /// [radius] An additional padding to add around the calculated bounds.
  /// Returns a [Rect] representing the bounding box.
  /// Calculates the bounding box (minimum [Rect]) for a list of [Offset] points.
  ///
  /// [data] The list of [Offset] points.
  /// [minSize] The minimum width/height for the bounding box. If the calculated
  ///   size is smaller, it will be expanded to this minimum.
  /// [radius] An additional padding to add around the calculated bounds.
  /// Returns a [Rect] representing the bounding box.
  static Rect bounds(List<Offset> data,
      {double minSize = 2.0, double radius = 0.0}) {
    double left = data[0].dx;
    double top = data[0].dy;
    double right = data[0].dx;
    double bottom = data[0].dy;

    for (final point in data) {
      final x = point.dx;
      final y = point.dy;

      if (x < left) {
        left = x;
      } else if (x > right) {
        right = x;
      }

      if (y < top) {
        top = y;
      } else if (y > bottom) {
        bottom = y;
      }
    }

    final hSize = right - left;
    final vSize = bottom - top;

    if (hSize < minSize) {
      final dif = (minSize - hSize) * 0.5;
      left -= dif;
      right += dif;
    }

    if (vSize < minSize) {
      final dif = (minSize - vSize) * 0.5;
      top -= dif;
      bottom += dif;
    }

    return Rect.fromLTRB(
        left - radius, top - radius, right + radius, bottom + radius);
  }

  /// Calculates the bounding box (minimum [Rect]) for a list of lists of [Offset] points.
  /// This is useful for finding the overall bounds of multiple paths.
  ///
  /// [data] The list of lists of [Offset] points.
  /// [minSize] The minimum width/height for the bounding box.
  /// [radius] An additional padding to add around the calculated bounds.
  /// Returns a [Rect] representing the combined bounding box.
  /// Calculates the bounding box (minimum [Rect]) for a list of lists of [Offset] points.
  /// This is useful for finding the overall bounds of multiple paths.
  ///
  /// [data] The list of lists of [Offset] points.
  /// [minSize] The minimum width/height for the bounding box.
  /// [radius] An additional padding to add around the calculated bounds.
  /// Returns a [Rect] representing the combined bounding box.
  static Rect boundsOf(List<List<Offset>> data,
      {double minSize = 2.0, double radius = 0.0}) {
    double left = data[0][0].dx;
    double top = data[0][0].dy;
    double right = data[0][0].dx;
    double bottom = data[0][0].dy;

    for (final set in data) {
      for (final point in set) {
        final x = point.dx;
        final y = point.dy;

        if (x < left) {
          left = x;
        } else if (x > right) {
          right = x;
        }

        if (y < top) {
          top = y;
        } else if (y > bottom) {
          bottom = y;
        }
      }
    }

    final hSize = right - left;
    final vSize = bottom - top;

    if (hSize < minSize) {
      final dif = (minSize - hSize) * 0.5;
      left -= dif;
      right += dif;
    }

    if (vSize < minSize) {
      final dif = (minSize - vSize) * 0.5;
      top -= dif;
      bottom += dif;
    }

    return Rect.fromLTRB(
        left - radius, top - radius, right + radius, bottom + radius);
  }

  /// Translates a list of [Offset] points by a given [location] offset.
  ///
  /// [data] The list of points to translate.
  /// [location] The offset by which to translate the points.
  /// Returns a new list of translated points.
  /// Translates a list of [Offset] points by a given [location] offset.
  ///
  /// [data] The list of points to translate.
  /// [location] The offset by which to translate the points.
  /// Returns a new list of translated points.
  static List<T> translate<T extends Offset>(List<T> data, Offset location) {
    final output = <T>[];
    for (final point in data) {
      output.add(point.translate(location.dx, location.dy) as T);
    }
    return output;
  }

  /// Translates a list of lists of [Offset] points by a given [location] offset.
  ///
  /// [data] The list of lists of points to translate.
  /// [location] The offset by which to translate the points.
  /// Returns a new list of lists of translated points.
  /// Translates a list of lists of [Offset] points by a given [location] offset.
  ///
  /// [data] The list of lists of points to translate.
  /// [location] The offset by which to translate the points.
  /// Returns a new list of lists of translated points.
  static List<List<T>> translateData<T extends Offset>(
      List<List<T>> data, Offset location) {
    final output = <List<T>>[];
    for (final set in data) {
      output.add(translate(set, location));
    }
    return output;
  }

  /// Scales a list of [Offset] points by a given [ratio].
  ///
  /// [data] The list of points to scale.
  /// [ratio] The scaling factor.
  /// Returns a new list of scaled points.
  /// Scales a list of [Offset] points by a given [ratio].
  ///
  /// [data] The list of points to scale.
  /// [ratio] The scaling factor.
  /// Returns a new list of scaled points.
  static List<T> scale<T extends Offset>(List<T> data, double ratio) {
    final output = <T>[];
    for (final point in data) {
      output.add(point.scale(ratio, ratio) as T);
    }
    return output;
  }

  /// Scales a list of lists of [Offset] points by a given [ratio].
  ///
  /// [data] The list of lists of points to scale.
  /// [ratio] The scaling factor.
  /// Returns a new list of lists of scaled points.
  /// Scales a list of lists of [Offset] points by a given [ratio].
  ///
  /// [data] The list of lists of points to scale.
  /// [ratio] The scaling factor.
  /// Returns a new list of lists of scaled points.
  static List<List<T>> scaleData<T extends Offset>(
      List<List<T>> data, double ratio) {
    final output = <List<T>>[];
    for (final set in data) {
      output.add(scale(set, ratio));
    }
    return output;
  }

  /// Normalizes a list of [Offset] points to a unit square (0-1 range)
  /// based on their bounding box.
  ///
  /// [data] The list of points to normalize.
  /// [bound] Optional pre-calculated bounding box. If null, it will be calculated.
  /// Returns a new list of normalized points.
  /// Normalizes a list of [Offset] points to a unit square (0-1 range)
  /// based on their bounding box.
  ///
  /// [data] The list of points to normalize.
  /// [bound] Optional pre-calculated bounding box. If null, it will be calculated.
  /// Returns a new list of normalized points.
  static List<T> normalize<T extends Offset>(List<T> data, {Rect? bound}) {
    bound ??= bounds(data);
    return scale<T>(
      translate<T>(data, -bound.topLeft),
      1.0 / math.max(bound.width, bound.height),
    );
  }

  /// Normalizes a list of lists of [Offset] points to a unit square (0-1 range)
  /// based on their combined bounding box.
  ///
  /// [data] The list of lists of points to normalize.
  /// [bound] Optional pre-calculated combined bounding box. If null, it will be calculated.
  /// Returns a new list of lists of normalized points.
  /// Normalizes a list of lists of [Offset] points to a unit square (0-1 range)
  /// based on their combined bounding box.
  ///
  /// [data] The list of lists of points to normalize.
  /// [bound] Optional pre-calculated combined bounding box. If null, it will be calculated.
  /// Returns a new list of lists of normalized points.
  static List<List<T>> normalizeData<T extends Offset>(List<List<T>> data,
      {Rect? bound}) {
    bound ??= boundsOf(data);
    final ratio = 1.0 / math.max(bound.width, bound.height);
    return scaleData<T>(
      translateData<T>(data, -bound.topLeft),
      ratio,
    );
  }

  /// Fills a given [rect] with the scaled and translated [data] points,
  /// ensuring they fit within the rectangle with an optional [border].
  ///
  /// [data] The list of points to fill.
  /// [rect] The target rectangle to fill.
  /// [radius] An additional radius to consider for bounding box calculation.
  /// [bound] Optional pre-calculated bounding box for the data.
  /// [border] The border size to apply around the filled content.
  /// Returns a new list of transformed points.
  /// Fills a given [rect] with the scaled and translated [data] points,
  /// ensuring they fit within the rectangle with an optional [border].
  ///
  /// [data] The list of points to fill.
  /// [rect] The target rectangle to fill.
  /// [radius] An additional radius to consider for bounding box calculation.
  /// [bound] Optional pre-calculated bounding box for the data.
  /// [border] The border size to apply around the filled content.
  /// Returns a new list of transformed points.
  static List<T> fill<T extends Offset>(List<T> data, Rect rect,
      {double radius = 0.0, Rect? bound, double border = 32.0}) {
    bound ??= bounds(data, radius: radius);
    border *= 2.0;

    final outputSize = Size(rect.width - border, rect.height - border);
    final sourceSize = Size(bound.width, bound.height);
    Size destinationSize;

    final wr = outputSize.width / sourceSize.width;
    final hr = outputSize.height / sourceSize.height;

    if (wr < hr) {
      //scale by width
      destinationSize = Size(outputSize.width, sourceSize.height * wr);
    } else {
      //scale by height
      destinationSize = Size(sourceSize.width * hr, outputSize.height);
    }

    final borderSize = Offset(outputSize.width - destinationSize.width + border,
            outputSize.height - destinationSize.height + border) *
        0.5;

    return translate<T>(
      scale<T>(
        normalize<T>(data, bound: bound),
        math.max(destinationSize.width, destinationSize.height),
      ),
      borderSize,
    );
  }

  /// Fills a given [rect] with the scaled and translated list of lists of [data] points,
  /// ensuring they fit within the rectangle with an optional [border].
  ///
  /// [data] The list of lists of points to fill.
  /// [rect] The target rectangle to fill.
  /// [bound] Optional pre-calculated combined bounding box for the data.
  /// [border] The border size to apply around the filled content.
  /// Returns a new list of lists of transformed points.
  /// Fills a given [rect] with the scaled and translated list of lists of [data] points,
  /// ensuring they fit within the rectangle with an optional [border].
  ///
  /// [data] The list of lists of points to fill.
  /// [rect] The target rectangle to fill.
  /// [bound] Optional pre-calculated combined bounding box for the data.
  /// [border] The border size to apply around the filled content.
  /// Returns a new list of lists of transformed points.
  static List<List<T>> fillData<T extends Offset>(List<List<T>> data, Rect rect,
      {Rect? bound, double? border}) {
    bound ??= boundsOf(data);
    border ??= 4.0;

    final outputSize = rect.size;
    final sourceSize = bound;
    Size destinationSize;

    if (outputSize.width / outputSize.height >
        sourceSize.width / sourceSize.height) {
      destinationSize = Size(
          sourceSize.width * outputSize.height / sourceSize.height,
          outputSize.height);
    } else {
      destinationSize = Size(outputSize.width,
          sourceSize.height * outputSize.width / sourceSize.width);
    }

    destinationSize = Size(destinationSize.width - border * 2.0,
        destinationSize.height - border * 2.0);
    final borderSize = Offset(rect.width - destinationSize.width,
            rect.height - destinationSize.height) *
        0.5;

    return translateData<T>(
        scaleData<T>(
          normalizeData<T>(data, bound: bound),
          math.max(destinationSize.width, destinationSize.height),
        ),
        borderSize);
  }

  /// Converts a list of [Offset] points into a [Path] object by connecting them with lines.
  ///
  /// [points] The list of points to convert.
  /// Returns a [Path] representing the connected points.
  /// Converts a list of [Offset] points into a [Path] object by connecting them with lines.
  ///
  /// [points] The list of points to convert.
  /// Returns a [Path] representing the connected points.
  static Path toPath(List<Offset> points) {
    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (final point in points) {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  /// Converts a list of lists of [Offset] points into a list of [Path] objects.
  ///
  /// [data] The list of lists of points to convert.
  /// Returns a list of [Path] objects.
  /// Converts a list of lists of [Offset] points into a list of [Path] objects.
  ///
  /// [data] The list of lists of points to convert.
  /// Returns a list of [Path] objects.
  static List<Path> toPaths(List<List<Offset>> data) {
    final paths = <Path>[];
    for (final line in data) {
      paths.add(toPath(line));
    }
    return paths;
  }

  /// Calculates the combined bounding box for a list of [Path] objects.
  ///
  /// [data] The list of [Path] objects.
  /// Returns a [Rect] representing the combined bounding box.
  /// Calculates the combined bounding box for a list of [Path] objects.
  ///
  /// [data] The list of [Path] objects.
  /// Returns a [Rect] representing the combined bounding box.
  static Rect pathBounds(List<Path> data) {
    Rect init = data[0].getBounds();

    double left = init.left;
    double top = init.top;
    double right = init.right;
    double bottom = init.bottom;

    for (final path in data) {
      final bound = path.getBounds();

      left = math.min(left, bound.left);
      top = math.min(top, bound.top);
      right = math.max(right, bound.right);
      bottom = math.max(bottom, bound.bottom);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Scales a single [Path] object by a given [ratio].
  ///
  /// [data] The [Path] to scale.
  /// [ratio] The scaling factor.
  /// Returns a new, scaled [Path].
  static Path scalePath(Path data, double ratio) {
    final transform = Matrix4.identity();
    transform.scale(ratio, ratio);
    return data.transform(transform.storage);
  }

  /// Scales a list of [Path] objects by a given [ratio].
  ///
  /// [data] The list of [Path]s to scale.
  /// [ratio] The scaling factor.
  /// Returns a new list of scaled [Path]s.
  /// Scales a list of [Path] objects by a given [ratio].
  ///
  /// [data] The list of [Path]s to scale.
  /// [ratio] The scaling factor.
  /// Returns a new list of scaled [Path]s.
  static List<Path> scalePaths(List<Path> data, double ratio) {
    final output = <Path>[];
    for (final path in data) {
      output.add(scalePath(path, ratio));
    }
    return output;
  }

  /// Translates a list of [Path] objects by a given [location] offset.
  ///
  /// [data] The list of [Path]s to translate.
  /// [location] The offset by which to translate the paths.
  /// Returns a new list of translated [Path]s.
  /// Translates a list of [Path] objects by a given [location] offset.
  ///
  /// [data] The list of [Path]s to translate.
  /// [location] The offset by which to translate the paths.
  /// Returns a new list of translated [Path]s.
  static List<Path> translatePaths(List<Path> data, Offset location) {
    final output = <Path>[];
    final transform = Matrix4.identity();
    transform.translate(location.dx, location.dy);
    for (final path in data) {
      output.add(path.transform(transform.storage));
    }
    return output;
  }

  /// Converts a list of [CubicLine] segments into a closed [Path] representing a filled shape.
  /// This is typically used for drawing thick, filled signature lines.
  ///
  /// [lines] The list of [CubicLine] segments.
  /// [size] The base stroke width for the shape.
  /// [maxSize] The maximum stroke width for the shape.
  /// Returns a closed [Path] representing the filled shape.
  static Path toShapePath(List<CubicLine> lines, double size, double maxSize) {
    assert(lines.isNotEmpty);

    if (lines.length == 1) {
      final line = lines[0];
      if (line.isDot) {
        // TODO: Consider returning null or creating a circle path directly for dots.
        return Path()
          ..start(line.start)
          ..line(line.end);
      }
      return line.toShape(size, maxSize);
    }

    final path = Path();

    final firstLine = lines.first;
    path.start(firstLine.start + firstLine.cpsUp(size, maxSize));

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final d1 = line.cpsUp(size, maxSize);
      final d2 = line.cpeUp(size, maxSize);

      path.cubic(line.cpStart + d1, line.cpEnd + d2, line.end + d2);
    }

    final lastLine = lines.last;
    path.line(lastLine.end + lastLine.cpeDown(size, maxSize));

    for (int i = lines.length - 1; i > -1; i--) {
      final line = lines[i];
      final d3 = line.cpeDown(size, maxSize);
      final d4 = line.cpsDown(size, maxSize);

      path.cubic(line.cpEnd + d3, line.cpStart + d4, line.start + d4);
    }

    path.close();

    return path;
  }

  /// Converts a list of [CubicLine] segments into a simple [Path] object,
  /// connecting them with cubic Bezier curves.
  ///
  /// [lines] The list of [CubicLine] segments.
  /// Returns a [Path] representing the connected lines.
  /// Converts a list of [CubicLine] segments into a simple [Path] object,
  /// connecting them with cubic Bezier curves.
  ///
  /// [lines] The list of [CubicLine] segments.
  /// Returns a [Path] representing the connected lines.
  /// Converts a list of [CubicLine] segments into a simple [Path] object,
  /// connecting them with cubic Bezier curves.
  ///
  /// [lines] The list of [CubicLine] segments.
  /// Returns a [Path] representing the connected lines.
  static Path toLinePath(List<CubicLine> lines) {
    assert(lines.isNotEmpty);

    final path = Path()..start(lines[0]);
    for (final line in lines) {
      path.cubic(line.cpStart, line.cpEnd, line.end);
    }
    return path;
  }
}
