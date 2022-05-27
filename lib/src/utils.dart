import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../signature.dart';

extension ColorEx on Color {
  String get hexValue => '#${value.toRadixString(16)}'.replaceRange(1, 3, '');
}

extension OffsetEx on Offset {
  Offset axisDistanceTo(Offset other) => other - this;

  double distanceTo(Offset other) {
    final len = axisDistanceTo(other);

    return sqrt(len.dx * len.dx + len.dy * len.dy);
  }

  double angleTo(Offset other) {
    final len = axisDistanceTo(other);

    return atan2(len.dy, len.dx);
  }

  Offset directionTo(Offset other) {
    final len = axisDistanceTo(other);
    final m = sqrt(len.dx * len.dx + len.dy * len.dy);

    return Offset(m == 0 ? 0 : (len.dx / m), m == 0 ? 0 : (len.dy / m));
  }

  Offset rotate(double radians) {
    final s = sin(radians);
    final c = cos(radians);

    final x = dx * c - dy * s;
    final y = dx * s + dy * c;

    return Offset(x, y);
  }

  Offset rotateAround(Offset center, double radians) {
    return (this - center).rotate(radians) + center;
  }

  Map<String, dynamic> get toMap => {
        'dx': dx,
        'dy': dy,
      };
}

extension PathEx on Path {
  void start(Offset offset) => moveTo(offset.dx, offset.dy);

  void cubic(Offset cpStart, Offset cpEnd, Offset end) =>
      cubicTo(cpStart.dx, cpStart.dy, cpEnd.dx, cpEnd.dy, end.dx, end.dy);

  void line(Offset offset) => lineTo(offset.dx, offset.dy);
}

extension SizeExt on Size {
  Size scaleToFit(Size other) {
    final scale = min(
      other.width / this.width,
      other.height / this.height,
    );

    return this * scale;
  }
}

extension DoubleExt on double {
  double asFixed(int? fractionDigits) {
    if (fractionDigits == null) return this;

    final divident = pow(10, fractionDigits).toInt();

    return (this * divident).toInt() / divident;
  }
}

//TODO: clean up
class PathUtil {
  static Rect bounds(List<Offset> data) {
    double left = data[0].dx;
    double top = data[0].dy;
    double right = data[0].dx;
    double bottom = data[0].dy;

    data.forEach((point) {
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
    });

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Rect boundsOf(List<List<Offset>> data) {
    double left = data[0][0].dx;
    double top = data[0][0].dy;
    double right = data[0][0].dx;
    double bottom = data[0][0].dy;

    data.forEach((set) => set.forEach((point) {
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
        }));

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static List<T> translate<T extends Offset>(List<T> data, Offset location) {
    final output = <T>[];

    data.forEach(
        (point) => output.add(point.translate(location.dx, location.dy) as T));

    return output;
  }

  static List<List<T>> translateData<T extends Offset>(
      List<List<T>> data, Offset location) {
    final output = <List<T>>[];

    data.forEach((set) => output.add(translate(set, location)));

    return output;
  }

  static List<T> scale<T extends Offset>(List<T> data, double ratio) {
    final output = <T>[];

    data.forEach((point) => output.add(point.scale(ratio, ratio) as T));

    return output;
  }

  static List<List<T>> scaleData<T extends Offset>(
      List<List<T>> data, double ratio) {
    final output = <List<T>>[];

    data.forEach((set) => output.add(scale(set, ratio)));

    return output;
  }

  static List<T> normalize<T extends Offset>(List<T> data,
      {Rect? bound, double? border}) {
    bound ??= bounds(data);
    border ??= 0.0;

    return scale<T>(
      translate<T>(data, -bound.topLeft + Offset(border, border)),
      1.0 / (max(bound.width, bound.height) + border * 2.0),
    );
  }

  static List<List<T>> normalizeData<T extends Offset>(List<List<T>> data,
      {Rect? bound}) {
    bound ??= boundsOf(data);

    final ratio = 1.0 / max(bound.width, bound.height);

    return scaleData<T>(
      translateData<T>(data, -bound.topLeft),
      ratio,
    );
  }

  static List<T> fill<T extends Offset>(List<T> data, Rect rect,
      {Rect? bound, double? border}) {
    bound ??= bounds(data);
    border ??= 32.0;

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
            rect.height - destinationSize.height - border) *
        0.5;

    return translate<T>(
        scale<T>(
          normalize<T>(data, bound: bound),
          max(destinationSize.width, destinationSize.height),
        ),
        borderSize);
  }

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
          max(destinationSize.width, destinationSize.height),
        ),
        borderSize);
  }

  static Path toPath(List<Offset> points) {
    final path = Path();

    if (points.length > 0) {
      path.moveTo(points[0].dx, points[0].dy);
      points.forEach((point) => path.lineTo(point.dx, point.dy));
    }

    return path;
  }

  static List<Path> toPaths(List<List<Offset>> data) {
    final paths = <Path>[];

    data.forEach((line) => paths.add(toPath(line)));

    return paths;
  }

  static Rect pathBounds(List<Path> data) {
    Rect init = data[0].getBounds();

    double left = init.left;
    double top = init.top;
    double right = init.right;
    double bottom = init.bottom;

    data.forEach((path) {
      final bound = path.getBounds();

      left = min(left, bound.left);
      top = min(top, bound.top);
      right = max(right, bound.right);
      bottom = max(bottom, bound.bottom);
    });

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Path scalePath(Path data, double ratio) {
    final transform = Matrix4.identity();
    transform.scale(ratio, ratio);

    return data.transform(transform.storage);
  }

  static List<Path> scalePaths(List<Path> data, double ratio) {
    final output = <Path>[];

    data.forEach((path) => output.add(scalePath(path, ratio)));

    return output;
  }

  static List<Path> translatePaths(List<Path> data, Offset location) {
    final output = <Path>[];

    final transform = Matrix4.identity();
    transform.translate(location.dx, location.dy);

    data.forEach((path) => output.add(path.transform(transform.storage)));

    return output;
  }

  static List<Path> parseDrawable(DrawableParent root) {
    final list = <Path>[];

    _parseDrawableRoot(root, list);

    return PathUtil.translatePaths(list, -PathUtil.pathBounds(list).topLeft);
  }

  static _parseDrawableRoot(DrawableParent root, List<Path> output) {
    if (root.children != null) {
      root.children!.forEach((drawable) {
        if (drawable is DrawableShape) {
          output.add(drawable.path);
        } else if (drawable is DrawableParent) {
          _parseDrawableRoot(drawable, output);
        }
      });
    }
  }

  static Size getDrawableSize(DrawableRoot root) => root.viewport.size;

  static Path toShapePath(List<CubicLine> lines, double size, double maxSize) {
    assert(lines.length > 0);

    if (lines.length == 1) {
      final line = lines[0];
      if (line.isDot) {
        //TODO: return null or create circle ?
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

  static Path toLinePath(List<CubicLine> lines) {
    assert(lines.length > 0);

    final path = Path()..start(lines[0]);

    lines.forEach((line) => path.cubic(line.cpStart, line.cpEnd, line.end));

    return path;
  }

  static Offset offsetFromMap(Map<String, dynamic> map) => Offset(
        map['dx'],
        map['dy'],
      );
}
