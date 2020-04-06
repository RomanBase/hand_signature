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

  Offset axisDistanceTo(OffsetPoint other) => other.location - location;

  double distanceTo(OffsetPoint other) {
    final len = axisDistanceTo(other);

    return math.sqrt(len.dx * len.dx + len.dy * len.dy);
  }

  double angleTo(OffsetPoint other) {
    final len = axisDistanceTo(other);

    return math.atan2(len.dy, len.dx);
  }

  Offset directionTo(OffsetPoint other) {
    final len = axisDistanceTo(other);
    final m = distanceTo(other);

    return Offset(len.dx / m, len.dy / m);
  }

  double velocityFrom(OffsetPoint other) => timestamp != other.timestamp ? this.distanceTo(other) / (timestamp - other.timestamp) : 0.0;

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

  const SingleCubicLine({
    this.start,
    this.controlPoint1,
    this.controlPoint2,
    this.end,
  });

  static Offset softCP(OffsetPoint current, {OffsetPoint previous, OffsetPoint next, bool reverse: false, double smoothing: 0.2}) {
    previous ??= current;
    next ??= current;

    final angle = previous.angleTo(next) + (reverse ? math.pi : 0);
    final length = previous.distanceTo(next) * smoothing;

    final x = current.x + math.cos(angle) * length;
    final y = current.y + math.sin(angle) * length;

    return Offset(x, y);
  }
}

class CubicPath {
  final _raw = List<OffsetPoint>();

  Offset get _origin => _raw.isNotEmpty ? _raw[0].location : null;

  OffsetPoint get _lastPoint => _raw.isNotEmpty ? _raw[_raw.length - 1] : null;

  final threshold = 3.0;

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
    if (_raw.length < 2) {
      return null;
    }

    int i = _raw.length - 2;

    final start = _raw[i];
    final end = _raw[i + 1];

    final prev = i > 0 ? _raw[i - 1] : start;
    final next = i < _raw.length - 2 ? _raw[i + 2] : end;

    final cpStart = SingleCubicLine.softCP(
      start,
      previous: prev,
      next: end,
    );

    final cpEnd = SingleCubicLine.softCP(
      end,
      previous: start,
      next: next,
      reverse: true,
    );

    _path.cubicTo(
      cpStart.dx,
      cpStart.dy,
      cpEnd.dx,
      cpEnd.dy,
      end.x,
      end.y,
    );

    return SingleCubicLine();
  }

  bool end({Offset point}) {
    if (point != null) {
      add(point);
    }

    if (_raw.isEmpty) {
      return false;
    }

    if (_raw.length < 2) {
      _path.cubicTo(
        _raw[0].x,
        _raw[0].y,
        _raw[0].x,
        _raw[0].y,
        _raw[0].x,
        _raw[0].y,
      );
    }

    return true;
  }
}

class HandSignatureControl extends ChangeNotifier {
  final _pathData = List<Path>();
  final _rawData = List<Offset>();

  List<Path> get paths => _pathData;

  List<Offset> get points => _rawData;

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

    if (!_activePath.end(point: point)) {
      _pathData.removeLast();
    }

    _activePath = null;
    _activePart = null;

    notifyListeners();
  }

  void clear() {
    _pathData.clear();
    _rawData.clear();
  }

  @override
  void dispose() {
    super.dispose();

    clear();
    _activePath = null;
    _activePart = null;
  }
}
