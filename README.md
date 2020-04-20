A Flutter plugin providing signature pad for drawing smooth signatures. Library is written in pure Dart/Flutter environment to provide support for all platforms..\
Easy to use library with variety of draw and export settings.

![Structure](https://raw.githubusercontent.com/RomanBase/hand_signature/master/doc/signature.png)

Signature pad drawing is based on Cubic Bézier curves.

---

**Usage**
```dart
    import 'package:hand_signature/signature.dart';
```

With **HandSignatureControl** and **HandSignaturePainterView** is possible to tweak some drawing aspects like stroke width, smoothing ratio or velocity weight.
```dart
    final control = HandSignatureControl(
      threshold: 3.0,
      smoothRatio: 0.65,
      velocityRange: 2.0,
    );

    final widget = HandSignaturePainterView(
      control: control,
      color: Colors.blueGrey,
      width: 1.0,
      maxWidth: 10.0,
      type: SignatureDrawType.shape,
    );
```

**HandSignatureControl** sets up 'math' to control input touch and handle control points of signature curve.\
- threshold: (LP) controls minimal distance between two points - higher distance creates smoother curve, but less precise. Higher distance also creates input draw lag, because last two points of 'open' curve is not drawn.
- smoothRatio: (0 - 1) controls how smooth curve will be - higher ratio creates smoother curve, but less precise. In most cases best results are with 0.5 - 0.75 ratio.
- velocityRange: (LP/milliseconds) controls curve size based on duration between two points. With higher velocityRange user must swing faster to draw thinner line.

**HandSignaturePainterView** sets up visual style of signature curve.\
- control: process input and handles math and stores raw data.
- color: line color.
- width: minimal width of line. Width at maximum swing speed (clamped by velocityRange).
- maxWidth: maximum width of line. Width at slowest swing speed.
- type: draw type of curve. Default and main draw type is **shape** - not so nice as **arc**, but has better performance. And **line** is simple path with uniform stroke width. 

---

**Export**\
Some properties can be modified during export, like canvas size, stroke min/max width and color.
There are more ways and more formats how to export signature. Most used are **svg** and **png** formats.
```dart
    final control = HandSignatureControl();

    final svg = control.toSvg();
    final png = control.toImage();
```

**Parsing**\
Resulting **svg** is possible to display in classic [flutter_svg](https://pub.dev/packages/flutter_svg) widget.\
Or use build in **HandSignatureView** for greater control.
```dart
    final widget = HandSignatureView.svg(
      data: svgString,
      strokeWidth: (width) => width * 0.35,
    );
```

---

**Contribution**\
Any contribution is highly welcomed.\
Library is in good condition, but still in early development.\
Mainly to improve smoothing and line weight to better match real signature.\
Remove dependency of [flutter_svg](https://pub.dev/packages/flutter_svg) and make library dependent only at [path_drawing](https://pub.dev/packages/path_drawing) or [path_parsing](https://pub.dev/packages/path_parsing).\
Performance can be always better..\
Also currently there are no tests or documentation.