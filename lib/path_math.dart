import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';

Rect bounds(List<Offset> data) {
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

Rect boundsOf(List<List<Offset>> data) {
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

List<Offset> translate(List<Offset> data, Offset location) {
  final output = List<Offset>();

  data.forEach((point) => output.add(point.translate(location.dx, location.dy)));

  return output;
}

List<List<Offset>> translateOf(List<List<Offset>> data, Offset location) {
  final output = List<List<Offset>>();

  data.forEach((set) => output.add(translate(set, location)));

  return output;
}

List<Offset> scale(List<Offset> data, double ratio) {
  final output = List<Offset>();

  data.forEach((point) => output.add(point.scale(ratio, ratio)));

  return output;
}

List<List<Offset>> scaleOf(List<List<Offset>> data, double ratio) {
  final output = List<List<Offset>>();

  data.forEach((set) => output.add(scale(set, ratio)));

  return output;
}

List<Offset> normalize(List<Offset> data, {Rect bound, double border}) {
  bound ??= bounds(data);
  border ??= 0.0;

  return scale(
    translate(data, -bound.topLeft + Offset(border, border)),
    1.0 / (max(bound.width, bound.height) + border * 2.0),
  );
}

List<List<Offset>> normalizeOf(List<List<Offset>> data, {Rect bound}) {
  bound ??= boundsOf(data);

  final ratio = 1.0 / max(bound.width, bound.height);
  final nSize = Size(bound.width * ratio, bound.height * ratio);

  return scaleOf(
    translateOf(data, -bound.topLeft),
    ratio,
  );
}

List<Offset> fill(List<Offset> data, Rect rect, {Rect bound, double border}) {
  bound ??= bounds(data);
  final srcRatio = bound.width / bound.height;
  final dstRatio = rect.width / rect.height;

  return scale(
    normalize(data, bound: bound, border: border),
    srcRatio >= dstRatio ? rect.width : rect.height,
  );
}

List<List<Offset>> fillOf(List<List<Offset>> data, Rect rect, {Rect bound, double border}) {
  bound ??= boundsOf(data);

  final outputSize = rect.size;
  final sourceSize = bound;
  Size destinationSize;

  if (outputSize.width / outputSize.height > sourceSize.width / sourceSize.height) {
    destinationSize = Size(sourceSize.width * outputSize.height / sourceSize.height, outputSize.height);
  } else {
    destinationSize = Size(outputSize.width, sourceSize.height * outputSize.width / sourceSize.width);
  }

  destinationSize = Size(destinationSize.width - border * 2.0, destinationSize.height - border * 2.0);
  final borderSize = Offset(rect.width - destinationSize.width, rect.height - destinationSize.height) * 0.5;

  return translateOf(
      scaleOf(
        normalizeOf(data, bound: bound),
        max(destinationSize.width, destinationSize.height),
      ),
      borderSize);
}


Path asPath(List<Offset> points) {
  final path = Path();

  if (points.length > 0) {
    path.moveTo(points[0].dx, points[0].dy);
    //points.forEach((point) => path.arcToPoint(point));
    points.forEach((point) => path.lineTo(point.dx, point.dy));
  }

  return path;
}

List<Path> asPathOf(List<List<Offset>> data) {
  final paths = List<Path>();

  data.forEach((line) => paths.add(asPath(line)));

  return paths;
}

Rect pathBoundsOf(List<Path> data) {
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

Path scalePath(Path data, double ratio) {
  final transform = Matrix4.identity();
  transform.scale(ratio, ratio);

  return data.transform(transform.storage);
}

List<Path> scalePathOf(List<Path> data, double ratio) {
  final output = List<Path>();

  data.forEach((path) => output.add(scalePath(path, ratio)));

  return output;
}

List<Path> translatePathOf(List<Path> data, Offset location) {
  final output = List<Path>();

  final transform = Matrix4.identity();
  transform.translate(location.dx, location.dy);

  data.forEach((path) => output.add(path.transform(transform.storage)));

  return output;
}
