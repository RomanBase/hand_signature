import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hand_signature/utils.dart';

import 'signature_painter.dart';

class SignaturePaintParams {
  final Color color;
  final double width;
  final double maxWidth;

  String get hexColor => color.hexValue;

  String get opacity => '${color.opacity}}';

  const SignaturePaintParams({
    this.color: Colors.black,
    this.width: 1.0,
    this.maxWidth: 10.0,
  });
}

class OffsetPoint extends Offset {
  final int timestamp;

  const OffsetPoint({
    double dx,
    double dy,
    this.timestamp,
  }) : super(dx, dy);

  factory OffsetPoint.from(Offset offset) => OffsetPoint(
        dx: offset.dx,
        dy: offset.dy,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

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

class CubicLine extends Offset {
  final OffsetPoint start;
  final Offset cpStart;
  final Offset cpEnd;
  final OffsetPoint end;

  double _velocity;
  double _distance;

  CubicLine({
    @required this.start,
    @required this.cpStart,
    @required this.cpEnd,
    @required this.end,
  }) : super(start.dx, start.dy) {
    _velocity = end.velocityFrom(start);
    _distance = start.distanceTo(end);
  }

  static Offset softCP(OffsetPoint current, {OffsetPoint previous, OffsetPoint next, bool reverse: false, double smoothing: 0.65}) {
    assert(smoothing >= 0.0 && smoothing <= 1.0);

    previous ??= current;
    next ??= current;

    final sharpness = 1.0 - smoothing;

    final dist1 = previous.distanceTo(current);
    final dist2 = current.distanceTo(next);
    final dist = dist1 + dist2;
    final dir1 = current.directionTo(next);
    final dir2 = current.directionTo(previous);
    final dir3 = reverse ? next.directionTo(previous) : previous.directionTo(next);

    final velocity = (dist * 0.3 / (next.timestamp - previous.timestamp)).clamp(0.5, 3.0);
    final ratio = (dist * velocity * smoothing).clamp(0.0, (reverse ? dist2 : dist1) * 0.5);

    final dir = ((reverse ? dir2 : dir1) * sharpness) + (dir3 * smoothing) * ratio;
    final x = current.dx + dir.dx;
    final y = current.dy + dir.dy;

    return Offset(x, y);
  }

  @override
  CubicLine scale(double scaleX, double scaleY) => CubicLine(
        start: start.scale(scaleX, scaleY),
        cpStart: cpStart.scale(scaleX, scaleY),
        cpEnd: cpEnd.scale(scaleX, scaleY),
        end: end.scale(scaleX, scaleY),
      );

  @override
  CubicLine translate(double translateX, double translateY) => CubicLine(
        start: start.translate(translateX, translateY),
        cpStart: cpStart.translate(translateX, translateY),
        cpEnd: cpEnd.translate(translateX, translateY),
        end: end.translate(translateX, translateY),
      );

  /// 0 - fastest, raw accuracy
  /// 1 - slowest, most accurate
  double length({double accuracy: 0.1}) {
    final steps = (accuracy * 100).toInt();

    if (steps <= 1) {
      return _distance;
    }

    double length = 0.0;

    Offset prevPoint = start;
    for (int i = 1; i < steps; i++) {
      final t = i / steps;

      final next = point(t);

      length += prevPoint.distanceTo(next);
      prevPoint = next;
    }

    return length;
  }

  Offset point(double t) {
    final rt = 1.0 - t;
    return (start * rt * rt * rt) + (cpStart * 3.0 * rt * rt * t) + (cpEnd * 3.0 * rt * t * t) + (end * t * t * t);
  }

  double velocity({double accuracy: 0.0}) => start.timestamp != end.timestamp ? length(accuracy: accuracy) / (end.timestamp - start.timestamp) : 0.0;

  double combineVelocity(double inVelocity, {double velocityRatio: 0.65, double maxFallOff: 1.0}) {
    final value = (_velocity * velocityRatio) + (inVelocity * (1.0 - velocityRatio));

    maxFallOff *= _distance / 10.0;

    final dif = value - inVelocity;
    if (dif.abs() > maxFallOff) {
      if (dif > 0.0) {
        return inVelocity + maxFallOff;
      } else {
        return inVelocity - maxFallOff;
      }
    }

    return value;
  }

  List<CubicArc> arcPath(double size, double deltaSize, {double precision: 2.0}) {
    final list = List<CubicArc>();

    final steps = (_distance * precision).floor();

    Offset start = this.start;
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final loc = point(t);
      final width = size + deltaSize * t;

      list.add(CubicArc(
        start: start,
        location: loc,
        size: width,
      ));

      start = loc;
    }

    return list;
  }
}

class CubicArc extends Offset {
  static const rotation = math.pi * 2.0;

