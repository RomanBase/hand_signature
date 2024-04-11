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
