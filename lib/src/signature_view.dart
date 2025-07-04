import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../signature.dart';

typedef _GestureEvent = Function(Offset position, double pressure);

/// A widget that provides a canvas for drawing hand signatures.
/// It combines [HandSignaturePaint] for rendering and [RawGestureDetector] for input handling,
/// sending gesture events to a [HandSignatureControl].
class HandSignature extends StatelessWidget {
  /// The controller that manages the creation and manipulation of signature paths.
  final HandSignatureControl control;

  /// @Deprecated('This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the drawing type and style.')
  /// The type of signature path to draw.
  @Deprecated(
      'This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the drawing type and style.')
  final SignatureDrawType type;

  /// @Deprecated('This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the drawing color.')
  /// The single color used for painting the signature.
  @Deprecated(
      'This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the drawing color.')
  final Color color;

  /// @Deprecated('This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the minimal stroke width.')
  /// The minimal stroke width of the signature path.
  @Deprecated(
      'This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the minimal stroke width.')
  final double width;

  /// @Deprecated('This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the maximal stroke width.')
  /// The maximal stroke width of the signature path.
  @Deprecated(
      'This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the maximal stroke width.')
  final double maxWidth;

  /// The [HandSignatureDrawer] responsible for rendering the signature.
  /// If `null`, a default drawer will be created based on the deprecated `type`, `color`, `width`, and `maxWidth` properties.
  final HandSignatureDrawer? drawer;

  /// The set of [PointerDeviceKind]s that this widget should recognize.
  ///
  /// For example, to only accept stylus input:
  /// ```dart
  /// supportedDevices: {
  ///   PointerDeviceKind.stylus,
  /// }
  /// ```
  /// If `null`, it accepts input from all pointer device types.
  final Set<PointerDeviceKind>? supportedDevices;

  /// Optional callback function invoked when a new signature path drawing starts (pointer down event).
  final VoidCallback? onPointerDown;

  /// Optional callback function invoked when a signature path drawing ends (pointer up or cancel event).
  final VoidCallback? onPointerUp;

  /// Creates a [HandSignature] widget.
  ///
  /// [key] Controls how one widget replaces another widget in the tree.
  /// [control] The [HandSignatureControl] instance to manage the signature data.
  /// [type] The deprecated drawing type for the signature.
  /// [color] The deprecated color for the signature.
  /// [width] The deprecated minimal width for the signature.
  /// [maxWidth] The deprecated maximal width for the signature.
  /// [drawer] The custom drawer to use for rendering the signature.
  /// [onPointerDown] Callback for when drawing starts.
  /// [onPointerUp] Callback for when drawing ends.
  /// [supportedDevices] The set of pointer device types to recognize.
  const HandSignature({
    Key? key,
    required this.control,
    @Deprecated(
        'This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the drawing type and style.')
    this.type = SignatureDrawType.shape,
    @Deprecated(
        'This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the drawing color.')
    this.color = Colors.black,
    @Deprecated(
        'This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the minimal stroke width.')
    this.width = 1.0,
    @Deprecated(
        'This property is deprecated since 3.1.0. Use the `drawer` property instead to specify the maximal stroke width.')
    this.maxWidth = 10.0,
    this.drawer,
    this.onPointerDown,
    this.onPointerUp,
    this.supportedDevices,
  }) : super(key: key);

  void _startPath(Offset point, double pressure) {
    if (!control.hasActivePath) {
      onPointerDown?.call();
      control.startPath(point, pressure: pressure);
    }
  }

  void _endPath(Offset point, double pressure) {
    if (control.hasActivePath) {
      control.closePath(pressure: pressure);
      onPointerUp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    control.params = SignaturePaintParams(
      color: color,
      strokeWidth: width,
      maxStrokeWidth: maxWidth,
    );

    return ClipRRect(
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          _SingleGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_SingleGestureRecognizer>(
            () => _SingleGestureRecognizer(
                debugOwner: this, supportedDevices: supportedDevices),
            (instance) {
              instance.onStart =
                  (position, pressure) => _startPath(position, pressure);
              instance.onUpdate = (position, pressure) =>
                  control.alterPath(position, pressure: pressure);
              instance.onEnd =
                  (position, pressure) => _endPath(position, pressure);
            },
          ),
        },
        child: HandSignaturePaint(
          control: control,
          drawer: drawer ??
              switch (type) {
                SignatureDrawType.line =>
                  LineSignatureDrawer(color: color, width: width),
                SignatureDrawType.arc => ArcSignatureDrawer(
                    color: color, width: width, maxWidth: maxWidth),
                SignatureDrawType.shape => ShapeSignatureDrawer(
                    color: color, width: width, maxWidth: maxWidth),
              },
          onSize: control.notifyDimension,
        ),
      ),
    );
  }
}

/// A custom [GestureRecognizer] that processes only a single input pointer
/// for signature drawing. It extends [OneSequenceGestureRecognizer] to ensure
/// that only one gesture is recognized at a time.
class _SingleGestureRecognizer extends OneSequenceGestureRecognizer {
  @override
  String get debugDescription => 'single_gesture_recognizer';

  /// Callback function for when a pointer starts interacting with the widget.
  _GestureEvent? onStart;

  /// Callback function for when a pointer moves while interacting with the widget.
  _GestureEvent? onUpdate;

  /// Callback function for when a pointer stops interacting with the widget.
  _GestureEvent? onEnd;

  /// A flag indicating whether a pointer is currently active (down).
  bool pointerActive = false;

  /// Creates a [_SingleGestureRecognizer].
  ///
  /// [debugOwner] The object that is debugging this recognizer.
  /// [supportedDevices] The set of [PointerDeviceKind]s that this recognizer should respond to.
  /// If `null`, it defaults to all available pointer device kinds.
  _SingleGestureRecognizer({
    super.debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(
          supportedDevices:
              supportedDevices ?? PointerDeviceKind.values.toSet(),
        );

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Only allow a new pointer if no other pointer is currently active.
    if (pointerActive) {
      return;
    }
    // Start tracking the pointer.
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    // Handle different types of pointer events.
    if (event is PointerMoveEvent) {
      // If it's a move event, call the onUpdate callback.
      onUpdate?.call(event.localPosition, event.pressure);
    } else if (event is PointerDownEvent) {
      // If it's a down event, set pointer as active and call onStart.
      pointerActive = true;
      onStart?.call(event.localPosition, event.pressure);
    } else if (event is PointerUpEvent) {
      // If it's an up event, set pointer as inactive and call onEnd.
      pointerActive = false;
      onEnd?.call(event.localPosition, event.pressure);
    } else if (event is PointerCancelEvent) {
      // If the pointer interaction is cancelled, set pointer as inactive and call onEnd.
      pointerActive = false;
      onEnd?.call(event.localPosition, event.pressure);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    // No specific action needed when the last pointer stops tracking.
  }
}