  final Offset location;
  final double size;

  Path get path => Path()
    ..moveTo(dx, dy)
    ..arcToPoint(location, rotation: rotation);

  CubicArc({
    @required Offset start,
    @required this.location,
    this.size: 1.0,
  }) : super(start.dx, start.dy);

  @override
  Offset translate(double translateX, double translateY) => CubicArc(
        start: Offset(dx + translateX, dy + translateY),
        location: location.translate(translateX, translateY),
        size: size,
      );

  @override
  Offset scale(double scaleX, double scaleY) => CubicArc(
        start: Offset(dx * scaleX, dy * scaleY),
        location: location.scale(scaleX, scaleY),
        size: size,
      );
}

class CubicPath {
  final _points = List<OffsetPoint>();
  final _lines = List<CubicLine>();
  final _arcs = List<CubicArc>();

  List<OffsetPoint> get points => _points;

  List<CubicLine> get lines => _lines;

  List<CubicArc> get arcs => _arcs;

  Offset get _origin => _points.isNotEmpty ? _points[0] : null;

  OffsetPoint get _lastPoint => _points.isNotEmpty ? _points[_points.length - 1] : null;

  bool get isFilled => _points.isNotEmpty;

  Path _temp;

  Path get path => Path();

  Path get tempPath => _temp;

  double maxVelocity = 1.0;

  double _currentVelocity = 0.0;
  double _currentSize = 0.0;

  final threshold;
  final smoothRatio;

  CubicPath({
    this.threshold: 3.0,
    this.smoothRatio: 0.65,
  });

  void _addLine(CubicLine line) {
    if (_lines.length == 0) {
      if (_currentVelocity == 0.0) {
        _currentVelocity = line._velocity;
      }

      if (_currentSize == 0.0) {
        _currentSize = _lineSize(_currentVelocity, maxVelocity);
      }
    }

    _lines.add(line);

    final combinedVelocity = line.combineVelocity(_currentVelocity, maxFallOff: 0.125);
    final double endSize = _lineSize(combinedVelocity, maxVelocity);

    if (combinedVelocity > maxVelocity) {
      maxVelocity = combinedVelocity;
    }

    _arcs.addAll(line.arcPath(_currentSize, endSize - _currentSize));

    _currentSize = endSize;
    _currentVelocity = combinedVelocity;
  }

  double _lineSize(double velocity, double max) {
    velocity /= max;

    return 1.0 - velocity.clamp(0.0, 1.0);
  }

  void begin(Offset point, {double velocity: 0.0}) {
    _points.add(OffsetPoint.from(point));
    _currentVelocity = velocity;

    _temp = _dot(point);
  }

  void add(Offset point) {
    assert(_origin != null);

    final nextPoint = point is OffsetPoint ? point : OffsetPoint.from(point);

    if (_lastPoint.distanceTo(nextPoint) < threshold) {
      _temp = _line(_points.last, nextPoint);

      return;
    }

    _points.add(nextPoint);
    int count = _points.length;

    if (count < 3) {
      if (count > 1) {
        _temp = _line(_points[0], _points[1]);
      }

      return;
    }

    int i = count - 3;

    final prev = i > 0 ? _points[i - 1] : _points[i];
    final start = _points[i];
    final end = _points[i + 1];
    final next = _points[i + 2];

    final cpStart = CubicLine.softCP(
      start,
      previous: prev,
      next: end,
      smoothing: smoothRatio,
    );

    final cpEnd = CubicLine.softCP(
      end,
      previous: start,
      next: next,
      smoothing: smoothRatio,
      reverse: true,
    );

    final line = CubicLine(
      start: start,
      cpStart: cpStart,
      cpEnd: cpEnd,
      end: end,
    );

    _addLine(line);

    _temp = _line(end, next);
  }

