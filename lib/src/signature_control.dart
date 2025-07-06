import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../signature.dart';
import 'utils.dart';

/// @Deprecated('Paint parameters are obsolete from 3.1.0 and will be removed in future versions. Use SignaturePathSetup instead.')
/// Paint settings.
/// This class is used for backwards compatibility.
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
  String get opacity => '${color.a}}';

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

/// Defines the setup parameters for a signature path, including smoothing, velocity, and pressure ratios.
class SignaturePathSetup {
  /// Minimal distance between two control points.
  final double threshold;

  /// Ratio of line smoothing.
  /// Don't have impact to performance. Values between 0 - 1.
  /// [0] - no smoothing, no flattening.
  /// [1] - best smoothing, but flattened.
  /// Best results are between: 0.5 - 0.85.
  final double smoothRatio;

  /// Clamps velocity.
  final double velocityRange;

  /// Ratio between pressure and velocity.
  /// 1.0 - only pressure, velocity is ignored
  /// 0.0 - only velocity, pressure is ignored
  /// 0.5 - balanced pressure and velocity
  final double pressureRatio;

  /// Additional arguments to setup path - typically used with custom {HandSignatureDrawer}
  /// Only primitives should be stored in args [String, num, List, Map] - just structs that are supported with jsonEncode/jsonDecode converter.
  final Map<String, dynamic>? args;

  const SignaturePathSetup({
    this.threshold = 3.0,
    this.smoothRatio = 0.65,
    this.velocityRange = 2.0,
    this.pressureRatio = 0.0,
    this.args,
  })  : assert(threshold > 0.0),
        assert(smoothRatio > 0.0 && smoothRatio <= 1.0),
        assert(velocityRange > 0.0),
        assert(pressureRatio >= 0.0 && pressureRatio <= 1.0);

  factory SignaturePathSetup.fromMap(Map<String, dynamic> data) =>
      SignaturePathSetup(
        threshold: data['threshold'],
        smoothRatio: data['smoothRatio'],
        velocityRange: data['velocityRange'],
        pressureRatio: data['pressureRatio'],
        args: data['args'],
      );

  Map<String, dynamic> toMap() => {
        'threshold': threshold,
        'smoothRatio': smoothRatio,
        'velocityRange': velocityRange,
        'pressureRatio': pressureRatio,
        if (args != null) 'args': args,
      };
}

/// Extended [Offset] point with [timestamp] and optional [pressure].
class OffsetPoint extends Offset {
  /// Timestamp of this point. Used to determine velocity to other points.
  final int timestamp;

  /// The pressure value at this point, if available.
  final double? pressure;

  /// Creates an [OffsetPoint] with the given coordinates, timestamp, and optional pressure.
  const OffsetPoint({
    required double dx,
    required double dy,
    required this.timestamp,
    this.pressure,
  }) : super(dx, dy);

  /// Creates an [OffsetPoint] from a standard [Offset] with the current timestamp and optional pressure.
  factory OffsetPoint.from(Offset offset, {double? pressure}) => OffsetPoint(
        dx: offset.dx,
        dy: offset.dy,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        pressure: pressure,
      );

  /// Creates an [OffsetPoint] from a map of data, typically used for deserialization.
  factory OffsetPoint.fromMap(Map<String, dynamic> data) => OffsetPoint(
        dx: data['x'],
        dy: data['y'],
        timestamp: data['t'],
        pressure: data['p'],
      );

  /// Converts this [OffsetPoint] to a map of data, typically used for serialization.
  Map<String, dynamic> toMap() => {
        'x': dx,
        'y': dy,
        't': timestamp,
        if (pressure != null) 'p': pressure,
      };

  /// Calculates the velocity between this point and a [other] (previous) point.
  /// Returns 0.0 if timestamps are the same to avoid division by zero.
  double velocityFrom(OffsetPoint other) => timestamp != other.timestamp
      ? distanceTo(other) / (timestamp - other.timestamp)
      : 0.0;

  @override
  OffsetPoint translate(double translateX, double translateY) {
    return OffsetPoint(
      dx: dx + translateX,
      dy: dy + translateY,
      timestamp: timestamp,
      pressure: pressure,
    );
  }

