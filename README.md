# Hand Signature

A Flutter plugin providing a Signature Pad for drawing smooth signatures. This library is written in a pure Dart/Flutter environment to provide support for all platforms. It's easy to use, with a variety of drawing and export settings, and also supports SVG files.

![Signature](https://raw.githubusercontent.com/RomanBase/hand_signature/master/doc/signature.png)

The signature pad drawing is based on Cubic Bézier curves and offers a choice between performance and beauty modes.

---

## Features

- **Cross-Platform:** Works on any platform supported by Flutter.
- **Customizable:** Adjust stroke width, color, and smoothing.
- **Multiple Drawing Types:** Choose between `line`, `shape`, and `arc` for different visual styles.
- **Velocity-Based Stroke:** The thickness of the line can vary based on the drawing speed.
- **Export Options:** Export signatures as PNG, SVG, or raw data (JSON/Map).
- **Import/Export:** Save and load signature data.

---

## Usage

### 1. Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  hand_signature: ^<latest_version>
```

### 2. Import the library:

```dart
import 'package:hand_signature/signature.dart';
```

### 3. Implement the Signature Pad:

Use `HandSignatureControl` to manage the drawing logic and `HandSignature` to display the pad.

```dart
// Create a control instance
final control = HandSignatureControl(
  threshold: 3.0,
  smoothRatio: 0.65,
  velocityRange: 2.0,
);

// Create the signature pad widget
HandSignature(
  control: control,
  color: Colors.blueGrey,
  width: 1.0,
  maxWidth: 10.0,
  type: SignatureDrawType.shape,
)
```

---

## `HandSignatureControl`

This class handles the "math" behind the signature, controlling input touches and managing the control points of the signature curve.

- `threshold`: (LP) Controls the minimal distance between two points. A higher distance creates a smoother, but less precise, curve and may introduce a slight drawing lag.
- `smoothRatio`: (0 - 1) Controls how smooth the curve will be. A higher ratio creates a smoother, but less precise, curve. The best results are typically between 0.5 and 0.75.
- `velocityRange`: (LP per millisecond) Controls the curve size based on the distance and duration between two points. A thin line corresponds to a fast movement, while a thick line corresponds to a slow movement. With a higher `velocityRange`, the user must move the pointer faster to draw a thinner line.
- `reverseVelocity`: Swaps the stroke width. A thin line will correspond to a slow movement, and a thick line to a fast movement.

---

## `HandSignature`

This widget handles the visual style of the signature curve.

- `control`: The `HandSignatureControl` that processes input and stores the raw data.
- `color`: The color of the line.
- `width`: The minimal width of the line (at maximum drawing speed).
- `maxWidth`: The maximum width of the line (at slowest drawing speed).
- `type`: The draw type of the curve.
  - `line`: A basic Bezier line with the best performance.
  - `shape`: An "ink" style signature with good performance.
  - `arc`: A "beauty mode" for an ink-styled signature, which may be less performant.

---

## Exporting

You can modify properties like canvas size, stroke width, and color during export. The most common export formats are SVG and PNG.

```dart
final control = HandSignatureControl();

// Export to SVG
final svg = control.toSvg();

// Export to PNG
final png = await control.toImage();

// Export to raw data
final json = control.toMap();

// Import from raw data
control.importData(json);
```

- **SVG**: 
  - `shape`: Generates a reasonably small file that is well-supported by most programs.
  - `arc`: Generates a larger SVG file, which some programs may struggle to handle.
  - `line`: A simple Bezier curve.
- **Image**: Export to an `Image` object, which can then be converted to PNG bytes.
- **JSON/Map**: Export the current state as raw data, which can be used later to restore the signature.

### Displaying a Saved SVG

You can display an exported SVG string using a library like [flutter_svg](https://pub.dev/packages/flutter_svg).
