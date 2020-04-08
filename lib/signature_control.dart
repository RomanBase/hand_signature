import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hand_signature/path_math.dart';

import 'signature_painter.dart';

class SignaturePaintParams {
  final Color color;
  final double width;
  final double maxWidth;

  String get hexColor => '#${color.value.toRadixString(16)}'.replaceRange(1, 3, '');

  String get opacity => '${color.opacity}}';

  const SignaturePaintParams({
    @required this.color,
    @required this.width,
    this.maxWidth,
  });
}

extension OffsetEx on Offset {
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
        timestamp: DateTime.now().microsecondsSinceEpoch,
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

  CubicLine({
    this.start,
    this.cpStart,
    this.cpEnd,
    this.end,
  }) : super(start.dx, start.dy);

  //TODO: smoothing based on distance with smoothRatio multiplier
  static Offset softCP(OffsetPoint current, {OffsetPoint previous, OffsetPoint next, bool reverse: false, double smoothing: 0.2}) {
    previous ??= current;
    next ??= current;

    final angle = previous.angleTo(next) + (reverse ? math.pi : 0);
    final length = previous.distanceTo(next) * smoothing;

    final x = current.dx + math.cos(angle) * length;
    final y = current.dy + math.sin(angle) * length;

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

  double length({double accuracy: 0.1}) {
    final steps = (accuracy * 100).toInt();

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

  double velocity({double accuracy: 0.1}) => start.timestamp != end.timestamp ? length(accuracy: accuracy) / (start.timestamp - end.timestamp) : 0.0;

  double combineVelocity(double inVelocity, {double velocityRatio: 0.65}) => velocity() * velocityRatio + (inVelocity * (1.0 - velocityRatio));
}

class CubicPath {
  final threshold;
  final smoothRatio;

  final _raw = List<OffsetPoint>();
  final _rawLine = List<CubicLine>();

  List<OffsetPoint> get points => _raw;

  List<CubicLine> get lines => _rawLine;

  Offset get _origin => _raw.isNotEmpty ? _raw[0] : null;

  OffsetPoint get _lastPoint => _raw.isNotEmpty ? _raw[_raw.length - 1] : null;

  bool get isFilled => _raw.isNotEmpty;

  Path _path;
  Path _temp;

  Path get path => _path;

  Path get tempPath => _temp;

  CubicPath({
    this.threshold: 3.0,
    this.smoothRatio: 0.2,
  });

  Path begin(Offset point) {
    assert(_path == null);

    _path = Path();
    _raw.add(OffsetPoint.from(point));
    _path.moveTo(point.dx, point.dy);

    _temp = _dot(point);

    return _path;
  }

  void add(Offset point) {
    assert(_origin != null);

    final nextPoint = point is OffsetPoint ? point : OffsetPoint.from(point);

    if (_lastPoint.distanceTo(nextPoint) < threshold) {
      if (_raw.length > 1) {
        _temp = _line(
          _raw[_raw.length - 2],
          nextPoint,
          CubicLine.softCP(
            _raw[_raw.length - 1],
            previous: _raw[_raw.length - 2],
            next: nextPoint,
            smoothing: smoothRatio,
          ),
          CubicLine.softCP(
            nextPoint,
            previous: _raw[_raw.length - 1],
            smoothing: smoothRatio,
            reverse: true,
          ),
        );
      } else {
        _temp = _line(_raw[0], nextPoint);
      }

      return;
    }

    _raw.add(nextPoint);
    int count = _raw.length;

    if (count < 3) {
      if (count > 1) {
        _temp = _line(_raw[0], _raw[1]);
      }

      return;
    }

    int i = count - 3;

    final start = _raw[i];
    final end = _raw[i + 1];

    final prev = i > 0 ? _raw[i - 1] : start;
    final next = i < count - 2 ? _raw[i + 2] : end;

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

    _rawLine.add(CubicLine(
      start: start,
      cpStart: cpStart,
      cpEnd: cpEnd,
      end: end,
    ));

    _path.cubicTo(
      cpStart.dx,
      cpStart.dy,
      cpEnd.dx,
      cpEnd.dy,
      end.dx,
      end.dy,
    );

    _temp = _line(end, next);
  }

  bool end({Offset point}) {
    if (point != null) {
      add(point);
    }

    _temp = null;

    if (_raw.isEmpty) {
      return false;
    }

    if (_raw.length < 3) {
      if (_raw.length == 1) {
        _path.cubicTo(
          _raw[0].dx,
          _raw[0].dy,
          _raw[0].dx,
          _raw[0].dy,
          _raw[0].dx,
          _raw[0].dy,
        );

        _rawLine.add(CubicLine(
          start: _raw[0],
          cpStart: _raw[0],
          cpEnd: _raw[0],
          end: _raw[0],
        ));
      } else {
        _path.cubicTo(
          _raw[0].dx,
          _raw[0].dy,
          _raw[1].dx,
          _raw[1].dy,
          _raw[1].dx,
          _raw[1].dy,
        );

        _rawLine.add(CubicLine(
          start: _raw[0],
          cpStart: _raw[0],
          cpEnd: _raw[1],
          end: _raw[1],
        ));
      }
    } else {
      final i = _raw.length - 3;

      final last = CubicLine(
        start: _raw[i],
        cpStart: CubicLine.softCP(
          _raw[i + 1],
          previous: _raw[i],
          next: _raw[i + 2],
          smoothing: smoothRatio,
        ),
        cpEnd: CubicLine.softCP(
          _raw[i + 2],
          previous: _raw[i + 1],
          smoothing: smoothRatio,
          reverse: true,
        ),
        end: _raw[i + 1],
      );

      final end = CubicLine(
        start: _raw[i + 1],
        cpStart: _raw[i + 1],
        cpEnd: _raw[i + 2],
        end: _raw[i + 2],
      );

      _path.cubicTo(
        last.cpStart.dx,
        last.cpStart.dy,
        last.cpEnd.dx,
        last.cpEnd.dy,
        last.end.dx,
        last.end.dy,
      );

      _path.cubicTo(
        end.cpStart.dx,
        end.cpStart.dy,
        end.cpEnd.dx,
        end.cpEnd.dy,
        end.end.dx,
        end.end.dy,
      );

      _rawLine.add(last);
      _rawLine.add(end);
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

  Path setScale(double ratio) {
    if (!isFilled) {
      return null;
    }

    final data = OffsetMath.scale(_raw, ratio);

    _raw.clear();
    _rawLine.clear();
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

  List<Path> get paths {
    final paths = List.of(_pathData);

    if (_activePath?._temp != null) {
      paths.add(_activePath._temp);
    }

    return paths;
  }

  List<List<Offset>> get _rawList {
    final list = List<List<Offset>>();

    _rawData.forEach((data) => list.add(data._raw));

    return list;
  }

  List<List<CubicLine>> get _rawLine {
    final list = List<List<CubicLine>>();

    _rawData.forEach((data) => list.add(data._rawLine));

    return list;
  }

  CubicPath _activePath;

  bool get hasActivePath => _activePath != null;

  bool get isFilled => _rawData.isNotEmpty;

  SignaturePaintParams params;

  Size _areaSize = Size.zero;

  final double threshold;
  final double smoothRatio;

  //TODO: convert smoothRatio to 0-1
  HandSignatureControl({
    this.threshold: 3.0,
    this.smoothRatio: 0.25,
  });

  void startPath(Offset point) {
    assert(!hasActivePath);

    _activePath = CubicPath(
      threshold: threshold,
      smoothRatio: 0.25,
    );
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

  String asSvg({double width: 256.0, double height: 256.0, double border: 0.0}) {
    if (!isFilled) {
      return null;
    }

    params ??= SignaturePaintParams(
      color: Colors.black,
      width: 6.0,
    );

    final rect = Rect.fromLTRB(0.0, 0.0, width, height);
    final bounds = OffsetMath.boundsOf(_rawList);
    final data = OffsetMath.fillOf(_rawLine, rect, bound: bounds, border: params.width + border);

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buffer.writeln('<svg width="$width" height="$height" xmlns="http://www.w3.org/2000/svg">');

    buffer.writeln('<g stroke="${params.hexColor}" fill="none" stroke-width="${params.width}" stroke-linecap="round" stroke-linejoin="round" >');
    data.forEach((line) {
      buffer.write('<path d="M ${line[0].dx} ${line[0].dy}');
      line.cast<CubicLine>().forEach((path) => buffer.write(' C ${path.cpStart.dx} ${path.cpStart.dy}, ${path.cpEnd.dx} ${path.cpEnd.dy}, ${path.end.dx} ${path.end.dy}'));
      buffer.writeln('" />');
    });
    buffer.writeln('<\/g>');

    buffer.writeln('<\/svg>');

    return buffer.toString();
  }

  Picture asPicture({double width: 256.0, double height: 256.0}) {
    final data = OffsetMath.fillOf(_rawList, Rect.fromLTRB(0.0, 0.0, width, height));

    final recorder = PictureRecorder();
    final painter = HandSignaturePainter(
      paths: OffsetMath.asPathOf(data),
      color: params?.color,
      width: params?.width,
    );

    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        Offset(0.0, 0.0),
        Offset(width, height),
      ),
    );

    painter.paint(canvas, Size(width, height));

    return recorder.endRecording();
  }

  Future<ByteData> asPng({int width: 256, int height: 256}) async {
    final image = await asPicture(width: width.toDouble(), height: height.toDouble()).toImage(width, height);

    return image.toByteData();
  }

  @override
  void dispose() {
    super.dispose();

    clear();
    _activePath = null;
  }
}