  @override
  OffsetPoint scale(double scaleX, double scaleY) {
    return OffsetPoint(
      dx: dx * scaleX,
      dy: dy * scaleY,
      timestamp: timestamp,
      pressure: pressure,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OffsetPoint &&
        other.dx == dx &&
        other.dy == dy &&
        other.timestamp == timestamp &&
        other.pressure == pressure;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, timestamp, pressure);
}

/// Represents a cubic Bezier curve segment, defined by a start point, end point, and two control points.
/// This class extends [Offset] to represent the starting point of the curve.
///
/// For more information on Bezier curves, refer to: https://cubic-bezier.com/
class CubicLine extends Offset {
  /// The starting point of the cubic Bezier curve.
  final OffsetPoint start;

  /// The first control point, influencing the curve's shape from the [start] point.
  final Offset cpStart;

  /// The second control point, influencing the curve's shape from the [end] point.
  final Offset cpEnd;

  /// The ending point of the cubic Bezier curve.
  final OffsetPoint end;

  /// The calculated velocity of the line segment.
  late double _velocity;

  /// The calculated distance between the start and end points.
  late double _distance;

  /// Cached 'Up' vector for the [start] point, used for shape calculations.
  Offset? _upStartVector;

  /// The 'Up' vector for the [start] point, calculated if not already cached.
  /// This vector is perpendicular to the curve's direction at the start.
  Offset get upStartVector =>
      _upStartVector ??
      (_upStartVector = start.directionTo(point(0.001)).rotate(-math.pi * 0.5));

  /// Cached 'Up' vector for the [end] point, used for shape calculations.
  Offset? _upEndVector;

  /// The 'Up' vector for the [end] point, calculated if not already cached.
  /// This vector is perpendicular to the curve's direction at the end.
  Offset get upEndVector =>
      _upEndVector ??
      (_upEndVector = end.directionTo(point(0.999)).rotate(math.pi * 0.5));

  /// The 'Down' vector for the [start] point, which is the [upStartVector] rotated by 180 degrees.
  Offset get _downStartVector => upStartVector.rotate(math.pi);

  /// The 'Down' vector for the [end] point, which is the [upEndVector] rotated by 180 degrees.
  Offset get _downEndVector => upEndVector.rotate(math.pi);

  /// The size ratio of the line at its starting point (typically 0.0 to 1.0).
  double startSize;

  /// The size ratio of the line at its ending point (typically 0.0 to 1.0).
  double endSize;

  /// Indicates if this line segment represents a 'dot' (i.e., start and end points are the same, and velocity is zero).
  bool get isDot => _velocity == 0.0;

  /// Creates a [CubicLine] segment.
  ///
  /// [start] The initial point of the curve.
  /// [end] The end point of the curve.
  /// [cpStart] The control point associated with the [start] vector.
  /// [cpEnd] The control point associated with the [end] vector.
  /// [upStartVector] An optional pre-calculated 'Up' vector for the start point.
  /// [upEndVector] An optional pre-calculated 'Up' vector for the end point.
  /// [startSize] The initial size ratio of the line at the beginning of the curve.
  /// [endSize] The final size ratio of the line at the end of the curve.
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

  /// Calculates the approximate length of the cubic curve with a given [accuracy].
  ///
  /// [accuracy] A value between 0 (fastest, raw accuracy) and 1 (slowest, most accurate).
  /// Returns the calculated length of the curve.
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

  /// Calculates a point on the cubic curve at a given parameter [t].
  ///
  /// [t] A value between 0 (start of the curve) and 1 (end of the curve).
  /// Returns the [Offset] representing the location on the curve at [t].
  Offset point(double t) {
    final rt = 1.0 - t;
    return (start * rt * rt * rt) +
        (cpStart * 3.0 * rt * rt * t) +
        (cpEnd * 3.0 * rt * t * t) +
        (end * t * t * t);
  }

