## [3.1.0] - Pressure, Custom Drawer, Path Setup 
- **Custom Drawing with `HandSignatureDrawer`**: Introduced a new abstract class `HandSignatureDrawer` that allows for complete customization of how signatures are drawn. This provides developers with the flexibility to implement their own drawing logic by extending this class.
- **Built-in Drawers**: Added several built-in drawers for common use cases:
  - `LineSignatureDrawer`: Draws the path as simple lines.
  - `ArcSignatureDrawer`: Renders the path as a series of arcs with variable width.
  - `ShapeSignatureDrawer`: Draws the path as a filled shape.
  - `DynamicSignatureDrawer`: Dynamically selects a drawer based on parameters in the path data.
  - `MultiSignatureDrawer`: Allows combining multiple drawers for complex visual effects.
- **Pressure Sensitivity**: The signature input now captures pressure data from supported devices. The line thickness can vary with pressure. The `pressureRatio` in `SignaturePathSetup` can be used to balance between pressure and velocity.
- **Path Configuration**: Introduced `SignaturePathSetup` to provide a more structured way to configure path properties like `smoothRatio`, `velocityRange`, and `pressureRatio`. It also includes an `args` map for passing custom data to drawers.

### State Handling
- **Rendering**: The drawing pipeline has been refactored to be more customizable, with `SignaturePathSetup` that can hold all the necessary variables for drawer.
- **Data Serialization**: The `toMap` and `import` methods in `HandSignatureControl` have been updated to version `2`, which includes the `SignaturePathSetup` for each path and `pressure` value for each point.

- **Also Comes with updated examples.**

## [3.0.3] - Updated Gesture Recognizer
Now can specify input type - `PointerDeviceKind`.
## [3.0.1] - Fit
Resolve vertices scaling with `fit` flag in export.\
Rename some properties to unify naming across library.
## [3.0.0] - Dependency
Removed dependency on `flutter_svg` and removed `HandSignatureView`.
## [2.3.0] - Import/Export current state (map/json)
Refactor `HandSignaturePainterView` to `HandSignature`
## [2.2.0] - SVG wrap option
## [2.1.1] - Ability to export exact image
toPicture and toImage now contains **fit** property.
## [2.1.0] - Custom Gesture Recognizer
New `GestureRecognizer` based on `OneSequenceGestureRecognizer` that allows just one pointer and handles all pointer updates.
All previous Recognizers have been removed.
## [2.0.0] - Nullsafety
Minimum Dart SDK 2.12.0
## [0.6.3] - Scroll
Added `TapGestureDetector` and current `PanGestureDetector` has been modified to support drawing in `ScrollView`.\
Also pointer callbacks are now exposed to detect **start** and **end** of drawing.
## [0.6.1] - Shape, Arc, Line
Draw line as single shape (huge performance update).\
Selection of 3 draw styles (shape, arc, line). Arc is still nicest, but has performance issues..\
`SignatureDrawType.shape` is now default draw and export style.
## [0.5.1] - Dot
Support dot drawing based on last line size.\
Minor performance updates.
## [0.5.0] - Alpha version of signature pad.
Signature pad for smooth and real hand signatures.
