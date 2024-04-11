import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../signature.dart';

/// Wraps [HandSignaturePaint] to paint signature. And [RawGestureDetector] to send input to [HandSignatureControl].
class HandSignature extends StatelessWidget {
  /// Controls path creation.
  final HandSignatureControl control;

  /// Colors of path.
  final Color color;

  /// Minimal size of path.
  final double width;

  /// Maximal size of path.
  final double maxWidth;

  /// Path type.
  final SignatureDrawType type;

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
  HandSignature({
    Key? key,
    required this.control,
    this.color = Colors.black,
    this.width = 1.0,
    this.maxWidth = 10.0,
    this.type = SignatureDrawType.shape,
    this.onPointerDown,
    this.onPointerUp,
    this.supportedDevices,
  }) : super(key: key);

  void _startPath(Offset point) {
    if (!control.hasActivePath) {
      onPointerDown?.call();
      control.startPath(point);
    }
  }

  void _endPath(Offset point) {
    if (control.hasActivePath) {
      control.closePath();
      onPointerUp?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          _SingleGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_SingleGestureRecognizer>(
            () => _SingleGestureRecognizer(
                debugOwner: this, supportedDevices: supportedDevices),
            (instance) {
              instance.onStart = (position) => _startPath(position);
              instance.onUpdate = (position) => control.alterPath(position);
              instance.onEnd = (position) => _endPath(position);
            },
          ),
        },
        child: HandSignaturePaint(
          control: control,
          color: color,
          strokeWidth: width,
          maxStrokeWidth: maxWidth,
          type: type,
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

  ValueChanged<Offset>? onStart;
  ValueChanged<Offset>? onUpdate;
  ValueChanged<Offset>? onEnd;

  bool pointerActive = false;

  _SingleGestureRecognizer({
    super.debugOwner,
    Set<PointerDeviceKind>? supportedDevices,
  }) : super(
          supportedDevices:
              supportedDevices ?? PointerDeviceKind.values.toSet(),
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
      onUpdate?.call(event.localPosition);
    } else if (event is PointerDownEvent) {
      pointerActive = true;
      onStart?.call(event.localPosition);
    } else if (event is PointerUpEvent) {
      pointerActive = false;
      onEnd?.call(event.localPosition);
    } else if (event is PointerCancelEvent) {
      pointerActive = false;
      onEnd?.call(event.localPosition);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
