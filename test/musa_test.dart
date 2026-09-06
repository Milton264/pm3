import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:musa/main.dart';
import 'package:musa/models.dart';
import 'package:musa/api.dart';
import 'package:musa/state.dart';
import 'package:musa/explore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  setUpAll(() async {
    for (final pair in [
      ('Editorial', 'assets/fonts/Editorial.ttf'),
      ('Atelier', 'assets/fonts/Atelier.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(pair.$1)..addFont(rootBundle.load(pair.$2));
      await loader.load();
    }
  });
  setUp(() async {
    state = AppState();
    state.baseCatalog = (jsonDecode(
      await File('assets/catalog.json').readAsString(),
    ) as List).map((j) => Inspiration.fromJson(object(j))).toList();
    state.ready = true;
  });
  Future<void> launch(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('screen'),
        child: ChangeNotifierProvider.value(
          value: state,
          child: const MusaApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'taste follows positive and negative votes without counting unseen images',
    () {
      final t = Taste(state.catalog, {'blazer': true, 'pink': false});
      expect(t.reviewed, 2);
      expect(t.likes, 1);
      expect(t.favorites, contains('sastrería'));
      expect(t.favorites, isNot(contains('rosa')));
    },
  );
  test('remote connections require HTTPS and cannot include credentials or query strings', () {
    expect(
      MusaApi.normalizeUrl('https://musa.example/'),
      'https://musa.example',
    );
    expect(
      MusaApi.normalizeUrl('http://192.168.1.4:8787'),
      'http://192.168.1.4:8787',
    );
    for (final url in [
      'http://public.example',
      'https://user:secret@host.example',
      'https://host.example/?key=secret',
      'file:///etc/passwd',
    ]) {
      expect(() => MusaApi.normalizeUrl(url), throwsA(isA<ApiException>()));
    }
  });
  testWidgets('right likes, undo restores card, left rejects', (tester) async {
    await launch(tester, const Size(390, 844));
    await tester.drag(find.byType(SwipeDeck), const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(state.votes['blazer'], true);
    await tester.tap(find.byTooltip('Deshacer'));
    await tester.pumpAndSettle();
    expect(state.votes.containsKey('blazer'), false);
    await tester.tap(find.byTooltip('Paso'));
    await tester.pumpAndSettle();
    expect(state.votes['blazer'], false);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'private actions request connection instead of pretending to save',
    (tester) async {
      await launch(tester, const Size(390, 844));
      state.navigate(1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir mi primera prenda'));
      await tester.pumpAndSettle();
      expect(find.text('Tu espacio privado.'), findsOneWidget);
      expect(state.garments, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('all four screens fit a compact iPhone without render overflow', (
    tester,
  ) async {
    await launch(tester, const Size(320, 568));
    for (var tab = 0; tab < 4; tab++) {
      state.navigate(tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'tab $tab');
    }
  });
  testWidgets('chat composer remains usable with the keyboard open', (
    tester,
  ) async {
    await launch(tester, const Size(390, 844));
    state.navigate(3);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.byTooltip('Enviar mensaje')).dy,
      lessThan(504),
    );
  });
  testWidgets('render actual Flutter screens for visual review', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE')) return;
    for (final pair in [
      ('Editorial', 'Editorial.ttf'),
      ('Atelier', 'Atelier.ttf'),
    ]) {
      final loader = FontLoader(pair.$1)
        ..addFont(rootBundle.load('assets/fonts/${pair.$2}'));
      await loader.load();
    }
    await launch(tester, const Size(390, 844));
    await tester.runAsync(
      () => Future.wait(
        state.baseCatalog.map(
          (item) => precacheImage(
            AssetImage(item.asset!),
            tester.element(find.byType(MusaHome)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final output = Directory('qa/screens')..createSync(recursive: true);
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('screen')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('descubrir');
    await tester.tap(find.text('Mi tablero'));
    await tester.pumpAndSettle();
    await capture('tablero');
    state.navigate(1);
    await tester.pumpAndSettle();
    await capture('armario');
    state.navigate(2);
    await tester.pumpAndSettle();
    await capture('looks');
    state.navigate(3);
    await tester.pumpAndSettle();
    await capture('chat');
    expect(tester.takeException(), isNull);
  });
}