  bool end({Offset point}) {
    if (point != null) {
      add(point);
    }

    _temp = null;

    if (_points.isEmpty) {
      return false;
    }

    if (_points.length < 3) {
      if (_points.length == 1) {
        _addLine(CubicLine(
          start: _points[0],
          cpStart: _points[0],
          cpEnd: _points[0],
          end: _points[0],
        ));
      } else {
        _addLine(CubicLine(
          start: _points[0],
          cpStart: _points[0],
          cpEnd: _points[1],
          end: _points[1],
        ));
      }
    } else {
      final i = _points.length - 3;

      final end = CubicLine(
        start: _points[i + 1],
        cpStart: _points[i + 1],
        cpEnd: _points[i + 2],
        end: _points[i + 2],
      );

      _addLine(end);
    }

    return true;
  }

  Path _dot(Offset point) => Path()
    ..moveTo(point.dx, point.dy)
    ..cubicTo(
      point.dx,
      point.dy,
      point.dx,
      point.dy,
      point.dx,
      point.dy,
    );

  Path _line(Offset start, Offset end, [Offset startCp, Offset endCp]) => Path()
    ..moveTo(start.dx, start.dy)
    ..cubicTo(
      startCp != null ? startCp.dx : (start.dx + end.dx) * 0.5,
      startCp != null ? startCp.dy : (start.dy + end.dy) * 0.5,
      endCp != null ? endCp.dx : (start.dx + end.dx) * 0.5,
      endCp != null ? endCp.dy : (start.dy + end.dy) * 0.5,
      end.dx,
      end.dy,
    );

  void setScale(double ratio) {
    if (!isFilled) {
      return;
    }

    final data = PathUtil.scale(_arcs, ratio);

    _arcs.clear();
    _arcs.addAll(data.cast<CubicArc>());
  }

  void clear() {
    _points.clear();
    _lines.clear();
    _arcs.clear();
  }
}

class HandSignatureControl extends ChangeNotifier {
  final _paths = List<CubicPath>();

  List<CubicPath> get paths => _paths;

  List<List<Offset>> get _offsets {
    final list = List<List<Offset>>();

    _paths.forEach((data) => list.add(data._points));

    return list;
  }

  List<List<CubicLine>> get _cubicLines {
    final list = List<List<CubicLine>>();

    _paths.forEach((data) => list.add(data._lines));

    return list;
  }

  List<CubicArc> get _arcs {
    final list = List<CubicArc>();

    _paths.forEach((data) => list.addAll(data.arcs));

    return list;
  }

  List<CubicLine> get lines {
    final list = List<CubicLine>();

    _paths.forEach((data) => list.addAll(data.lines));

    return list;
  }

  CubicPath _activePath;

  bool get hasActivePath => _activePath != null;

  bool get isFilled => _paths.isNotEmpty;

  SignaturePaintParams params;

  Size _areaSize = Size.zero;

  final double threshold;
  final double smoothRatio;
  final double velocityRange;

  HandSignatureControl({
    this.threshold: 3.0,
    this.smoothRatio: 0.65,
    this.velocityRange: 2.0,
  });

  void startPath(Offset point) {
    assert(!hasActivePath);

    _activePath = CubicPath(
      threshold: threshold,
      smoothRatio: smoothRatio,
    )..maxVelocity = velocityRange;

    _activePath.begin(point, velocity: _paths.isNotEmpty ? _paths[0]._currentVelocity : 0.0);

    _paths.add(_activePath);
  }

  void alterPath(Offset point) {
    assert(hasActivePath);

    _activePath.add(point);

    notifyListeners();
  }

  void closePath({Offset point}) {
    assert(hasActivePath);

    if (!_activePath.end(point: point)) {
      _paths.removeLast();
    }

    _activePath = null;

    notifyListeners();
  }

