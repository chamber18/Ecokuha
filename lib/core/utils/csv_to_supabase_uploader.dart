import 'dart:io';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility to parse a materials CSV and upsert it into the signed-in
/// junkshop's `junkshop_materials` rows.
///
/// `material_templates` is admin-write-only, so templates are only READ here
/// (see [copyTemplatesToJunkshop]).
class CsvToSupabaseUploader {
  final SupabaseClient _db;

  CsvToSupabaseUploader({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  /// Parse CSV file and upsert the materials for the signed-in junkshop.
  Future<void> uploadMaterialsFromCsv(String csvFilePath) async {
    try {
      final junkshopId = requireUid();
      final file = File(csvFilePath);
      final lines = await file.readAsLines();

      // Skip header row and empty lines
      final dataLines = lines.skip(1).where((line) {
        final fields = line.split(',');
        return fields.length >= 5 && fields[1].trim().isNotEmpty;
      }).toList();

      if (kDebugMode) print('Found ${dataLines.length} materials to upload');

      final existing = await _existingByName(junkshopId);

      int successCount = 0;
      int errorCount = 0;

      for (final line in dataLines) {
        try {
          final material = _parseCsvLine(line);
          if (material != null) {
            await _upsertMaterial(junkshopId, material, existing);
            successCount++;
            if (kDebugMode) {
              print('Uploaded: ${material['name']} (${material['category']})');
            }
          }
        } catch (e) {
          errorCount++;
          if (kDebugMode) {
            print('Error parsing line: $line');
            print('   Error: $e');
          }
        }
      }

      if (kDebugMode) {
        print('Upload complete! Success: $successCount, Errors: $errorCount');
      }
    } catch (e) {
      if (kDebugMode) print('Fatal error: $e');
      rethrow;
    }
  }

  /// Parse a single CSV line into a material map (column-named keys).
  Map<String, dynamic>? _parseCsvLine(String line) {
    final fields = line.split(',');

    if (fields.length < 5) return null;

    final category = fields[0].trim();
    final name = fields[1].trim();
    final priceRange = fields[2].trim();
    final unit = fields[3].trim();
    final commissionStr = fields[4].trim();

    if (category.isEmpty || name.isEmpty || unit.isEmpty) return null;

    final prices = _parsePriceRange(priceRange);
    if (prices == null) return null;

    final commission = double.tryParse(commissionStr) ?? 0.0;

    return {
      'category': category,
      'name': name,
      'price_min': prices['min'],
      'price_max': prices['max'],
      'unit': unit,
      'commission': commission,
      'household_price_min': prices['min']! - commission,
      'household_price_max': prices['max']! - commission,
      'is_active': true,
    };
  }

  /// Parse price range string (e.g., "200 - 350" or "50" or "3 - 3.50")
  Map<String, double>? _parsePriceRange(String priceRange) {
    if (priceRange.isEmpty) return null;

    if (priceRange.contains(' - ')) {
      final parts = priceRange.split(' - ');
      if (parts.length != 2) return null;

      final min = double.tryParse(parts[0].trim());
      final max = double.tryParse(parts[1].trim());

      if (min == null || max == null) return null;

      return {'min': min, 'max': max};
    } else {
      final price = double.tryParse(priceRange.trim());
      if (price == null) return null;

      return {'min': price, 'max': price};
    }
  }

  /// lower-case name -> row id for the junkshop's current materials
  Future<Map<String, String>> _existingByName(String junkshopId) async {
    final rows = await _db
        .from('junkshop_materials')
        .select('id, name')
        .eq('junkshop_id', junkshopId);
    final map = <String, String>{};
    for (final r in rows) {
      final name = (r['name'] as String?)?.toLowerCase() ?? '';
      if (name.isNotEmpty) map[name] = r['id'].toString();
    }
    return map;
  }

  /// Update the junkshop's material of the same name, or insert a new one.
  Future<void> _upsertMaterial(
    String junkshopId,
    Map<String, dynamic> material,
    Map<String, String> existing,
  ) async {
    final key = (material['name'] as String).toLowerCase();
    final existingId = existing[key];
    if (existingId != null) {
      await _db
          .from('junkshop_materials')
          .update(material)
          .eq('id', existingId)
          .eq('junkshop_id', junkshopId);
    } else {
      final inserted = await _db
          .from('junkshop_materials')
          .insert({...material, 'junkshop_id': junkshopId})
          .select('id')
          .single();
      existing[key] = inserted['id'].toString();
    }
  }

  /// Copy (read-only) material templates into a junkshop's materials.
  /// Existing materials with the same name are skipped.
  Future<void> copyTemplatesToJunkshop(String junkshopId) async {
    try {
      if (kDebugMode) print('Copying material templates to junkshop: $junkshopId');

      final templates = await _db.from('material_templates').select();

      if (templates.isEmpty) {
        if (kDebugMode) print('No material templates found.');
        return;
      }

      final existingNames = (await _existingByName(junkshopId)).keys.toSet();

      final toInsert = <Map<String, dynamic>>[];
      for (final t in templates) {
        final name = (t['name'] as String?)?.toLowerCase() ?? '';
        if (name.isEmpty || existingNames.contains(name)) continue;
        existingNames.add(name);
        toInsert.add({
          'junkshop_id': junkshopId,
          'name': t['name'],
          'category': t['category'],
          'unit': t['unit'],
          'description': t['description'],
          'price_min': t['price_min'],
          'price_max': t['price_max'],
          'household_price_min': t['household_price_min'],
          'household_price_max': t['household_price_max'],
          'commission': t['commission'],
          'is_active': t['is_active'] ?? true,
        });
      }

      if (toInsert.isNotEmpty) {
        await _db.from('junkshop_materials').insert(toInsert);
      }

      if (kDebugMode) print('Copied ${toInsert.length} new materials to junkshop $junkshopId');
    } catch (e) {
      if (kDebugMode) print('Error copying templates: $e');
      rethrow;
    }
  }

  /// Check if junkshop already has materials
  Future<bool> junkshopHasMaterials(String junkshopId) async {
    final rows = await _db
        .from('junkshop_materials')
        .select('id')
        .eq('junkshop_id', junkshopId)
        .limit(1);
    return rows.isNotEmpty;
  }
}
