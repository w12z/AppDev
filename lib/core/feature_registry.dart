import 'package:flutter/material.dart';
import 'feature_interface.dart';

/// 全局模块注册表，管理所有 feature 的生命周期。
class FeatureRegistry extends ChangeNotifier {
  static final FeatureRegistry _instance = FeatureRegistry._();
  factory FeatureRegistry() => _instance;
  FeatureRegistry._();

  final Map<String, AppFeature> _features = {};
  final Set<String> _enabledFeatures = {};

  void register(AppFeature feature) {
    _features[feature.id] = feature;
    if (feature.enabledByDefault) {
      _enabledFeatures.add(feature.id);
    }
  }

  Future<void> enable(String id) async {
    if (!_features.containsKey(id) || _enabledFeatures.contains(id)) return;
    final feature = _features[id]!;
    await feature.init();
    _enabledFeatures.add(id);
    notifyListeners();
  }

  Future<void> disable(String id) async {
    if (!_features.containsKey(id) || !_enabledFeatures.contains(id)) return;
    final feature = _features[id]!;
    await feature.dispose();
    _enabledFeatures.remove(id);
    notifyListeners();
  }

  Future<void> uninstall(String id) async {
    if (!_features.containsKey(id)) return;
    await disable(id);
    _features.remove(id);
    notifyListeners();
  }

  bool isEnabled(String id) => _enabledFeatures.contains(id);
  bool isRegistered(String id) => _features.containsKey(id);

  List<AppFeature> get enabledFeatures =>
      _features.values.where((f) => _enabledFeatures.contains(f.id)).toList();

  List<AppFeature> get allFeatures => _features.values.toList();
}
