# Hand Signature

A Flutter plugin providing a Signature Pad for drawing smooth signatures. This library is written in
a pure Dart/Flutter environment to provide support for all platforms. It's easy to use, with a
variety of drawing and export settings, and also supports SVG files.

![Signature](https://raw.githubusercontent.com/RomanBase/hand_signature/master/doc/signature.png)

The signature pad drawing is based on Cubic Bézier curves and offers a choice between performance
and 'beauty' modes.

---

## Features

- **Cross-Platform:** Works on any platform supported by Flutter.
- **Customizable:** Adjust stroke width, color, and smoothing.
- **Multiple Drawing Types:** Choose between `line`, `shape`, and `arc` presets for different visual
  styles. It's also possible to implement custom drawing experience.
- **Velocity and Pressure Based Stroke:** The thickness of the line can vary based on the drawing
  speed.
- **Export Options:** Export signatures as PNG, SVG, or raw data (JSON/Map).
- **Import/Export:** Save and load signature data state.

---

## Implement the Signature Pad:

Use `HandSignatureControl` to manage the drawing logic and `HandSignature` to display the pad.

```dart
// Create a control instance
final control = HandSignatureControl(
  initialSetup: CubicPathSetup(
      threshold: 3.0,
      smoothRatio: 0.65,
      velocityRange: 2.0,
      pressureRatio: 0.0,
      args: {'color': 'red'}
  ),
);

// Create the signature pad widget
final widget = HandSignature(
  control: control,
  drawer: ShapeSignatureDrawer(
    color: Colors.blueGrey,
    width: 1.0,
    maxWidth: 10.0,
  ),
);
```

---

## `HandSignatureControl`

This class handles the "math" behind the signature, controlling input touches and managing the
control points of the signature curve. Setup was moved to `CubicPathSetup` and is stored per path.

- `threshold`: (LP) Controls the minimal distance between two points. A higher distance creates a
  smoother, but less precise, curve and may introduce a slight drawing lag.
- `smoothRatio`: (0 - 1) Controls how smooth the curve will be. A higher ratio creates a smoother,
  but less precise, curve. The best results are typically between 0.5 and 0.75.
- `velocityRange`: (LP per millisecond) Controls the curve size based on the distance and duration
  between two points. A thin line corresponds to a fast movement, while a thick line corresponds to
  a slow movement. With a higher `velocityRange`, the user must move the pointer faster to draw a
  thinner line.
- `pressureRatio`: (0 - 1) Ratio between pressure and velocity. 0.0 = only velocity, 1.0 = only
  pressure.

---

## `HandSignature`

This widget handles the visual style of the signature curve.

- `control`: The `HandSignatureControl` that processes input and stores the raw data.
- `drawer`: The `HandSignatureDrawer` that handles the painting of the signature.
  - Comes with prebuild Drawers: 
    - `LineSignatureDrawer`: Basic line with single line width.
    - `ShapeSignatureDrawer`: Default drawer, mimics ink pen. Various line with based on velocity and/or pressure. Also good for exporting in svg.
    - `ArcSignatureDrawer`: Mimics ink pen, less performant then Shape drawer. Default drawer when exporting toImage.
    - `DynamicSignatureDrawer`: Dynamically selects the drawing type based on provided args {'type' = 'shape', 'color' = 0xFFAA00BB, 'width' = 2.0}
    - `MultiSignatureDrawer`: Combines multiple drawers, allowing for complex effects

### Custom Drawer

You can create a custom drawer by extending `HandSignatureDrawer` and implementing the `paint` method.
This allows for full control over how the signature is rendered.

```dart
class MyCustomDrawer extends HandSignatureDrawer {
  @override
  void paint(Canvas canvas, Size size, List<CubicPath> paths) {
    // Custom painting logic here
  }
}
```

![Custom Drawer](https://raw.githubusercontent.com/RomanBase/hand_signature/master/doc/custom_drawer.png)

---

## Exporting

You can modify properties like canvas size, stroke width, and color during export.
The most common export formats are SVG and PNG. State can be saved with `toMap` and restored with `import` method.

```dart

final control = HandSignatureControl();

// Export to SVG
final svg = control.toSvg();

// Export to PNG
final png = await control.toImage();

// Export to raw data
final json = control.toMap();

// Import from raw data
control.impor(json);
```

- **SVG**:
  - `shape`: Generates a reasonably small file that is well-supported by most programs.
  - `arc`: Generates a larger SVG file, which some programs may struggle to handle.
  - `line`: A simple Bezier curve.
- **Image**: Export to an `Image` or `Picture` object, which can then be converted to PNG bytes.
  - `arc`: Default drawer when exporting image data.
  - `drawer`: Specifies `HandSignatureDrawer` to use during canvas export.
- **JSON/Map**: Export the current state as raw data, which can be used later to restore the signature.

### Displaying a Saved SVG

You can display an exported SVG string using a library like [flutter_svg](https://pub.dev/packages/flutter_svg).
