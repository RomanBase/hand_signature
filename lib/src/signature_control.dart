import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../signature.dart';
import 'utils.dart';

/// Paint settings.
class SignaturePaintParams {
  /// Color of line.
  final Color color;

  /// Minimal width of line.
  final double strokeWidth;

  /// Maximal width of line.
  final double maxStrokeWidth;

  /// Hex value of [color].
  String get hexColor => color.hexValue;

  /// Opacity of [color].
  String get opacity => '${color.opacity}}';

  /// Paint settings of line.
  /// [color] - color of line.
  /// [strokeWidth] - minimal width of line.
  /// [maxStrokeWidth] - maximal width of line.
  const SignaturePaintParams({
    this.color = Colors.black,
    this.strokeWidth = 1.0,
    this.maxStrokeWidth = 10.0,
  });
}

/// Extended [Offset] point with [timestamp].
class OffsetPoint extends Offset {
  /// Timestamp of this point. Used to determine velocity to other points.
  final int timestamp;

  /// 2D point in canvas space.
  /// [timestamp] of this [Offset]. Used to determine velocity to other points.
  const OffsetPoint({
    required double dx,
    required double dy,
    required this.timestamp,
  }) : super(dx, dy);

  factory OffsetPoint.from(Offset offset) => OffsetPoint(
        dx: offset.dx,
        dy: offset.dy,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

  factory OffsetPoint.fromMap(Map<String, dynamic> map) => OffsetPoint(
        dx: map['x'],
        dy: map['y'],
        timestamp: map['t'],
      );

  Map<String, dynamic> toMap() => {
        'x': dx,
        'y': dy,
        't': timestamp,
      };

  /// Returns velocity between this and [other] - previous point.
  double velocityFrom(OffsetPoint other) => timestamp != other.timestamp
      ? this.distanceTo(other) / (timestamp - other.timestamp)
      : 0.0;

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
    return other is OffsetPoint &&
        other.dx == dx &&
        other.dy == dy &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, timestamp);
}

/// Line between two points. Curve of this line is controlled with other two points.
/// Check https://cubic-bezier.com/ for more info about Bezier Curve.
class CubicLine extends Offset {
  /// Initial point of curve.
  final OffsetPoint start;

  /// Control of [start] point.
  final Offset cpStart;

  /// Control of [end] point
  final Offset cpEnd;

  /// End point of curve.
  final OffsetPoint end;

  late double _velocity;
  late double _distance;

  /// Cache of Up vector.
  Offset? _upStartVector;

  /// Up vector of [start] point.
  Offset get upStartVector =>
      _upStartVector ??
      (_upStartVector = start.directionTo(point(0.001)).rotate(-math.pi * 0.5));

  /// Cache of Up vector.
  Offset? _upEndVector;

  /// Up vector of [end] point.
  Offset get upEndVector =>
      _upEndVector ??
      (_upEndVector = end.directionTo(point(0.999)).rotate(math.pi * 0.5));

  /// Down vector.
  Offset get _downStartVector => upStartVector.rotate(math.pi);

  /// Down vector.
  Offset get _downEndVector => upEndVector.rotate(math.pi);

  /// Start ratio size of line.
  double startSize;

  /// End ratio size of line.
  double endSize;

  /// Checks if point is dot.
  /// Returns 'true' if [start] and [end] is same -> [velocity] is zero.
  bool get isDot => _velocity == 0.0;

  /// Based on Bezier Cubic curve.
  /// [start] point of curve.
  /// [end] point of curve.
  /// [cpStart] - control point of [start] vector.
  /// [cpEnd] - control point of [end] vector.
  /// [startSize] - size ratio at begin of curve.
  /// [endSize] - size ratio at end of curve.
  /// [upStartVector] - pre-calculated Up vector fo start point.
  /// [upEndVector] - pre-calculated Up vector of end point.
  CubicLine({
    required this.start,
    required this.cpStart,
    required this.cpEnd,
    required this.end,
    Offset? upStartVector,
    Offset? upEndVector,
    this.startSize = 0.0,
    this.endSize = 0.0,
  }) : super(start.dx, start.dy) {
    _upStartVector = upStartVector;
    _upEndVector = upEndVector;
    _velocity = end.velocityFrom(start);
    _distance = start.distanceTo(end);
  }

