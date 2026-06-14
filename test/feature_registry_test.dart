import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_hub/core/feature_registry.dart';
import 'package:z_hub/core/feature_interface.dart';

class _FakeFeature extends AppFeature {
  final String _id;
  final bool _enabledByDefault;
  _FakeFeature(this._id, {bool enabledByDefault = true})
      : _enabledByDefault = enabledByDefault;
  @override
  String get id => _id;
  @override
  String get name => _id;
  @override
  String get description => '';
  @override
  String get iconAsset => '';
  @override
  bool get enabledByDefault => _enabledByDefault;
  @override
  IconData get icon => Icons.abc;
  @override
  Widget buildPage(BuildContext context) => const SizedBox();
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  group('FeatureRegistry', () {
    test('register enables by default', () {
      final registry = FeatureRegistry.instance;
      registry.register(_FakeFeature('test_a'));
      expect(registry.isEnabled('test_a'), true);
    });

    test('register does not enable when enabledByDefault is false', () {
      final registry = FeatureRegistry.instance;
      registry.register(_FakeFeature('test_b', enabledByDefault: false));
      expect(registry.isEnabled('test_b'), false);
    });

    test('enable and disable', () async {
      final registry = FeatureRegistry.instance;
      registry.register(_FakeFeature('test_c', enabledByDefault: false));
      expect(registry.isEnabled('test_c'), false);
      await registry.enable('test_c');
      expect(registry.isEnabled('test_c'), true);
      await registry.disable('test_c');
      expect(registry.isEnabled('test_c'), false);
    });

    test('uninstall removes feature', () async {
      final registry = FeatureRegistry.instance;
      registry.register(_FakeFeature('test_d'));
      await registry.uninstall('test_d');
      expect(registry.isRegistered('test_d'), false);
    });

    test('enabledFeatures returns only enabled ones', () {
      final registry = FeatureRegistry.instance;
      for (final f in List.of(registry.allFeatures)) {
        if (f.id.startsWith('test_')) registry.uninstall(f.id);
      }

      registry.register(_FakeFeature('test_e', enabledByDefault: false));
      registry.register(_FakeFeature('test_f', enabledByDefault: true));
      final enabled = registry.enabledFeatures.map((f) => f.id).toList();
      expect(enabled.contains('test_e'), false);
      expect(enabled.contains('test_f'), true);
    });

    test('isRegistered returns true after register', () {
      final registry = FeatureRegistry.instance;
      registry.register(_FakeFeature('test_g'));
      expect(registry.isRegistered('test_g'), true);
      expect(registry.isRegistered('nonexistent'), false);
    });
  });
}
