import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../signature.dart';

typedef _GestureEvent = Function(Offset position, double pressure);

/// Wraps [HandSignaturePaint] to paint signature. And [RawGestureDetector] to send input to [HandSignatureControl].
class HandSignature extends StatelessWidget {
  /// Controls path creation.
  final HandSignatureControl control;

  /// Type of signature path.
  @Deprecated('Use {drawer}')
  final SignatureDrawType type;

  /// Single color of paint.
  @Deprecated('Use {drawer}')
  final Color color;

  /// Minimal size of path.
  @Deprecated('Use {drawer}')
  final double width;

  /// Maximal size of path.
  @Deprecated('Use {drawer}')
  final double maxWidth;

  final HandSignatureDrawer? drawer;

  /// The set of pointer device types to recognize, e.g., touch, stylus.
  /// Example:
  /// ```
  /// supportedDevices: {
  ///   PointerDeviceKind.stylus,
  /// }
  /// ```
  /// If null, it accepts all pointer devices.
  final Set<PointerDeviceKind>? supportedDevices;

  /// Callback when path drawing starts.
  final VoidCallback? onPointerDown;

  /// Callback when path drawing ends.
  final VoidCallback? onPointerUp;

  /// Draws [Path] based on input and stores data in [control].
  const HandSignature({
    Key? key,
    required this.control,
    @Deprecated('Use {drawer}') this.type = SignatureDrawType.shape,
    @Deprecated('Use {drawer}') this.color = Colors.black,
    @Deprecated('Use {drawer}') this.width = 1.0,
    @Deprecated('Use {drawer}') this.maxWidth = 10.0,
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
          _SingleGestureRecognizer: GestureRecognizerFactoryWithHandlers<_SingleGestureRecognizer>(
            () => _SingleGestureRecognizer(debugOwner: this, supportedDevices: supportedDevices),
            (instance) {
              instance.onStart = (position, pressure) => _startPath(position, pressure);
              instance.onUpdate = (position, pressure) => control.alterPath(position, pressure: pressure);
              instance.onEnd = (position, pressure) => _endPath(position, pressure);
            },
          ),
        },
        child: HandSignaturePaint(
          control: control,
          drawer: drawer ??
              switch (type) {
                SignatureDrawType.line => LineSignatureDrawer(color: color, width: width),
                SignatureDrawType.arc => ArcSignatureDrawer(color: color, width: width, maxWidth: maxWidth),
                SignatureDrawType.shape => ShapeSignatureDrawer(color: color, width: width, maxWidth: maxWidth),
              },
          onSize: control.notifyDimension,
        ),
      ),
    );
  }
}

/// [GestureRecognizer] that allows just one input pointer.
class _SingleGestureRecognizer extends OneSequenceGestureRecognizer {
  @override
  String get debugDescription => 'single_gesture_recognizer';

  _GestureEvent? onStart;
  _GestureEvent? onUpdate;
  _GestureEvent? onEnd;

  bool pointerActive = false;

  _SingleGestureRecognizer({
    super.debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(
          supportedDevices: supportedDevices ?? PointerDeviceKind.values.toSet(),
        );

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (pointerActive) {
      return;
    }

    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onUpdate?.call(event.localPosition, event.pressure);
    } else if (event is PointerDownEvent) {
      pointerActive = true;
      onStart?.call(event.localPosition, event.pressure);
    } else if (event is PointerUpEvent) {
      pointerActive = false;
      onEnd?.call(event.localPosition, event.pressure);
    } else if (event is PointerCancelEvent) {
      pointerActive = false;
      onEnd?.call(event.localPosition, event.pressure);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