  /// Calculates the velocity along this line segment.
  ///
  /// [accuracy] The accuracy for calculating the length of the curve.
  /// Returns the velocity, or 0.0 if start and end timestamps are the same.
  double velocity({double accuracy = 0.0}) => start.timestamp != end.timestamp
      ? length(accuracy: accuracy) / (end.timestamp - start.timestamp)
      : 0.0;

  /// Combines the line's intrinsic velocity with an [inVelocity] based on a [velocityRatio].
  ///
  /// [inVelocity] The incoming velocity to combine with.
  /// [velocityRatio] The ratio to weigh the line's intrinsic velocity (0.0 to 1.0).
  /// [maxFallOff] The maximum allowed difference between the combined velocity and [inVelocity].
  /// Returns the combined velocity.
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

  /// Converts this cubic line segment into a Flutter [Path] object.
  Path toPath() => Path()
    ..moveTo(dx, dy)
    ..cubicTo(cpStart.dx, cpStart.dy, cpEnd.dx, cpEnd.dy, end.dx, end.dy);

  /// Converts this cubic line into a list of [CubicArc] segments.
  /// This is used to approximate the curve with a series of arcs for drawing.
  ///
  /// [size] The base size for the arcs.
  /// [deltaSize] The change in size across the arc.
  /// [precision] The precision for generating arc segments (higher value means more segments).
  /// Returns a list of [CubicArc] objects.
  List<CubicArc> toArc({double? deltaSize, double precision = 0.5}) {
    final list = <CubicArc>[];

    final steps = (_distance * precision).floor().clamp(1, 30);

    Offset start = this.start;
    for (int i = 0; i < steps; i++) {
      final t = (i + 1) / steps;
      final loc = point(t);
      final width = startSize + (deltaSize ?? (endSize - startSize)) * t;

      list.add(CubicArc(
        start: start,
        location: loc,
        size: width,
      ));

      start = loc;
    }

    return list;
  }

  /// Converts this cubic line into a closed [Path] representing a filled shape.
  /// This is typically used for drawing thick, filled lines.
  ///
  /// [size] The base stroke width.
  /// [maxSize] The maximum stroke width.
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

  /// Returns the 'Up' offset for the start point, scaled by the start radius.
  Offset cpsUp(double size, double maxSize) =>
      upStartVector * startRadius(size, maxSize);

  /// Returns the 'Up' offset for the end point, scaled by the end radius.
  Offset cpeUp(double size, double maxSize) =>
      upEndVector * endRadius(size, maxSize);

  /// Returns the 'Down' offset for the start point, scaled by the start radius.
  Offset cpsDown(double size, double maxSize) =>
      _downStartVector * startRadius(size, maxSize);

  /// Returns the 'Down' offset for the end point, scaled by the end radius.
  Offset cpeDown(double size, double maxSize) =>
      _downEndVector * endRadius(size, maxSize);

  /// Returns the calculated radius for the start point based on [size], [maxSize], and [startSize].
  double startRadius(double size, double maxSize) =>
      _lerpRadius(size, maxSize, startSize);

  /// Returns the calculated radius for the end point based on [size], [maxSize], and [endSize].
  double endRadius(double size, double maxSize) =>
      _lerpRadius(size, maxSize, endSize);

  /// Performs linear interpolation to calculate a radius based on a given size, max size, and interpolation factor.
  ///
  /// [size] The base size.
  /// [maxSize] The maximum size.
  /// [t] The interpolation factor (0.0 to 1.0).
  /// Returns the interpolated radius.
  double _lerpRadius(double size, double maxSize, double t) =>
      (size + (maxSize - size) * t) * 0.5;

  /// Calculates a 'soft' control point for a [current] point based on its [previous] and [next] neighbors.
  /// This is used to create smooth curves.
  ///
  /// [current] The current [OffsetPoint] for which to calculate the control point.
  /// [previous] The preceding [OffsetPoint] in the path.
  /// [next] The succeeding [OffsetPoint] in the path.
  /// [reverse] If true, calculates the control point in reverse direction.
  /// [smoothing] A factor (0.0 to 1.0) controlling the smoothness of the curve.
  /// Returns the calculated soft control point as an [Offset].
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

/// Represents an arc segment between two points, typically used for drawing.
/// This class extends [Offset] to represent the starting point of the arc.
class CubicArc extends Offset {
  /// The ending location of the arc.
  final Offset location;