  void clear() {
    _paths.clear();

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

    _paths.forEach((path) {
      path.setScale(scale);
    });

    Future.delayed(Duration(), () => notifyListeners());

    return true;
  }

  String toSimplePathSvg({int width: 512, int height: 256, double border: 0.0, Color color, double size}) {
    if (!isFilled) {
      return null;
    }

    params ??= SignaturePaintParams(
      color: Colors.black,
      width: 1.0,
      maxWidth: 10.0,
    );

    size ??= params.width;
    color ??= params.color;

    final rect = Rect.fromLTRB(0.0, 0.0, width.toDouble(), height.toDouble());
    final bounds = PathUtil.boundsOf(_offsets);
    final data = PathUtil.fillOf(_cubicLines, rect, bound: bounds, border: size + border);

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buffer.writeln('<svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">');
    buffer.writeln('<g stroke="${color.hexValue}" fill="none" stroke-width="$size" stroke-linecap="round" stroke-linejoin="round" >');

    data.forEach((line) {
      buffer.write('<path d="M ${line[0].dx} ${line[0].dy}');
      line.cast<CubicLine>().forEach((path) => buffer.write(' C ${path.cpStart.dx} ${path.cpStart.dy}, ${path.cpEnd.dx} ${path.cpEnd.dy}, ${path.end.dx} ${path.end.dy}'));
      buffer.writeln('" />');
    });

    buffer.writeln('<\/g>');
    buffer.writeln('<\/svg>');

    return buffer.toString();
  }

  String toSvg({int width: 512, int height: 256, double border: 0.0, Color color, double size, double maxSize}) {
    if (!isFilled) {
      return null;
    }

    params ??= SignaturePaintParams(
      color: Colors.black,
      width: 1.0,
      maxWidth: 10.0,
    );

    color ??= params.color;
    size ??= params.width;
    maxSize ??= params.maxWidth;

    final rect = Rect.fromLTRB(0.0, 0.0, width.toDouble(), height.toDouble());
    final bounds = PathUtil.boundsOf(_offsets);
    final data = PathUtil.fill(_arcs, rect, bound: bounds, border: maxSize + border).cast<CubicArc>();

    if (data == null) {
      return null;
    }

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buffer.writeln('<svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">');
    buffer.writeln('<g stroke="${color.hexValue}" fill="none" stroke-linecap="round" stroke-linejoin="round" >');

    data.forEach((arc) {
      final strokeSize = size + (maxSize - size) * arc.size;
      buffer.writeln('<path d="M ${arc.dx} ${arc.dy} A 0 0, ${CubicArc.rotation}, 0, 0, ${arc.location.dx} ${arc.location.dy}" stroke-width="$strokeSize" \/>');
    });

    buffer.writeln('<\/g>');
    buffer.writeln('<\/svg>');

    return buffer.toString();
  }

  Picture toPicture({int width: 512, int height: 256, Color color, double size, double maxSize}) {
    final data = PathUtil.fill(_arcs, Rect.fromLTRB(0.0, 0.0, width.toDouble(), height.toDouble())).cast<CubicArc>();
    final path = CubicPath().._arcs.addAll(data);

    params ??= SignaturePaintParams(
      color: Colors.black,
      width: 1.0,
      maxWidth: 10.0,
    );

    color ??= params.color;
    size ??= params.width;
    maxSize ??= params.maxWidth;

    final recorder = PictureRecorder();
    final painter = PathSignaturePainter(
      paths: [path],
      color: color,
      width: size,
      maxWidth: maxSize,
    );

    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        Offset(0.0, 0.0),
        Offset(width.toDouble(), height.toDouble()),
      ),
    );

    painter.paint(canvas, Size(width.toDouble(), height.toDouble()));

    return recorder.endRecording();
  }

  Future<ByteData> toImage({int width: 512, int height: 256, Color color, double size, double maxSize, ImageByteFormat format: ImageByteFormat.png}) async {
    final image = await toPicture(
      width: width,
      height: height,
      color: color,
      size: size,
      maxSize: maxSize,
    ).toImage(width, height);

    return image.toByteData(format: format);
  }

  @override
  void dispose() {
    super.dispose();

    clear();
    _activePath = null;
  }
}
