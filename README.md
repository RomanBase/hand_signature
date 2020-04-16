A Flutter plugin providing signature pad for drawing smooth signatures. Library is written in pure Dart/Flutter environment to provide support for all platforms..\
Easy to use library with variety of draw and export settings.

![Structure](https://raw.githubusercontent.com/RomanBase/hand_signature/master/doc/signature.png)

Signature pad drawing is based on Cubic Bézier curves.

---

**Usage**
```dart
    import 'package:hand_signature/signature.dart';
```

With **HandSignatureControl** and **HandSignaturePainterView** is possible to tweak some aspects of signature like stroke width, smoothing ratio or velocity weight.
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
    );
```

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
Also currently there are no tests or documentation.