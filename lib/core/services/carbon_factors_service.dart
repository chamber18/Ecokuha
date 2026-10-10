import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class CarbonFactorsService {
  static CarbonFactorsService? _instance;
  static CarbonFactorsService get instance {
    _instance ??= CarbonFactorsService._();
    return _instance!;
  }

  CarbonFactorsService._();

  Map<String, dynamic>? _factors;
  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  Future<void> loadFactors() async {
    if (_isLoaded) return;

    // If already loading, wait for that to complete
    if (_loadingFuture != null) {
      return _loadingFuture;
    }

    _loadingFuture = _doLoad();
    await _loadingFuture;
    _loadingFuture = null;
  }

  Future<void> _doLoad() async {
    try {
      if (kDebugMode) print('📥 Loading carbon factors from assets...');
      final String jsonString = await rootBundle.loadString(
        'assets/config/carbon_factors.json',
      );
      final decoded = json.decode(jsonString);
      _factors = decoded;
      _isLoaded = true;
      if (kDebugMode) print('✅ Carbon factors loaded successfully!');
      if (kDebugMode) print('   Top-level keys: ${_factors?.keys.join(", ")}');
      if (_factors != null && _factors!.containsKey('factors')) {
        final factors = _factors!['factors'] as Map?;
        if (kDebugMode) print('   Factor categories: ${factors?.keys.join(", ")}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading carbon factors: $e');
      if (kDebugMode) print('   Stack trace: ${StackTrace.current}');
      _factors = {};
      _isLoaded = true;
    }
  }

  double getFactorForMaterial(String materialName) {
    if (!_isLoaded) {
      if (kDebugMode) print('⚠️ Carbon factors not loaded yet! Call loadFactors() first.');
      return _getDefaultFallback();
    }

    if (_factors == null || _factors!.isEmpty) {
      if (kDebugMode) print('⚠️ Carbon factors are empty!');
      return _getDefaultFallback();
    }

    final normalizedName = materialName.toLowerCase().trim();
    if (kDebugMode) print('🔍 Looking up carbon factor for: "$normalizedName"');

    final factor = _matchMaterialToFactor(normalizedName);
    if (kDebugMode) print('✅ Found factor: $factor');
    return factor;
  }

  double _matchMaterialToFactor(String materialName) {
    // Battery category
    if (materialName.contains('car battery') ||
        materialName.contains('plates')) {
      return _getFactorValue(['factors', 'battery', 'car_battery', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('motorcycle battery')) {
      return _getFactorValue([
            'factors',
            'battery',
            'motorcycle_battery',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('battery')) {
      return _getFactorValue(['factors', 'battery', 'default', 'value']) ??
          _getDefaultFallback();
    }

    // E-waste category
    if (materialName.contains('tv board')) {
      return _getFactorValue(['factors', 'e-waste', 'tv_board', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('motherboard')) {
      return _getFactorValue(['factors', 'e-waste', 'motherboard', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('cpu') || materialName.contains('processor')) {
      return _getFactorValue(['factors', 'e-waste', 'cpu', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('airconditioner') ||
        materialName.contains('aircon') ||
        materialName.contains('ac unit')) {
      return _getFactorValue([
            'factors',
            'e-waste',
            'airconditioner',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('copper radiator')) {
      return _getFactorValue([
            'factors',
            'e-waste',
            'copper_radiator',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('aluminum radiator') ||
        materialName.contains('aluminium radiator')) {
      return _getFactorValue([
            'factors',
            'e-waste',
            'aluminum_radiator',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('refrigerator') ||
        materialName.contains('fridge')) {
      return _getFactorValue(['factors', 'e-waste', 'refrigerator', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('retro tv') || materialName.contains('crt')) {
      return _getFactorValue(['factors', 'e-waste', 'retro_tv', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('split type') ||
        materialName.contains('split-type')) {
      return _getFactorValue([
            'factors',
            'e-waste',
            'split_type_aircon',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('washing machine')) {
      return _getFactorValue([
            'factors',
            'e-waste',
            'washing_machine',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('e-waste') ||
        materialName.contains('ewaste') ||
        materialName.contains('electronic')) {
      return _getFactorValue(['factors', 'e-waste', 'default', 'value']) ??
          _getDefaultFallback();
    }

    // Glass category
    if (materialName.contains('softdrinks') ||
        materialName.contains('pepsi') ||
        materialName.contains('coke')) {
      return _getFactorValue([
            'factors',
            'glass',
            'softdrinks_bottle',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('redhorse') ||
        materialName.contains('san mig') ||
        materialName.contains('beer')) {
      return _getFactorValue(['factors', 'glass', 'beer_bottle', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('tanduay') ||
        materialName.contains('emperador') ||
        materialName.contains('kulafu') ||
        materialName.contains('liquor')) {
      return _getFactorValue(['factors', 'glass', 'liquor_bottle', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('garapa')) {
      return _getFactorValue(['factors', 'glass', 'garapa', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('ketchup') ||
        materialName.contains('toyo') ||
        materialName.contains('mallorca')) {
      return _getFactorValue([
            'factors',
            'glass',
            'condiment_bottle',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('glass') || materialName.contains('bottle')) {
      return _getFactorValue(['factors', 'glass', 'default', 'value']) ??
          _getDefaultFallback();
    }

    // Metal category
    if (materialName.contains('copper') && !materialName.contains('radiator')) {
      return _getFactorValue(['factors', 'metal', 'copper', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('tin can')) {
      return _getFactorValue(['factors', 'metal', 'tin_can', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('sin roof') || materialName.contains('roofing')) {
      return _getFactorValue(['factors', 'metal', 'sin_roof', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('steel plate')) {
      return _getFactorValue(['factors', 'metal', 'steel_plate', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('brass')) {
      return _getFactorValue(['factors', 'metal', 'brass', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('aluminum can') ||
        materialName.contains('aluminium can')) {
      return _getFactorValue(['factors', 'metal', 'aluminum_can', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('kaldero')) {
      return _getFactorValue(['factors', 'metal', 'kaldero', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('stainless')) {
      return _getFactorValue([
            'factors',
            'metal',
            'stainless_steel',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('light metal')) {
      return _getFactorValue(['factors', 'metal', 'light_metals', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('assorted aluminum') ||
        materialName.contains('assorted aluminium')) {
      return _getFactorValue([
            'factors',
            'metal',
            'assorted_aluminum',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('metal')) {
      return _getFactorValue(['factors', 'metal', 'default', 'value']) ??
          _getDefaultFallback();
    }

    // Paper category
    if (materialName.contains('karton') || materialName.contains('cardboard')) {
      return _getFactorValue(['factors', 'paper', 'karton', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('white bondpaper') ||
        materialName.contains('bondpaper')) {
      return _getFactorValue([
            'factors',
            'paper',
            'white_bondpaper',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('paper white')) {
      return _getFactorValue(['factors', 'paper', 'paper_white', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('paper mix')) {
      return _getFactorValue(['factors', 'paper', 'paper_mix', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('assorted paper')) {
      return _getFactorValue(['factors', 'paper', 'assorted_paper', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('paper')) {
      return _getFactorValue(['factors', 'paper', 'default', 'value']) ??
          _getDefaultFallback();
    }

    // Plastic category
    if (materialName.contains('pet') || materialName.contains('p.e.t')) {
      return _getFactorValue(['factors', 'plastic', 'pet_bottle', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('monobloc')) {
      return _getFactorValue(['factors', 'plastic', 'monobloc', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('kola')) {
      return _getFactorValue(['factors', 'plastic', 'kola_plastic', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('assorted plastic')) {
      return _getFactorValue([
            'factors',
            'plastic',
            'assorted_plastic',
            'value',
          ]) ??
          _getDefaultFallback();
    }
    if (materialName.contains('plastic')) {
      return _getFactorValue(['factors', 'plastic', 'default', 'value']) ??
          _getDefaultFallback();
    }

    // Iron category
    if (materialName.contains('bakal solid')) {
      return _getFactorValue(['factors', 'iron', 'bakal_solid', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('bakal light')) {
      return _getFactorValue(['factors', 'iron', 'bakal_light', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('bakal assorted')) {
      return _getFactorValue(['factors', 'iron', 'bakal_assorted', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('pundido')) {
      return _getFactorValue(['factors', 'iron', 'pundido', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('cyclone')) {
      return _getFactorValue(['factors', 'iron', 'cyclone', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('alloy')) {
      return _getFactorValue(['factors', 'iron', 'alloy', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('bakal') || materialName.contains('iron')) {
      return _getFactorValue(['factors', 'iron', 'default', 'value']) ??
          _getDefaultFallback();
    }

    // Others category
    if (materialName.contains('tire')) {
      return _getFactorValue(['factors', 'others', 'tires', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('multicab') ||
        materialName.contains('sedan') ||
        materialName.contains('motorcycle') ||
        materialName.contains('jeepney') ||
        materialName.contains('vehicle')) {
      return _getFactorValue(['factors', 'others', 'vehicle_scrap', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('can tray')) {
      return _getFactorValue(['factors', 'others', 'can_tray', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('zinc')) {
      return _getFactorValue(['factors', 'others', 'zinc', 'value']) ??
          _getDefaultFallback();
    }
    if (materialName.contains('lata')) {
      return _getFactorValue(['factors', 'others', 'lata', 'value']) ??
          _getDefaultFallback();
    }

    return _getDefaultFallback();
  }

  double? _getFactorValue(List<String> path) {
    if (_factors == null) {
      if (kDebugMode) print('  ❌ _factors is null');
      return null;
    }

    if (kDebugMode) print('  🔎 Searching path: ${path.join(" → ")}');
    dynamic current = _factors;
    for (final key in path) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
        if (kDebugMode) print('    ✓ Found "$key"');
      } else {
        if (kDebugMode) print('    ✗ Key "$key" not found in ${current.runtimeType}');
        if (current is Map<String, dynamic>) {
          if (kDebugMode) print('      Available keys: ${current.keys.join(", ")}');
        }
        return null;
      }
    }

    if (current is num) {
      if (kDebugMode) print('  ✅ Final value: $current');
      return current.toDouble();
    }
    if (kDebugMode) print('  ⚠️ Final value is not a number: ${current.runtimeType}');
    return null;
  }

  double _getDefaultFallback() {
    final fallback = _getFactorValue(['factors', 'default', 'value']);
    return fallback ?? 0.5;
  }
}
