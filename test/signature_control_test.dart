import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_signature/signature.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final control = HandSignatureControl();

  // mock curve sequence
  control.startPath(OffsetPoint(dx: 0.0, dy: 0.0, timestamp: 1));
  control.alterPath(OffsetPoint(dx: 10.0, dy: 10.0, timestamp: 10));
  control.alterPath(OffsetPoint(dx: 20.0, dy: 20.0, timestamp: 15));
  control.alterPath(OffsetPoint(dx: 30.0, dy: 20.0, timestamp: 20));
  control.closePath();

  // mock dot sequence
  control.startPath(OffsetPoint(dx: 30.0, dy: 30.0, timestamp: 25));
  control.closePath();

  // json string representing above mock data
  final json =
      '[[{"x":0.0,"y":0.0,"t":1},{"x":10.0,"y":10.0,"t":10},{"x":20.0,"y":20.0,"t":15},{"x":30.0,"y":20.0,"t":20}],[{"x":30.0,"y":30.0,"t":25}]]';

  group('IO', () {
    test('points', () async {
      final paths = control.paths;
      final curve = paths[0];
      final dot = paths[1];

      expect(paths.length, 2);
      expect(curve.points.length, 4);
      expect(curve.lines.length, 3);

      // velocity of first line should be lower because second line is drawn faster while distance is identical
      expect(curve.lines[0].end - curve.lines[0].start,
          equals(curve.lines[1].end - curve.lines[1].start));
      expect(curve.lines[0].velocity(), lessThan(curve.lines[1].velocity()));

      expect(dot.points.length, 1);
      expect(dot.isDot, isTrue);
    });

    test('export', () async {
      final paths = control.paths;

      final export =
          '[${paths.map((e) => '[${e.points.map((e) => '{"x":${e.dx},"y":${e.dy},"t":${e.timestamp}}').join(',')}]').join(',')}]';
      final data = jsonDecode(export);

      expect(data, isNotNull);
      expect((data as List).length, 2);
      expect((data[0] as List).length, 4);
      expect((data[1] as List).length, 1);

      expect(export, equals(json));
    });

    test('import', () async {
      final controlIn = HandSignatureControl();

      final data = jsonDecode(json) as Iterable;

      data.forEach((element) {
        final line = List.of(element);
        expect(line.length, greaterThan(0));

        //start path with first point
        controlIn.startPath(OffsetPoint(
          dx: line[0]['x'],
          dy: line[0]['y'],
          timestamp: line[0]['t'],
        ));

        //skip first point and alter path with rest of points
        line.skip(1).forEach((item) {
          controlIn.alterPath(OffsetPoint(
            dx: item['x'],
            dy: item['y'],
            timestamp: item['t'],
          ));
        });

        //close path
        controlIn.closePath();
      });

      final paths = controlIn.paths;
      final curve = paths[0];
      final dot = paths[1];

      expect(paths.length, 2);
      expect(curve.points.length, 4);
      expect(curve.lines.length, 3);

      // velocity of first line is lower because second line is drawn faster while distance is identical
      expect(curve.lines[0].end - curve.lines[0].start,
          equals(curve.lines[1].end - curve.lines[1].start));
      expect(curve.lines[0].velocity(), lessThan(curve.lines[1].velocity()));

      expect(dot.points.length, 1);
      expect(dot.isDot, isTrue);

      // check equality of individual OffsetPoints of CubePaths
      expect(controlIn.equals(control), isTrue);
    });

    test('map', () async {
      final controlMap = HandSignatureControl();
      controlMap.importData(control.toMap());

      // check equality of individual OffsetPoints of CubePaths
      expect(controlMap.equals(control), isTrue);
    });

    test('image', () async {
      final controlImage = HandSignatureControl();

      controlImage.importData(control.toMap());
      controlImage.notifyDimension(Size(1280, 720));

      final image = await controlImage.toImage();

      expect(image, isNotNull);

      final data = image!.buffer.asUint8List();

      expect(data, isNotNull);
    });
  });
}
