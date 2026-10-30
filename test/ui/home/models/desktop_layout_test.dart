import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/desktop_layout/desktop_layout.dart';
import 'package:node_diary/ui/home/models/desktop_layout/desktop_layout_code.dart';

void main() {
  group('DesktopLayout.decode', () {
    test('null/empty/corrupt returns defaults', () {
      expect(DesktopLayout.decode(null), DesktopLayout.defaults);
      expect(DesktopLayout.decode(''), DesktopLayout.defaults);
      expect(DesktopLayout.decode('   '), DesktopLayout.defaults);
      expect(DesktopLayout.decode('not json'), DesktopLayout.defaults);
      expect(
        DesktopLayout.decode('{"modules": "nope"}'),
        DesktopLayout.defaults,
      );
    });

    test('default order is header/writeButton/quickEntry/recent', () {
      final layout = DesktopLayout.decode(null);
      expect(layout.visibleModuleIds, const <DesktopModuleId>[
        DesktopModuleId.header,
        DesktopModuleId.writeButton,
        DesktopModuleId.quickEntry,
        DesktopModuleId.recent,
      ]);
    });

    test('unknown ids are dropped, duplicates keep first', () {
      final layout = DesktopLayout.decode(
        '{"v":1,"modules":['
        '{"id":"recent","visible":true},'
        '{"id":"nope","visible":true},'
        '{"id":"recent","visible":false},'
        '{"id":"header","visible":false}'
        ']}',
      );
      // recent first (visible), unknown dropped, duplicate recent dropped,
      // header last (hidden); missing writeButton/quickEntry appended visible.
      expect(layout.modules.map((m) => m.id).toList(), const <DesktopModuleId>[
        DesktopModuleId.recent,
        DesktopModuleId.header,
        DesktopModuleId.writeButton,
        DesktopModuleId.quickEntry,
      ]);
      expect(layout.modules[0].visible, isTrue);
      expect(layout.modules[1].visible, isFalse);
      expect(layout.visibleModuleIds, const <DesktopModuleId>[
        DesktopModuleId.recent,
        DesktopModuleId.writeButton,
        DesktopModuleId.quickEntry,
      ]);
    });

    test('missing modules are appended at the end, visible', () {
      final layout = DesktopLayout.decode(
        '{"v":1,"modules":[{"id":"recent","visible":true}]}',
      );
      expect(layout.modules.map((m) => m.id).toList(), const <DesktopModuleId>[
        DesktopModuleId.recent,
        DesktopModuleId.header,
        DesktopModuleId.writeButton,
        DesktopModuleId.quickEntry,
      ]);
    });
  });

  group('DesktopLayout.encode', () {
    test('default encodes to null (key removed)', () {
      expect(DesktopLayout.defaults.encode(), isNull);
      expect(
        const DesktopLayout(modules: DesktopLayout.defaultModules).encode(),
        isNull,
      );
    });

    test('custom layout round-trips', () {
      const layout = DesktopLayout(
        modules: <DesktopModuleSpec>[
          DesktopModuleSpec(id: DesktopModuleId.recent),
          DesktopModuleSpec(id: DesktopModuleId.header, visible: false),
          DesktopModuleSpec(id: DesktopModuleId.writeButton),
          DesktopModuleSpec(id: DesktopModuleId.quickEntry),
        ],
      );
      final raw = layout.encode();
      expect(raw, isNotNull);
      expect(DesktopLayout.decode(raw), layout);
    });
  });

  group('DesktopLayout helpers', () {
    test('withVisibility toggles one module', () {
      final layout = DesktopLayout.defaults.withVisibility(
        DesktopModuleId.recent,
        false,
      );
      expect(layout.visibleModuleIds, isNot(contains(DesktopModuleId.recent)));
      expect(layout.modules.length, 4);
    });

    test('moved reorders', () {
      final layout = DesktopLayout.defaults.moved(DesktopModuleId.recent, 0);
      expect(layout.modules.first.id, DesktopModuleId.recent);
      expect(layout.modules[1].id, DesktopModuleId.header);
    });
  });

  group('DesktopLayoutCode', () {
    test('encode/decode round-trip', () {
      final layout = DesktopLayout.defaults.withVisibility(
        DesktopModuleId.quickEntry,
        false,
      );
      final code = DesktopLayoutCode.encode(layout);
      expect(code.startsWith('jotsy-home:v1:'), isTrue);
      final result = DesktopLayoutCode.decode(code);
      expect(result.status, StyleCodeStatus.ok);
      expect(result.style, layout);
    });

    test('invalid code is rejected', () {
      expect(DesktopLayoutCode.decode('hello').status, StyleCodeStatus.invalid);
      expect(
        DesktopLayoutCode.decode('jotsy-bars:v1:abc').status,
        StyleCodeStatus.invalid,
      );
    });

    test('default layout code decodes to defaults', () {
      final code = DesktopLayoutCode.encode(DesktopLayout.defaults);
      final result = DesktopLayoutCode.decode(code);
      expect(result.status, StyleCodeStatus.ok);
      expect(result.style!.isDefault, isTrue);
    });
  });
}
