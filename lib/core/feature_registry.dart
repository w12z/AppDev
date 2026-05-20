import 'feature_interface.dart';

/// 全局模块注册表，管理所有 feature 的生命周期。
class FeatureRegistry {
  static final FeatureRegistry _instance = FeatureRegistry._();
  factory FeatureRegistry() => _instance;
  FeatureRegistry._();

  /// 所有已注册的模块
  final Map<String, AppFeature> _features = {};

  /// 当前启用的模块 id
  final Set<String> _enabledFeatures = {};

  /// 注册一个模块（应用启动时调用）
  void register(AppFeature feature) {
    _features[feature.id] = feature;
    if (feature.enabledByDefault) {
      _enabledFeatures.add(feature.id);
    }
  }

  /// 启用模块
  Future<void> enable(String id) async {
    if (!_features.containsKey(id)) return;
    final feature = _features[id]!;
    await feature.init();
    _enabledFeatures.add(id);
  }

  /// 禁用模块（保留数据，仅隐藏 UI）
  Future<void> disable(String id) async {
    if (!_features.containsKey(id)) return;
    final feature = _features[id]!;
    await feature.dispose();
    _enabledFeatures.remove(id);
  }

  /// 卸载模块（销毁所有数据）
  Future<void> uninstall(String id) async {
    if (!_features.containsKey(id)) return;
    await disable(id);
    _features.remove(id);
  }

  /// 模块是否已启用
  bool isEnabled(String id) => _enabledFeatures.contains(id);

  /// 模块是否已注册
  bool isRegistered(String id) => _features.containsKey(id);

  /// 获取所有已启用的模块（按注册顺序）
  List<AppFeature> get enabledFeatures =>
      _features.values.where((f) => _enabledFeatures.contains(f.id)).toList();

  /// 获取所有已注册的模块
  List<AppFeature> get allFeatures => _features.values.toList();
}
