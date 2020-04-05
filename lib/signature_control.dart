import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SignaturePaintParams {
  final Color color;
  final double width;

  String get hexColor => '#${color.value.toRadixString(16)}'.replaceRange(1, 3, '');

  String get opacity => '${color.opacity}}';

  const SignaturePaintParams(this.color, this.width);
}

class OffsetPoint {
  final Offset location;
  final int timestamp;

  double get x => location.dx;

  double get y => location.dy;

  OffsetPoint(
    this.location,
  ) : timestamp = DateTime.now().millisecondsSinceEpoch;

  double distanceTo(OffsetPoint other) => math.sqrt(math.pow(location.dx - other.location.dx, 2) + math.pow(location.dy - other.location.dy, 2));

  velocityFrom(OffsetPoint other) => timestamp != other.timestamp ? this.distanceTo(other) / (timestamp - other.timestamp) : 0;

  @override
  bool operator ==(other) {
    return other is OffsetPoint && other.location == location && other.timestamp == timestamp;
  }

  @override
  int get hashCode => hashValues(location, timestamp);
}

class SingleCubicLine {
  final Offset start;
  final Offset controlPoint1;
  final Offset controlPoint2;
  final Offset end;

  SingleCubicLine({
    this.start,
    this.controlPoint1,
    this.controlPoint2,
    this.end,
  });

  factory SingleCubicLine.from(OffsetPoint a, OffsetPoint c1, OffsetPoint c2, OffsetPoint b) {
    return SingleCubicLine(
      start: a.location,
      controlPoint1: calculateControlPoints(a, c1, c2)[1],
      controlPoint2: calculateControlPoints(c1, c2, b)[0],
      end: b.location,
    );
  }

  static List<Offset> calculateControlPoints(OffsetPoint s1, OffsetPoint s2, OffsetPoint s3) {
    final dx1 = s1.x - s2.x;
    final dy1 = s1.y - s2.y;
    final dx2 = s2.x - s3.x;
    final dy2 = s2.y - s3.y;

    final m1 = Offset((s1.x + s2.x) / 2.0, (s1.y + s2.y) / 2.0);
    final m2 = Offset((s2.x + s3.x) / 2.0, (s2.y + s3.y) / 2.0);

    final l1 = math.sqrt(dx1 * dx1 + dy1 * dy1);
    final l2 = math.sqrt(dx2 * dx2 + dy2 * dy2);

    final dxm = m1.dx - m2.dx;
    final dym = m1.dy - m2.dy;

    final k = l2 / (l1 + l2);
    final cm = Offset(m2.dx + dxm * k, m2.dy + dym * k);

    final tx = s2.x - cm.dx;
    final ty = s2.y - cm.dy;

    return [
      Offset(m1.dx + tx, m1.dy + ty),
      Offset(m2.dy + tx, m2.dy + ty),
    ];
  }
}

class CubicPath {
  final _raw = List<OffsetPoint>();

  Offset get _origin => _raw.isNotEmpty ? _raw[0].location : null;

  OffsetPoint get _lastPoint => _raw.isNotEmpty ? _raw[_raw.length - 1] : null;

  final threshold = 1.0;

  final _path = Path();

  Path getCurrentPath() => Path()..addPath(_path, Offset.zero);

  void begin(Offset point) {
    _raw.add(OffsetPoint(point));
    _path.moveTo(point.dx, point.dy);
  }

  SingleCubicLine add(Offset point) {
    assert(_origin != null);

    final nextPoint = OffsetPoint(point);

    if (_lastPoint.distanceTo(nextPoint) < threshold) {
      return null;
    }

    _raw.add(nextPoint);

    final length = _raw.length;
    if (length > 3) {
      final curve = SingleCubicLine.from(
        _raw[length - 4],
        _raw[length - 3],
        _raw[length - 2],
        _raw[length - 1],
      );

      if (length % 4 == 0) {
        _path.cubicTo(
          curve.controlPoint1.dx,
          curve.controlPoint1.dy,
          curve.controlPoint2.dx,
          curve.controlPoint2.dy,
          curve.end.dx,
          curve.end.dy,
        );

        return null;
      }

      return curve;
    }

    return null;
  }

  void end({Offset point}) {}
}

class HandSignatureControl extends ChangeNotifier {
  final _pathData = List<Path>();
  final _rawData = List<Offset>();

  List<Path> get paths => _pathData;

  CubicPath _activePath;

  bool get hasActivePath => _activePath != null;

  SingleCubicLine _activePart;

  bool get hasActivePart => _activePart != null;

  SignaturePaintParams params;

  void startPath(Offset point) {
    assert(!hasActivePath);

    _rawData.add(point);
    _activePath = CubicPath();
    _activePath.begin(point);

    _pathData.add(_activePath._path);
  }

  void alterPath(Offset point) {
    assert(hasActivePath);

    _rawData.add(point);
    _activePart = _activePath.add(point);

    notifyListeners();
  }

  void closePath({Offset point}) {
    assert(hasActivePath);

    _activePath.end(point: point);

    //_pathData.add(_activePath._path);
    _activePath = null;
    _activePart = null;

    notifyListeners();
  }

  void clear() {
    _pathData.clear();
  }

  @override
  void dispose() {
    super.dispose();

    _pathData.clear();
    _rawData.clear();
    _activePath = null;
    _activePart = null;
  }
}