  @override
  CubicLine scale(double scaleX, double scaleY) => CubicLine(
        start: start.scale(scaleX, scaleY),
        cpStart: cpStart.scale(scaleX, scaleY),
        cpEnd: cpEnd.scale(scaleX, scaleY),
        end: end.scale(scaleX, scaleY),
        upStartVector: _upStartVector,
        upEndVector: _upEndVector,
        startSize: startSize * (scaleX + scaleY) * 0.5,
        endSize: endSize * (scaleX + scaleY) * 0.5,
      );

  @override
  CubicLine translate(double translateX, double translateY) => CubicLine(
        start: start.translate(translateX, translateY),
        cpStart: cpStart.translate(translateX, translateY),
        cpEnd: cpEnd.translate(translateX, translateY),
        end: end.translate(translateX, translateY),
        upStartVector: _upStartVector,
        upEndVector: _upEndVector,
        startSize: startSize,
        endSize: endSize,
      );

  /// Calculates length of Cubic curve with given [accuracy].
  /// 0 - fastest, raw accuracy.
  /// 1 - slowest, most accurate.
  /// Returns length of curve.
  double length({double accuracy = 0.1}) {
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

  /// Calculates point on curve at given [t].
  /// [t] - 0 to 1.
  /// Returns location on Curve at [t].
  Offset point(double t) {
    final rt = 1.0 - t;
    return (start * rt * rt * rt) +
        (cpStart * 3.0 * rt * rt * t) +
        (cpEnd * 3.0 * rt * t * t) +
        (end * t * t * t);
  }

  /// Velocity along this line.
  double velocity({double accuracy = 0.0}) => start.timestamp != end.timestamp
      ? length(accuracy: accuracy) / (end.timestamp - start.timestamp)
      : 0.0;

  /// Combines line velocity with [inVelocity] based on [velocityRatio].
  double combineVelocity(double inVelocity,
      {double velocityRatio = 0.65, double maxFallOff = 1.0}) {
    final value =
        (_velocity * velocityRatio) + (inVelocity * (1.0 - velocityRatio));

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

  /// Converts this line to Cubic [Path].
  Path toPath() => Path()
    ..moveTo(dx, dy)
    ..cubicTo(cpStart.dx, cpStart.dy, cpEnd.dx, cpEnd.dy, end.dx, end.dy);

  /// Converts this line to [CubicArc].
  List<CubicArc> toArc(double size, double deltaSize,
      {double precision = 0.5}) {
    final list = <CubicArc>[];

    final steps = (_distance * precision).floor().clamp(1, 30);

    Offset start = this.start;
    for (int i = 0; i < steps; i++) {
      final t = (i + 1) / steps;
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

  /// Converts this line to closed [Path].
  Path toShape(double size, double maxSize) {
    final startArm = (size + (maxSize - size) * startSize) * 0.5;
    final endArm = (size + (maxSize - size) * endSize) * 0.5;

    final sDirUp = upStartVector;
    final eDirUp = upEndVector;

    final d1 = sDirUp * startArm;
    final d2 = eDirUp * endArm;
    final d3 = eDirUp.rotate(math.pi) * endArm;
    final d4 = sDirUp.rotate(math.pi) * startArm;

    return Path()
      ..start(start + d1)
      ..cubic(cpStart + d1, cpEnd + d2, end + d2)
      ..line(end + d3)
      ..cubic(cpEnd + d3, cpStart + d4, start + d4)
      ..close();
  }

  /// Returns Up offset of start point.
  Offset cpsUp(double size, double maxSize) =>
      upStartVector * startRadius(size, maxSize);

  /// Returns Up offset of end point.
  Offset cpeUp(double size, double maxSize) =>
      upEndVector * endRadius(size, maxSize);

  /// Returns Down offset of start point.
  Offset cpsDown(double size, double maxSize) =>
      _downStartVector * startRadius(size, maxSize);

  /// Returns Down offset of end point.
  Offset cpeDown(double size, double maxSize) =>
      _downEndVector * endRadius(size, maxSize);

  /// Returns radius of start point.
  double startRadius(double size, double maxSize) =>
      _lerpRadius(size, maxSize, startSize);

  /// Returns radius of end point.
  double endRadius(double size, double maxSize) =>
      _lerpRadius(size, maxSize, endSize);

  /// Linear interpolation of size.
  /// Returns radius of interpolated size.
  double _lerpRadius(double size, double maxSize, double t) =>
      (size + (maxSize - size) * t) * 0.5;

  /// Calculates [current] point based on [previous] and [next] control points.
  static Offset softCP(OffsetPoint current,
      {OffsetPoint? previous,
      OffsetPoint? next,
      bool reverse = false,
      double smoothing = 0.65}) {
    assert(smoothing >= 0.0 && smoothing <= 1.0);

    previous ??= current;
    next ??= current;

    final sharpness = 1.0 - smoothing;

    final dist1 = previous.distanceTo(current);
    final dist2 = current.distanceTo(next);
    final dist = dist1 + dist2;
    final dir1 = current.directionTo(next);
    final dir2 = current.directionTo(previous);
    final dir3 =
        reverse ? next.directionTo(previous) : previous.directionTo(next);

    final velocity =
        (dist * 0.3 / (next.timestamp - previous.timestamp)).clamp(0.5, 3.0);
    final ratio = (dist * velocity * smoothing)
        .clamp(0.0, (reverse ? dist2 : dist1) * 0.5);

    final dir =
        ((reverse ? dir2 : dir1) * sharpness) + (dir3 * smoothing) * ratio;
    final x = current.dx + dir.dx;
    final y = current.dy + dir.dy;

    return Offset(x, y);
  }

  @override
  bool operator ==(Object other) =>
      other is CubicLine &&
      start == other.start &&
      cpStart == other.cpStart &&
      cpEnd == other.cpEnd &&
      end == other.end &&
      startSize == other.startSize &&
      endSize == other.endSize;

  @override
  int get hashCode =>
      super.hashCode ^
      start.hashCode ^
      cpStart.hashCode ^
      cpEnd.hashCode ^
      end.hashCode ^
      startSize.hashCode ^
      endSize.hashCode;
}

/// Arc between two points.
class CubicArc extends Offset {
  static const _pi2 = math.pi * 2.0;

  /// End location of arc.
  final Offset location;

  /// Line size.
  final double size;

  /// Arc path.
  Path get path => Path()
    ..moveTo(dx, dy)
    ..arcToPoint(location, rotation: _pi2);

  /// Rectangle of start and end point.
  Rect get rect => Rect.fromPoints(this, location);

  /// Arc line.
  /// [start] point of arc.
  /// [location] end point of arc.
  /// [size] ratio of arc. typically 0 - 1.
  CubicArc({
    required Offset start,
    required this.location,
    this.size = 1.0,
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
        size: size * (scaleX + scaleY) * 0.5,
      );
}

/// Combines sequence of points into one Line.
class CubicPath {
  /// Raw data.
  final _points = <OffsetPoint>[];

  /// [CubicLine] representation of path.
  final _lines = <CubicLine>[];

  /// [CubicArc] representation of path.
  final _arcs = <CubicArc>[];

  /// Distance between two control points.
  final double threshold;

  /// Ratio of line smoothing.
  /// Don't have impact to performance. Values between 0 - 1.
  /// [0] - no smoothing, no flattening.
  /// [1] - best smoothing, but flattened.
  /// Best results are between: 0.5 - 0.85.
  final double smoothRatio;

  /// Returns raw data of path.
  List<OffsetPoint> get points => _points;

  /// Returns [CubicLine] representation of path.
  List<CubicLine> get lines => _lines;

  /// Returns [CubicArc] representation of path.
  List<CubicArc> get arcs => _arcs;

  /// First point of path.
  Offset? get _origin => _points.isNotEmpty ? _points[0] : null;

  /// Last point of path.
  OffsetPoint? get _lastPoint =>
      _points.isNotEmpty ? _points[_points.length - 1] : null;

  /// Checks if path is valid.
  bool get isFilled => _lines.isNotEmpty;

  /// Checks if this Line is just dot.
  bool get isDot => lines.length == 1 && lines[0].isDot;

  /// Unfinished path.
  // Path? _temp;

  /// Returns currently unfinished part of path.
  // Path? get tempPath => _temp;

  /// Maximum possible velocity.
  double _maxVelocity = 1.0;

  /// Actual average velocity.
  double _currentVelocity = 0.0;

  /// Actual size based on velocity.
  double _currentSize = 0.0;

  /// Line builder.
  /// [threshold] - Distance between two control points.
  /// [smoothRatio] - Ratio of line smoothing.
  CubicPath({
    this.threshold = 3.0,
    this.smoothRatio = 0.65,
  });

  /// Adds line to path.
  void _addLine(CubicLine line) {
    if (_lines.length == 0) {
      if (_currentVelocity == 0.0) {
        _currentVelocity = line._velocity;
      }

      if (_currentSize == 0.0) {
        _currentSize = _lineSize(_currentVelocity, _maxVelocity);
      }
    } else {
      line._upStartVector = _lines.last.upEndVector;
    }

    _lines.add(line);

    final combinedVelocity =
        line.combineVelocity(_currentVelocity, maxFallOff: 0.125);
    final double endSize = _lineSize(combinedVelocity, _maxVelocity);

    if (combinedVelocity > _maxVelocity) {
      _maxVelocity = combinedVelocity;
    }

    line.startSize = _currentSize;
    line.endSize = endSize;

    _arcs.addAll(line.toArc(_currentSize, endSize - _currentSize));

    _currentSize = endSize;
    _currentVelocity = combinedVelocity;
  }

  /// Adds dot to path.
  void _addDot(CubicLine line) {
    final size = 0.25 + _lineSize(_currentVelocity, _maxVelocity) * 0.5;
    line.startSize = size;

    _lines.add(line);
    _arcs.addAll(line.toArc(size, 0.0));
  }

  /// Calculates line size based on [velocity].
  double _lineSize(double velocity, double max) {
    velocity /= max;

    return 1.0 - velocity.clamp(0.0, 1.0);
  }

  /// Starts path at given [point].
  /// Must be called as first, before [begin], [end].
  void begin(Offset point, {double velocity = 0.0}) {
    _points.add(point is OffsetPoint ? point : OffsetPoint.from(point));
    _currentVelocity = velocity;
  }

  /// Alters path with given [point].
  void add(Offset point) {
    assert(_origin != null);

    final nextPoint = point is OffsetPoint ? point : OffsetPoint.from(point);

    if (_lastPoint == null || _lastPoint!.distanceTo(nextPoint) < threshold) {
      return;
    }

    _points.add(nextPoint);
    int count = _points.length;

    if (count < 3) {
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
  }

  /// Ends path at given [point].
  bool end({Offset? point}) {
    if (point != null) {
      add(point);
    }

    if (_points.isEmpty) {
      return false;
    }

    if (_points.length < 3) {
      if (_points.length == 1 || _points[0].distanceTo(points[1]) == 0.0) {
        _addDot(CubicLine(
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

      if (_points[i + 1].distanceTo(points[i + 2]) > 0.0) {
        _addLine(CubicLine(
          start: _points[i + 1],
          cpStart: _points[i + 1],
          cpEnd: _points[i + 2],
          end: _points[i + 2],
        ));
      }
    }

    return true;
  }

  /// Sets scale of whole line.
  void setScale(double ratio) {
    if (!isFilled) {
      return;
    }

    final arcData = PathUtil.scale<CubicArc>(_arcs, ratio);
    _arcs
      ..clear()
      ..addAll(arcData);

    final lineData = PathUtil.scale<CubicLine>(_lines, ratio);
    _lines
      ..clear()
      ..addAll(lineData);
  }

  /// Clears all path data-.
  void clear() {
    _points.clear();
    _lines.clear();
    _arcs.clear();
  }

  /// Currently checks only equality of [points].
  bool equals(CubicPath other) {
    if (points.length == other.points.length) {
      for (int i = 0; i < points.length; i++) {
        if (points[i] != other.points[i]) {
          return false;
        }
      }

      return true;
    }

    return false;
  }
}

/// Controls signature drawing and line shape.
/// Also handles export of finished signature.
class HandSignatureControl extends ChangeNotifier {
  /// Distance between two control points.
  final double threshold;

  /// Smoothing ratio of path.
  final double smoothRatio;

  /// Maximal velocity.
  final double velocityRange;

  /// List of active paths.
  final _paths = <CubicPath>[];

  /// List of currently completed lines.
  List<CubicPath> get paths => _paths;

  /// Lazy list of all control points - raw data.
  List<List<Offset>> get _offsets {
    final list = <List<Offset>>[];

    _paths.forEach((data) => list.add(data._points));

    return list;
  }

  /// Lazy list of all Lines.
  List<List<CubicLine>> get _cubicLines {
    final list = <List<CubicLine>>[];

    _paths.forEach((data) => list.add(data._lines));

    return list;
  }

  /// Lazy list of all Arcs.
  List<CubicArc> get _arcs {
    final list = <CubicArc>[];

    _paths.forEach((data) => list.addAll(data.arcs));

    return list;
  }

  /// Lazy list of all Lines.
  List<CubicLine> get lines {
    final list = <CubicLine>[];

    _paths.forEach((data) => list.addAll(data._lines));

    return list;
  }

  /// Currently unfinished path.
  CubicPath? _activePath;

  /// Visual parameters of line painting.
  SignaturePaintParams? params;

  /// Canvas size.
  Size _areaSize = Size.zero;

  /// Checks if is there unfinished path.
  bool get hasActivePath => _activePath != null;

  /// Checks if something is drawn.
  bool get isFilled => _paths.isNotEmpty;

  /// Controls input from [HandSignature] and creates smooth signature path.
  /// [threshold] minimal distance between two points.
  /// [smoothRatio] smoothing ratio of curved parts.
  /// [velocityRange] controls velocity speed and dampening between points (only Shape and Arc drawing types using this property to control line width). aka how fast si signature drawn..
  HandSignatureControl({
    this.threshold = 3.0,
    this.smoothRatio = 0.65,
    this.velocityRange = 2.0,
  })  : assert(threshold > 0.0),
        assert(smoothRatio > 0.0 && smoothRatio <= 1.0),
        assert(velocityRange > 0.0);

  factory HandSignatureControl.fromMap(Map<String, dynamic> data) =>
      HandSignatureControl(
        smoothRatio: data['smoothRatio'],
        threshold: data['threshold'],
        velocityRange: data['velocityRange'],
      )..importData(data);

  /// Starts new line at given [point].
  void startPath(Offset point) {
    assert(!hasActivePath);

    _activePath = CubicPath(
      threshold: threshold,
      smoothRatio: smoothRatio,
    ).._maxVelocity = velocityRange;

    _activePath!.begin(point,
        velocity: _paths.isNotEmpty ? _paths.last._currentVelocity : 0.0);

    _paths.add(_activePath!);
  }

  /// Adds [point[ to active path.
  void alterPath(Offset point) {
    assert(hasActivePath);

    _activePath?.add(point);

    notifyListeners();
  }

  /// Closes active path at given [point].
  void closePath([Offset? point]) {
    assert(hasActivePath);

    final valid = _activePath?.end(point: point);

    if (valid == false) {
      _paths.removeLast();
    }

    _activePath = null;

    notifyListeners();
  }

  /// Imports given [paths] and alters current signature data.
  void importPath(List<CubicPath> paths, [Size? bounds]) {
    //TODO: check bounds

    if (bounds != null) {
      if (_areaSize.isEmpty) {
        print(
            'Signature: Canvas area is not specified yet. Signature can be out of visible bounds or misplaced.');
      } else if (_areaSize != bounds) {
        print(
            'Signature: Canvas area has different size. Signature can be out of visible bounds or misplaced.');
      }
    }

    _paths.addAll(paths);
    notifyListeners();
  }

  /// Expects [data] from [toMap].
  void importData(Map data) {
    final list = <CubicPath>[];

    final bounds = Size(data['bounds']['width'], data['bounds']['height']);
    final paths = data['paths'];
    final threshold = data['threshold'];
    final smoothRatio = data['smoothRatio'];
    final velocityRange = data['velocityRange'];

    for (final path in paths) {
      final List points = List.from(path);

      final cp = CubicPath(
        threshold: threshold,
        smoothRatio: smoothRatio,
      ).._maxVelocity = velocityRange;

      cp.begin(OffsetPoint.fromMap(points[0]));
      points.skip(1).forEach((element) => cp.add(OffsetPoint.fromMap(element)));
      cp.end();

      list.add(cp);
    }

    importPath(list, bounds);
  }

  /// Removes last line.
  bool stepBack() {
    assert(!hasActivePath);

    if (_paths.isNotEmpty) {
      _paths.removeLast();
      notifyListeners();

      return true;
    }

    return false;
  }

  /// Clears all data.
  void clear() {
    _paths.clear();

    notifyListeners();
  }

  //TODO: Only landscape to landscape mode works correctly now. Add support for orientation switching.
  /// Handles canvas size changes.
  bool notifyDimension(Size size) {
    if (_areaSize == size) {
      return false;
    }

    if (_areaSize.isEmpty ||
        _areaSize.width == size.width ||
        _areaSize.height == size.height) {
      _areaSize = size;
      return false;
    }

    //TODO: iOS device holds pointer during rotation
    if (hasActivePath) {
      closePath();
    }

    if (!isFilled) {
      _areaSize = size;
      return false;
    }

    //final ratioX = size.width / _areaSize.width;
    final ratioY = size.height / _areaSize.height;
    final scale = ratioY;

    _areaSize = size;

    _paths.forEach((path) {
      path.setScale(scale);
    });

    //TODO: Called during rebuild, so notify must be postponed one frame - will be solved by widget/state
    Future.delayed(Duration(), () => notifyListeners());

    return true;
  }

  /// Converts dat to Map (json)
  /// Exported data can be restored via [HandSignatureControl.fromMap] factory or via [importData] method.
  Map<String, dynamic> toMap() => {
        'bounds': {
          'width': _areaSize.width,
          'height': _areaSize.height,
        },
        'paths':
            paths.map((p) => p.points.map((p) => p.toMap()).toList()).toList(),
        'threshold': threshold,
        'smoothRatio': smoothRatio,
        'velocityRange': velocityRange,
      };

  /// Converts data to [svg] String.
  /// [type] - data structure.
  String? toSvg({
    SignatureDrawType type = SignatureDrawType.shape,
    int width = 512,
    int height = 256,
    double border = 0.0,
    Color? color,
    double? strokeWidth,
    double? maxStrokeWidth,
    bool fit = false,
  }) {
    if (!isFilled) {
      return null;
    }

    params ??= SignaturePaintParams(
      color: Colors.black,
      strokeWidth: 1.0,
      maxStrokeWidth: 10.0,
    );

    color ??= params!.color;
    strokeWidth ??= params!.strokeWidth;
    maxStrokeWidth ??= params!.maxStrokeWidth;

    final bounds = PathUtil.boundsOf(_offsets, radius: maxStrokeWidth * 0.5);
    final fitBox =
        bounds.size.scaleToFit(Size(width.toDouble(), height.toDouble()));
    final rect = fit
        ? Rect.fromLTWH(0.0, 0.0, fitBox.width, fitBox.height)
        : Rect.fromLTWH(0.0, 0.0, width.toDouble(), height.toDouble());

    if (type == SignatureDrawType.line || type == SignatureDrawType.shape) {
      final data = PathUtil.fillData(
        _cubicLines,
        rect,
        bound: bounds,
        border: maxStrokeWidth + border,
      );

      if (type == SignatureDrawType.line) {
        return _exportPathSvg(data, rect.size, color, strokeWidth);
      } else {
        return _exportShapeSvg(
            data, rect.size, color, strokeWidth, maxStrokeWidth);
      }
    } else {
      final data = PathUtil.fill(
        _arcs,
        rect,
        bound: bounds,
        border: maxStrokeWidth + border,
      );

      return _exportArcSvg(data, rect.size, color, strokeWidth, maxStrokeWidth);
    }
  }

  /// Exports [svg] as simple line.
  String _exportPathSvg(
    List<List<CubicLine>> data,
    Size size,
    Color color,
    double strokeWidth,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buffer.writeln(
        '<svg width="${size.width}" height="${size.height}" xmlns="http://www.w3.org/2000/svg">');
    buffer.writeln(
        '<g stroke="${color.hexValue}" fill="none" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round" >');

    data.forEach((line) {
      buffer.write('<path d="M ${line[0].dx} ${line[0].dy}');
      line.forEach((path) => buffer.write(
          ' C ${path.cpStart.dx} ${path.cpStart.dy}, ${path.cpEnd.dx} ${path.cpEnd.dy}, ${path.end.dx} ${path.end.dy}'));
      buffer.writeln('" />');
    });

    buffer.writeln('</g>');
    buffer.writeln('</svg>');

    return buffer.toString();
  }

  /// Exports [svg] as a lot of arcs.
  String _exportArcSvg(
    List<CubicArc> data,
    Size size,
    Color color,
    double strokeWidth,
    double maxStrokeWidth,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buffer.writeln(
        '<svg width="${size.width}" height="${size.height}" xmlns="http://www.w3.org/2000/svg">');
    buffer.writeln(
        '<g stroke="${color.hexValue}" fill="none" stroke-linecap="round" stroke-linejoin="round" >');

    data.forEach((arc) {
      final strokeSize =
          strokeWidth + (maxStrokeWidth - strokeWidth) * arc.size;
      buffer.writeln(
          '<path d="M ${arc.dx} ${arc.dy} A 0 0, ${CubicArc._pi2}, 0, 0, ${arc.location.dx} ${arc.location.dy}" stroke-width="$strokeSize" />');
    });

    buffer.writeln('</g>');
    buffer.writeln('</svg>');

    return buffer.toString();
  }

  /// Exports [svg] as shape - 4 paths per line. Path is closed and filled with given color.
  String _exportShapeSvg(
    List<List<CubicLine>> data,
    Size size,
    Color color,
    double strokeWidth,
    double maxStrokeWidth,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>');
    buffer.writeln(
        '<svg width="${size.width}" height="${size.height}" xmlns="http://www.w3.org/2000/svg">');
    buffer.writeln('<g fill="${color.hexValue}">');

    data.forEach((lines) {
      if (lines.length == 1 && lines[0].isDot) {
        final dot = lines[0];
        buffer.writeln(
            '<circle cx="${dot.start.dx}" cy="${dot.start.dy}" r="${dot.startRadius(strokeWidth, maxStrokeWidth)}" />');
      } else {
        final firstLine = lines.first;
        final start =
            firstLine.start + firstLine.cpsUp(strokeWidth, maxStrokeWidth);
        buffer.write('<path d="M ${start.dx} ${start.dy}');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final d1 = line.cpsUp(strokeWidth, maxStrokeWidth);
          final d2 = line.cpeUp(strokeWidth, maxStrokeWidth);

          final cpStart = line.cpStart + d1;
          final cpEnd = line.cpEnd + d2;
          final end = line.end + d2;

          buffer.write(
              ' C ${cpStart.dx} ${cpStart.dy} ${cpEnd.dx} ${cpEnd.dy} ${end.dx} ${end.dy}');
        }

        final lastLine = lines.last;
        final half =
            lastLine.end + lastLine.cpeDown(strokeWidth, maxStrokeWidth);
        buffer.write(' L ${half.dx} ${half.dy}');

        for (int i = lines.length - 1; i > -1; i--) {
          final line = lines[i];
          final d3 = line.cpeDown(strokeWidth, maxStrokeWidth);
          final d4 = line.cpsDown(strokeWidth, maxStrokeWidth);

          final cpEnd = line.cpEnd + d3;
          final cpStart = line.cpStart + d4;
          final start = line.start + d4;

          buffer.write(
              ' C ${cpEnd.dx} ${cpEnd.dy} ${cpStart.dx} ${cpStart.dy} ${start.dx} ${start.dy}');
        }

        buffer.writeln(' z" />');

        buffer.writeln(
            '<circle cx="${firstLine.start.dx}" cy="${firstLine.start.dy}" r="${firstLine.startRadius(strokeWidth, maxStrokeWidth)}" />');
        buffer.writeln(
            '<circle cx="${lastLine.end.dx}" cy="${lastLine.end.dy}" r="${lastLine.endRadius(strokeWidth, maxStrokeWidth)}" />');
      }
    });

    buffer.writeln('</g>');
    buffer.writeln('</svg>');

    return buffer.toString();
  }

  /// Exports data to [Picture].
  ///
  /// If [fit] is enabled, the path will be normalized and scaled to fit given [width] and [height].
  Picture? toPicture({
    int width = 512,
    int height = 256,
    Color? color,
    Color? background,
    double? strokeWidth,
    double? maxStrokeWidth,
    double border = 0.0,
    bool fit = true,
  }) {
    if (!isFilled) {
      return null;
    }

    final pictureRect = Rect.fromLTRB(
      0.0,
      0.0,
      width.toDouble(),
      height.toDouble(),
    );

    params ??= SignaturePaintParams(
      color: Colors.black,
      strokeWidth: 1.0,
      maxStrokeWidth: 10.0,
    );

    color ??= params!.color;
    strokeWidth ??= params!.strokeWidth;
    maxStrokeWidth ??= params!.maxStrokeWidth;

    final canvasRect = Rect.fromLTRB(0, 0, _areaSize.width, _areaSize.height);
    final data = fit
        ? PathUtil.fill(
            _arcs,
            pictureRect,
            radius: maxStrokeWidth * 0.5,
            border: border,
          )
        : PathUtil.fill(
            _arcs,
            pictureRect,
            bound: canvasRect,
            border: border,
          );
    final path = CubicPath().._arcs.addAll(data);

    final recorder = PictureRecorder();
    final painter = PathSignaturePainter(
      paths: [path],
      color: color,
      width: strokeWidth,
      maxWidth: maxStrokeWidth,
      type: SignatureDrawType.arc,
    );

    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        Offset(0.0, 0.0),
        Offset(width.toDouble(), height.toDouble()),
      ),
    );

    if (background != null) {
      canvas.drawColor(background, BlendMode.src);
    }

    painter.paint(canvas, Size(width.toDouble(), height.toDouble()));

    return recorder.endRecording();
  }

  /// Exports data to raw image.
  ///
  /// If [fit] is enabled, the path will be normalized and scaled to fit given [width] and [height].
  Future<ByteData?> toImage({
    int width = 512,
    int height = 256,
    Color? color,
    Color? background,
    double? strokeWidth,
    double? maxStrokeWidth,
    double border = 32.0,
    ImageByteFormat format = ImageByteFormat.png,
    bool fit = false,
  }) async {
    final image = await toPicture(
      width: width,
      height: height,
      color: color,
      background: background,
      strokeWidth: strokeWidth,
      maxStrokeWidth: maxStrokeWidth,
      border: border,
      fit: fit,
    )?.toImage(width, height);

    if (image == null) {
      return null;
    }

    return image.toByteData(format: format);
  }

  /// Currently checks only equality of [paths].
  bool equals(HandSignatureControl other) {
    if (paths.length == other.paths.length) {
      for (int i = 0; i < paths.length; i++) {
        if (!paths[i].equals(other.paths[i])) {
          return false;
        }
      }

      return true;
    }

    return false;
  }

  @override
  void dispose() {
    _paths.clear();
    _activePath = null;

    super.dispose();
  }
}
