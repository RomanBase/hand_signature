import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hand_signature/path_math.dart';

class SignaturePaintParams {
  final Color color;
  final double width;

  String get hexColor => '#${color.value.toRadixString(16)}'.replaceRange(1, 3, '');

  String get opacity => '${color.opacity}}';

  const SignaturePaintParams(this.color, this.width);
}

class OffsetPoint extends Offset {
  final int timestamp;

  OffsetPoint({
    double dx,
    double dy,
    this.timestamp,
  }) : super(dx, dy);

  factory OffsetPoint.from(Offset offset) => OffsetPoint(
        dx: offset.dx,
        dy: offset.dy,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

  Offset axisDistanceTo(OffsetPoint other) => other - this;

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
  OffsetPoint translate(double translateX, double translateY) {
    return OffsetPoint(
      dx: dx + translateX,
      dy: dy + translateY,
      timestamp: timestamp,
    );
  }

  @override
  OffsetPoint scale(double scaleX, double scaleY) {
    return OffsetPoint(
      dx: dx * scaleX,
      dy: dy * scaleY,
      timestamp: timestamp,
    );
  }

  @override
  bool operator ==(other) {
    return other is OffsetPoint && other.dx == dx && other.dy == dy && other.timestamp == timestamp;
  }

  @override
  int get hashCode => hashValues(super.hashCode, timestamp);
}

class CubicLine {
  final Offset start;
  final Offset controlPoint1;
  final Offset controlPoint2;
  final Offset end;

  const CubicLine({
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

    final x = current.dx + math.cos(angle) * length;
    final y = current.dy + math.sin(angle) * length;

    return Offset(x, y);
  }
}

class CubicPath {
  final _raw = List<OffsetPoint>();

  Offset get _origin => _raw.isNotEmpty ? _raw[0] : null;

  OffsetPoint get _lastPoint => _raw.isNotEmpty ? _raw[_raw.length - 1] : null;

  bool get isFilled => _raw.isNotEmpty;

  final threshold = 3.0;

  Path _path;

  Path begin(Offset point) {
    assert(_path == null);

    _path = Path();
    _raw.add(OffsetPoint.from(point));
    _path.moveTo(point.dx, point.dy);

    return _path;
  }

  void add(Offset point) {
    assert(_origin != null);

    final nextPoint = point is OffsetPoint ? point : OffsetPoint.from(point);

    if (_lastPoint.distanceTo(nextPoint) < threshold) {
      return;
    }

    _raw.add(nextPoint);
    if (_raw.length < 2) {
      return;
    }

    int i = _raw.length - 2;

    final start = _raw[i];
    final end = _raw[i + 1];

    final prev = i > 0 ? _raw[i - 1] : start;
    final next = i < _raw.length - 2 ? _raw[i + 2] : end;

    final cpStart = CubicLine.softCP(
      start,
      previous: prev,
      next: end,
    );

    final cpEnd = CubicLine.softCP(
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
      end.dx,
      end.dy,
    );
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
        _raw[0].dx,
        _raw[0].dy,
        _raw[0].dx,
        _raw[0].dy,
        _raw[0].dx,
        _raw[0].dy,
      );
    }

    return true;
  }

  Path setScale(double ratio) {
    if (!isFilled) {
      return null;
    }

    final data = OffsetMath.scale(_raw, ratio);

    _raw.clear();
    _path = null;

    begin(data[0]);
    data.forEach((point) => add(point));
    end();

    return _path;
  }
}

class HandSignatureControl extends ChangeNotifier {
  final _pathData = List<Path>();
  final _rawData = List<CubicPath>();

  List<Path> get paths => _pathData;

  CubicPath _activePath;

  bool get hasActivePath => _activePath != null;

  bool get isFilled => _rawData.isNotEmpty;

  SignaturePaintParams params;

  Size _areaSize = Size.zero;

  void startPath(Offset point) {
    assert(!hasActivePath);

    _activePath = CubicPath();
    _activePath.begin(point);

    _rawData.add(_activePath);
    _pathData.add(_activePath._path);
  }

  void alterPath(Offset point) {
    assert(hasActivePath);

    _activePath.add(point);

    notifyListeners();
  }

  void closePath({Offset point}) {
    assert(hasActivePath);

    if (!_activePath.end(point: point)) {
      _rawData.removeLast();
      _pathData.removeLast();
    }

    _activePath = null;

    notifyListeners();
  }

  void clear() {
    _rawData.clear();
    _pathData.clear();

    notifyListeners();
  }

  bool notifyDimension(Size size) {
    if (_areaSize == size) {
      return false;
    }

    if (_areaSize.isEmpty || _areaSize.width == size.width || _areaSize.height == size.height) {
      _areaSize = size;
      return false;
    }

    if (hasActivePath) {
      closePath();
    }

    if (!isFilled) {
      _areaSize = size;
      return false;
    }

    //TODO: currently works only when aspect ratio stays same..
    final ratioX = size.width / _areaSize.width;
    final ratioY = size.height / _areaSize.height;
    final scale = math.min(ratioX, ratioY);

    _areaSize = size;

    _pathData.clear();
    _rawData.forEach((path) {
      final data = path.setScale(scale);
      if (data != null) {
        _pathData.add(data);
      }
    });

    Future.delayed(Duration(), () => notifyListeners());

    return true;
  }

  @override
  void dispose() {
    super.dispose();

    clear();
    _activePath = null;
  }
}
