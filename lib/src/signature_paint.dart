import 'package:flutter/material.dart';

import '../signature.dart';

class HandSignaturePaint extends StatefulWidget {
  final HandSignatureControl control;
  final Color color;
  final double width;
  final double maxWidth;
  final SignatureDrawType type;
  final bool Function(Size size) onSize;

  const HandSignaturePaint({
    Key key,
    this.control,
    this.color: Colors.black,
    this.width: 1.0,
    this.maxWidth: 10.0,
    this.type: SignatureDrawType.shape,
    this.onSize,
  }) : super(key: key);

  @override
  _HandSignaturePaintState createState() => _HandSignaturePaintState();
}

class _HandSignaturePaintState extends State<HandSignaturePaint> {
  @override
  void initState() {
    super.initState();

    widget.control.params = SignaturePaintParams(
      color: widget.color,
      width: widget.width,
      maxWidth: widget.maxWidth,
    );

    widget.control.addListener(_updateState);
  }

  void _updateState() {
    setState(() {});
  }

  @override
  void didUpdateWidget(HandSignaturePaint oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.control != widget.control) {
      oldWidget.control.removeListener(_updateState);
      widget.control.addListener(_updateState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PathSignaturePainter(
        paths: widget.control.paths,
        color: widget.color,
        width: widget.width,
        maxWidth: widget.maxWidth,
        type: widget.type,
        onSize: widget.onSize,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();

    widget.control.removeListener(_updateState);
  }
}