  /// The size of the line segment represented by this arc (typically 0.0 to 1.0).
  final double size;

  /// Generates a [Path] object representing this arc.
  Path get path => Path()
    ..moveTo(dx, dy)
    ..arcToPoint(location, rotation: pi2);

  /// Returns a [Rect] that encloses both the start and end points of the arc.
  Rect get rect => Rect.fromPoints(this, location);

  /// Creates a [CubicArc] instance.
  ///
  /// [start] The starting point of the arc.
  /// [location] The ending point of the arc.
  /// [size] The size ratio of the arc, typically between 0 and 1.
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

/// Manages a sequence of points to form a smooth, drawable path using cubic Bezier curves.
class CubicPath {
  /// The raw list of [OffsetPoint]s that define the path.
  final _points = <OffsetPoint>[];

  /// The list of [CubicLine] segments derived from the raw points, forming the smoothed path.
  final _lines = <CubicLine>[];

  /// The setup parameters for this path, including smoothing, velocity, and pressure ratios.
  final SignaturePathSetup setup;

  /// Returns an unmodifiable list of the raw [OffsetPoint]s that make up this path.
  List<OffsetPoint> get points => _points;

  /// Returns an unmodifiable list of the [CubicLine] segments that form this path.
  List<CubicLine> get lines => _lines;

  /// The first point in the path, or `null` if the path is empty.
  Offset? get _origin => _points.isNotEmpty ? _points[0] : null;

  /// The last point added to the path, or `null` if the path is empty.
  OffsetPoint? get _lastPoint =>
      _points.isNotEmpty ? _points[_points.length - 1] : null;

  /// Indicates whether the path contains any drawn lines.
  bool get isFilled => _lines.isNotEmpty;

  /// Indicates whether the path consists of a single 'dot' (a line with zero velocity).
  bool get isDot => lines.length == 1 && lines[0].isDot;

  /// The maximum velocity observed within this path.
  double _maxVelocity = 1.0;

  /// The current average velocity of the path being drawn.
  double _currentVelocity = 0.0;

  /// The current size (thickness) of the line based on velocity and pressure.
  double _currentSize = 0.0;

  /// Creates a [CubicPath] with the given [setup] parameters.
  CubicPath({
    this.setup = const SignaturePathSetup(),
  }) {
    _maxVelocity = setup.velocityRange;
  }

  List<CubicArc> toArcs() {
    final arcs = <CubicArc>[];

    for (final line in _lines) {
      arcs.addAll(line.toArc());
    }

    return arcs;
  }

  /// Adds a [CubicLine] segment to the path.
  /// This method updates the current velocity and size based on the new line.
  void _addLine(CubicLine line) {
    if (_lines.isEmpty) {
      if (_currentVelocity == 0.0) {
        _currentVelocity = line._velocity;
      }

      if (_currentSize == 0.0) {
        _currentSize =
            _lineSize(_currentVelocity, _maxVelocity, line.start.pressure);
      }
    } else {
      line._upStartVector = _lines.last.upEndVector;
    }

    _lines.add(line);

    final combinedVelocity =
        line.combineVelocity(_currentVelocity, maxFallOff: 0.125);
    final double endSize =
        _lineSize(combinedVelocity, _maxVelocity, line.end.pressure);

    if (combinedVelocity > _maxVelocity) {
      _maxVelocity = combinedVelocity;
    }

    line.startSize = _currentSize;
    line.endSize = endSize;

    //_arcs.addAll(line.toArc());

    _currentSize = endSize;
    _currentVelocity = combinedVelocity;
  }

  /// Adds a 'dot' (a single point line) to the path.
  /// This is used when the path consists of a single, stationary point.
  void _addDot(CubicLine line) {
    final size = 0.25 +
        _lineSize(_currentVelocity, _maxVelocity, line.end.pressure) * 0.5;
    line.startSize = size;
    line.endSize = size;

    _lines.add(line);
    //_arcs.addAll(line.toArc(deltaSize:  0.0));
  }

