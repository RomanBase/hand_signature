import 'package:flutter/material.dart';

import '../signature.dart';

/// A [StatefulWidget] that uses [CustomPaint] to render a hand signature.
/// It rebuilds automatically whenever the signature data managed by [HandSignatureControl] changes.
///
/// This widget is typically used internally by [HandSignature] and [HandSignatureView].
class HandSignaturePaint extends StatefulWidget {
  /// The controller that manages the signature paths and notifies listeners of changes.
  final HandSignatureControl control;

  /// The drawer responsible for rendering the signature paths on the canvas.
  final HandSignatureDrawer drawer;

  /// Optional callback that is invoked when the canvas size changes.
  ///
  /// TODO: This callback should ideally be handled within the State of this widget
  /// or by the [HandSignatureControl] itself, rather than being exposed here.
  final bool Function(Size size)? onSize;

  /// Creates a [HandSignaturePaint] widget.
  ///
  /// [key] Controls how one widget replaces another widget in the tree.
  /// [control] The [HandSignatureControl] instance that provides the signature data.
  /// [drawer] The [HandSignatureDrawer] instance that defines how the signature is painted.
  /// [onSize] An optional callback for canvas size changes.
  const HandSignaturePaint({
    Key? key,
    required this.control,
    required this.drawer,
    this.onSize,
  }) : super(key: key);

  @override
  _HandSignaturePaintState createState() => _HandSignaturePaintState();
}

/// The state class for [HandSignaturePaint].
///
/// This state subscribes to the [HandSignatureControl] to listen for changes
/// in signature data and triggers a rebuild of the widget when updates occur.
class _HandSignaturePaintState extends State<HandSignaturePaint> {
  @override
  void initState() {
    super.initState();
    // Add a listener to the control to trigger a rebuild on data changes.
    widget.control.addListener(_updateState);
  }

  /// Callback method to trigger a widget rebuild.
  void _updateState() {
    setState(() {});
  }

  @override
  void didUpdateWidget(HandSignaturePaint oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the control instance changes, update the listener.
    if (oldWidget.control != widget.control) {
      oldWidget.control.removeListener(_updateState);
      widget.control.addListener(_updateState);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use CustomPaint to draw the signature using PathSignaturePainter.
    return CustomPaint(
      painter: PathSignaturePainter(
        paths: widget.control.paths,
        drawer: widget.drawer,
        onSize: widget.onSize,
      ),
    );
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed to prevent memory leaks.
    widget.control.removeListener(_updateState);
    super.dispose();
  }
}
