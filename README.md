A Flutter plugin providing Signature Pad for drawing smooth signatures. Library is written in pure Dart/Flutter environment to provide support for all platforms..\
Easy to use library with variety of draw and export settings. Also supports SVG files.

![Structure](https://raw.githubusercontent.com/RomanBase/hand_signature/master/doc/signature.png)

Signature pad drawing is based on Cubic Bézier curves.\
Offers to choose between performance and beauty mode.

---

**Usage**
```dart
    import 'package:hand_signature/signature.dart';
```

With **HandSignatureControl** and **HandSignature** is possible to tweak some drawing aspects like stroke width, smoothing ratio or velocity weight.
```dart
    final control = HandSignatureControl(
      threshold: 3.0,
      smoothRatio: 0.65,
      velocityRange: 2.0,
    );

    final widget = HandSignature(
      control: control,
      color: Colors.blueGrey,
      width: 1.0,
      maxWidth: 10.0,
      type: SignatureDrawType.shape,
    );
```

**HandSignatureControl** sets up 'math' to control input touches and handles control points of signature curve.
- threshold: (LP) controls minimal distance between two points - higher distance creates smoother curve, but less precise. Higher distance also creates bigger input draw lag.
- smoothRatio: (0 - 1) controls how smooth curve will be - higher ratio creates smoother curve, but less precise. In most of cases are best results with values between 0.5 - 0.75.
- velocityRange: (LP per millisecond) controls curve size based on distance and duration between two points. Thin line - fast move, thick line - slow move. With higher velocityRange user must swing faster to draw thinner line.
- reverseVelocity: swaps stroke width. Thin line - slow move, thick line - fast move. Simply swaps min/max size based on velocity. 

**HandSignature** sets up visual style of signature curve.
- control: processes input, handles math and stores raw data.
- color: just color of line.
- strokeWidth: minimal width of line. Width at maximum swing speed (clamped by velocityRange).
- maxStrokeWidth: maximum width of line. Width at slowest swing speed.
- type: draw type of curve. Default and main draw type is **shape** - not so nice as **arc**, but has better performance. And **line** is simple path with uniform stroke width. 
  - line: basic Bezier line with best performance.
  - shape: like Ink drawn signature with still pretty good performance.
  - arc: beauty mode for Ink styled signature.
---

**Export**\
Properties, like canvas size, stroke min/max width and color can be modified during export.\
There are more ways and more formats how to export signature, most used ones are **svg** and **png** formats.
```dart
    final control = HandSignatureControl();

    final svg = control.toSvg();
    final png = control.toImage();
    final json = control.toMap();
    
    control.importData(json);
```
**Svg**: SignatureDrawType **shape** generates reasonably small file and is read well by all programs. On the other side **arc** generates really big svg file and some programs can have hard times handling so much objects. **Line** is simple Bezier Curve.\
**Image**: Export to image supports **ImageByteFormat** and provides png or raw rgba data.\
**Json/Map**: Exports current state - raw data that can be used later to restore state.

**Parsing and drawing saved SVG**\
Exported **svg** String is possible to display in another lib like: [flutter_svg](https://pub.dev/packages/flutter_svg).