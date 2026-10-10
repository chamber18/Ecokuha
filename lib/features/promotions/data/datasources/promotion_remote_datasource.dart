import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/promotion_model.dart';
import '../../domain/entities/promotion_type.dart';

class PromotionRemoteDataSource {
  final SupabaseClient _db;

  PromotionRemoteDataSource({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;
  PromotionModel _fromRow(Map<String, dynamic> row) =>
      PromotionModel.fromJson(rowToDoc('promotions', row));

  Map<String, dynamic> _toRow(PromotionModel promotion) {
    final json = promotion.toJson()..remove('id');
    json.remove('createdAt'); // DB default
    json['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    return docToRow('promotions', json);
  }

  Future<String> createPromotion(PromotionModel promotion) async {
    final row = _toRow(promotion)..remove('updated_at');
    row['junkshop_id'] = promotion.junkshopId;
    final inserted = await _db
        .from('promotions')
        .insert(row)
        .select('id')
        .single();
    return inserted['id'].toString();
  }

  Future<void> updatePromotion(PromotionModel promotion) async {
    final row = _toRow(promotion)..remove('junkshop_id');
    await _db
        .from('promotions')
        .update(row)
        .eq('id', promotion.id)
        .eq('junkshop_id', promotion.junkshopId);
  }

  Future<void> deletePromotion(String promotionId, String junkshopId) async {
    await _db
        .from('promotions')
        .delete()
        .eq('id', promotionId)
        .eq('junkshop_id', junkshopId);
  }

  /// Image URL stored on a promotion (used for storage cleanup), or null.
  Future<String?> getPromotionImageUrl(String promotionId) async {
    final row = await _db
        .from('promotions')
        .select('image_url')
        .eq('id', promotionId)
        .maybeSingle();
    return row?['image_url'] as String?;
  }

  Future<PromotionModel> getPromotion(String promotionId) async {
    final row = await _db
        .from('promotions')
        .select()
        .eq('id', promotionId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Promotion not found');
    }

    return _fromRow(row);
  }

  Future<List<PromotionModel>> getJunkshopPromotions(
    String junkshopId, {
    PromotionStatus? status,
  }) async {
    final now = DateTime.now();

    final rows = await _db
        .from('promotions')
        .select()
        .eq('junkshop_id', junkshopId)
        .order('created_at', ascending: false);
    var promotions = rows.map(_fromRow).toList();

    // Filter based on actual status considering endDate
    if (status != null) {
      promotions = promotions.where((promotion) {
        // Determine actual status based on dates and stored status
        if (promotion.status == PromotionStatus.cancelled) {
          return status == PromotionStatus.cancelled;
        }

        // Check if promotion has expired based on endDate
        final isExpired = promotion.endDate.isBefore(now);

        if (status == PromotionStatus.expired) {
          return isExpired && promotion.status != PromotionStatus.cancelled;
        } else if (status == PromotionStatus.active) {
          return !isExpired && promotion.status == PromotionStatus.active;
        }

        return false;
      }).toList();
    }

    return promotions;
  }

  /// Applies the "currently running" filters client-side.
  List<PromotionModel> _filterActive(
    List<PromotionModel> promotions, {
    String? materialType,
    PromotionType? promotionType,
  }) {
    final now = DateTime.now();
    final filtered = promotions.where((p) {
      if (p.status != PromotionStatus.active) return false;
      if (p.startDate.isAfter(now)) return false;
      if (!p.endDate.isAfter(now)) return false;
      if (promotionType != null && p.type != promotionType) return false;
      if (materialType != null && !p.materials.contains(materialType)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final byEnd = a.endDate.compareTo(b.endDate);
      if (byEnd != 0) return byEnd;
      return b.createdAt.compareTo(a.createdAt);
    });
    return filtered;
  }

  Future<List<PromotionModel>> getActivePromotions({
    String? materialType,
    PromotionType? promotionType,
    int? limit,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    var query = _db
        .from('promotions')
        .select()
        .eq('status', 'active')
        .gt('end_date', nowIso);

    if (promotionType != null) {
      query = query.eq('type', promotionType.toFirestoreValue());
    }

    final rows = await query
        .order('end_date', ascending: true)
        .order('created_at', ascending: false);

    var promotions = _filterActive(
      rows.map(_fromRow).toList(),
      materialType: materialType,
      promotionType: promotionType,
    );

    if (limit != null && promotions.length > limit) {
      promotions = promotions.take(limit).toList();
    }

    return promotions;
  }

  Stream<List<PromotionModel>> watchActivePromotions({
    String? materialType,
    PromotionType? promotionType,
  }) {
    return _db
        .from('promotions')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .map(
          (rows) => _filterActive(
            rows.map(_fromRow).toList(),
            materialType: materialType,
            promotionType: promotionType,
          ),
        );
  }

  Future<void> cancelPromotion(String promotionId, String junkshopId) async {
    await _db
        .from('promotions')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', promotionId)
        .eq('junkshop_id', junkshopId);
  }
}