  /// Calculates the line size (thickness) based on the given [velocity], maximum velocity [max], and optional [pressure].
  double _lineSize(double velocity, double max, double? pressure) {
    velocity /= max;

    if (pressure != null) {
      final v = (1.0 - velocity) * (1.0 - setup.pressureRatio);
      final p = pressure * setup.pressureRatio;

      return (v + p).clamp(0.0, 1.0);
    }

    return 1.0 - velocity.clamp(0.0, 1.0);
  }

  /// Starts a new path at the given [point].
  /// This method must be called before [add] or [end].
  ///
  /// [point] The initial [Offset] for the path.
  /// [velocity] The initial velocity of the path.
  /// [pressure] The initial pressure at the starting point.
  void begin(Offset point, {double velocity = 0.0, double? pressure}) {
    _points.add(point is OffsetPoint
        ? point
        : OffsetPoint.from(point, pressure: pressure));
    _currentVelocity = velocity;
  }

  /// Adds a new [point] to the active path.
  /// This method calculates new cubic line segments and updates the path.
  ///
  /// [point] The new [Offset] to add to the path.
  /// [pressure] The pressure at the new point.
  void add(Offset point, {double? pressure}) {
    assert(_origin != null);

    final nextPoint = point is OffsetPoint
        ? point
        : OffsetPoint.from(point, pressure: pressure);

    if (_lastPoint == null ||
        _lastPoint!.distanceTo(nextPoint) < setup.threshold) {
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
      smoothing: setup.smoothRatio,
    );

    final cpEnd = CubicLine.softCP(
      end,
      previous: start,
      next: next,
      smoothing: setup.smoothRatio,
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

  /// Ends the active path at the given [point].
  /// This method finalizes the path segments and handles cases for very short paths (dots or single lines).
  ///
  /// [point] The final [Offset] for the path.
  /// [pressure] The pressure at the final point.
  /// Returns `true` if the path was successfully ended and is valid, `false` otherwise.
  bool end({Offset? point, double? pressure}) {
    if (point != null) {
      add(point, pressure: pressure);
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

  /// Scales the entire path by a given [ratio].
  /// This method updates all points, arcs, and lines within the path.
  void setScale(double ratio) {
    if (!isFilled) {
      return;
    }

    final pointsData = PathUtil.scale<OffsetPoint>(_points, ratio);
    _points
      ..clear()
      ..addAll(pointsData);

    final lineData = PathUtil.scale<CubicLine>(_lines, ratio);
    _lines
      ..clear()
      ..addAll(lineData);
  }

  CubicPath copy() => CubicPath(setup: setup)
    .._points.addAll(_points)
    .._lines.addAll(_lines);

  /// Clears all data associated with this path, effectively resetting it.
  void clear() {
    _points.clear();
    _lines.clear();
  }

  /// Checks if this [CubicPath] is equal to [other] based on their raw points.
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

/// A [ChangeNotifier] that controls the drawing and manipulation of a hand signature.
/// It manages the active paths, their setup, and provides methods for
/// starting, altering, closing, importing, and exporting signature data.
class HandSignatureControl extends ChangeNotifier {
  /// A private list storing all completed [CubicPath]s that form the signature.
  final _paths = <CubicPath>[];

  /// A function that provides the [SignaturePathSetup] for new paths.
  late SignaturePathSetup Function() setup;

  /// Optional visual parameters for line painting, primarily for backwards compatibility.
  SignaturePaintParams? params;

  /// The currently active (unfinished) [CubicPath] being drawn.
  CubicPath? _activePath;

  /// The size of the canvas area where the signature is drawn.
  /// TODO: This property should ideally be part of [SignaturePaintParams] or a dedicated rendering context.
  Size _areaSize = Size.zero;

  /// Returns an unmodifiable list of all completed [CubicPath]s.
  List<CubicPath> get paths => _paths;

  /// Returns a lazy list of all raw [Offset] control points from all paths.
  List<List<Offset>> get _offsets => _paths.map((data) => data.points).toList();

  /// Returns a lazy list of all [CubicLine] segments from all paths.
  List<List<CubicLine>> get _cubicLines =>
      _paths.map((data) => data.lines).toList();

  /// Returns a flattened list of all [CubicLine] segments across all paths.
  List<CubicLine> get lines => _paths.expand((data) => data.lines).toList();

  /// Indicates whether there is an active (unfinished) path being drawn.
  bool get hasActivePath => _activePath != null;

  /// Indicates whether any signature data has been drawn (i.e., if there are any completed paths).
  bool get isFilled => _paths.isNotEmpty;

  /// Controls input from [HandSignature] and creates smooth signature path.
  ///
  /// [setup] dynamic setup for every new path. Setup can be also set later.
  /// [initialSetup] default setup for each path (ignored if [setup] is provided).
  ///
  /// [threshold] minimal distance between two points.
  /// [smoothRatio] smoothing ratio of curved parts.
  /// [velocityRange] controls velocity speed and dampening between points (only Shape and Arc drawing types using this property to control line width). aka how fast si signature drawn..
  /// [pressureRatio] ratio between pressure and velocity. 0.0 = only velocity, 1.0 = only pressure
  HandSignatureControl({
    @Deprecated('Use {setup} or {initialSetup}') double threshold = 3.0,
    @Deprecated('Use {setup} or {initialSetup}') double smoothRatio = 0.65,
    @Deprecated('Use {setup} or {initialSetup}') double velocityRange = 2.0,
    @Deprecated('Use {setup} or {initialSetup}') double pressureRatio = 0.0,
    SignaturePathSetup Function()? setup,
    SignaturePathSetup? initialSetup,
  }) {
    this.setup = setup ??
        () =>
            initialSetup ??
            SignaturePathSetup(
              threshold: threshold,
              smoothRatio: smoothRatio,
              velocityRange: velocityRange,
              pressureRatio: pressureRatio,
            );
  }

  factory HandSignatureControl.fromMap(Map<String, dynamic> data) =>
      HandSignatureControl()..import(data);

  /// Sets setup for next Path
  void setSetup(SignaturePathSetup setup) => this.setup = () => setup;

  /// Starts new line at given [point].
  void startPath(Offset point, {double? pressure}) {
    assert(!hasActivePath);

    _activePath = CubicPath(setup: setup.call());

    _activePath!.begin(
      point,
      velocity: _paths.isNotEmpty ? _paths.last._currentVelocity : 0.0,
      pressure: pressure,
    );

    _paths.add(_activePath!);
  }

  /// Adds [point[ to active path.
  void alterPath(Offset point, {double? pressure}) {
    assert(hasActivePath);

    _activePath?.add(
      point,
      pressure: pressure,
    );

    notifyListeners();
  }

  /// Closes active path at given [point].
  void closePath({Offset? point, double? pressure}) {
    assert(hasActivePath);

    final valid = _activePath?.end(
      point: point,
      pressure: pressure,
    );

    if (valid == false) {
      _paths.removeLast();
    }

    _activePath = null;

    notifyListeners();
  }

  /// Imports given [paths] and alters current signature data.
  @Deprecated('User {addPath}')
  void importPath(List<CubicPath> paths, [Size? bounds]) =>
      addPath(paths, bounds);

  /// Imports given [paths] and alters current signature data.
  void addPath(List<CubicPath> paths, [Size? bounds]) {
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

  /// Removes last Path.
  /// returns removed [CubicPath].
  CubicPath? stepBack() {
    if (_paths.isNotEmpty) {
      final path = _paths.removeLast();
      notifyListeners();

      return path;
    }

    return null;
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

    //TODO: Called during rebuild, so notify must be postponed one frame - should be solved by widget/state
    Future.delayed(Duration(), () => notifyListeners());

    return true;
  }

  @Deprecated('User {import}')
  void importData(Map data) => import(data);

  /// Expects [data] from [toMap].
  void import(Map data) {
    final list = <CubicPath>[];

    final v2 = (data['version'] ?? 1) == 2;
    final bounds = Size(data['bounds']['width'], data['bounds']['height']);
    final paths = data['paths'] as Iterable;
    final setups = data['setup'] as Iterable?;

    if (v2) {
      assert(setups != null);
      assert(paths.length == setups!.length);
    } else {
      final threshold = data['threshold'];
      final smoothRatio = data['smoothRatio'];
      final velocityRange = data['velocityRange'];

      setup = () => SignaturePathSetup(
            threshold: threshold,
            smoothRatio: smoothRatio,
            velocityRange: velocityRange,
          );
    }

    final count = paths.length;

    for (int i = 0; i < count; i++) {
      final points = List.from(paths.elementAt(i));
      final setup =
          v2 ? SignaturePathSetup.fromMap(setups!.elementAt(i)) : this.setup();

      final cp = CubicPath(setup: setup);

      cp.begin(OffsetPoint.fromMap(points[0]));
      points.skip(1).forEach((element) => cp.add(OffsetPoint.fromMap(element)));
      cp.end();

      list.add(cp);
    }

    addPath(list, bounds);
  }

  /// Converts dat to Map (json)
  /// Exported data can be restored via [HandSignatureControl.fromMap] factory or via [import] method.
  Map<String, dynamic> toMap() => {
        'version': 2,
        'bounds': {
          'width': _areaSize.width,
          'height': _areaSize.height,
        },
        'paths':
            paths.map((p) => p.points.map((p) => p.toMap()).toList()).toList(),
        'setup': paths.map((p) => p.setup.toMap()).toList(),
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

    final data = PathUtil.fillData(
      _cubicLines,
      rect,
      bound: bounds,
      border: maxStrokeWidth + border,
    );

    switch (type) {
      case SignatureDrawType.line:
        return _exportPathSvg(data, rect.size, color, strokeWidth);
      case SignatureDrawType.shape:
        return _exportShapeSvg(
            data, rect.size, color, strokeWidth, maxStrokeWidth);
      case SignatureDrawType.arc:
        final arcs = <CubicArc>[];

        for (final lines in data) {
          for (final line in lines) {
            arcs.addAll(line.toArc());
          }
        }

        return _exportArcSvg(
            arcs, rect.size, color, strokeWidth, maxStrokeWidth);
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
          '<path d="M ${arc.dx} ${arc.dy} A 0 0, $pi2, 0, 0, ${arc.location.dx} ${arc.location.dy}" stroke-width="$strokeSize" />');
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
    HandSignatureDrawer? drawer,
    double border = 0.0,
    bool fit = false,
  }) {
    if (!isFilled) {
      return null;
    }

    final outputArea =
        Rect.fromLTWH(0.0, 0.0, width.toDouble(), height.toDouble());

    params ??= SignaturePaintParams(
      color: Colors.black,
      strokeWidth: 1.0,
      maxStrokeWidth: 10.0,
    );

    maxStrokeWidth ??= params!.maxStrokeWidth;

    final bounds = PathUtil.boundsOf(_offsets, radius: maxStrokeWidth * 0.5);

    final data = PathUtil.fillData(
      _cubicLines,
      outputArea,
      bound: fit
          ? bounds
          : bounds.size
              .scaleToFit(Size(width.toDouble(), height.toDouble()))
              .toRect(),
      border: maxStrokeWidth + border,
    );

    int i = 0;
    final painter = PathSignaturePainter(
      paths: paths
          .map((e) => CubicPath(setup: e.setup).._lines.addAll(data[i++]))
          .toList(),
      drawer: drawer ??
          ArcSignatureDrawer(
            color: color ?? params!.color,
            width: strokeWidth ?? params!.strokeWidth,
            maxWidth: maxStrokeWidth,
          ),
    );

    final recorder = PictureRecorder();
    final canvas = Canvas(
      recorder,
      outputArea,
    );

    if (background != null) {
      canvas.drawColor(background, BlendMode.src);
    }

    painter.paint(canvas, outputArea.size);

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
    HandSignatureDrawer? drawer,
    double border = 0.0,
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
      drawer: drawer,
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
