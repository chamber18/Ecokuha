import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:ecokuha/core/config/feature_flags.dart';
import 'package:ecokuha/core/constants/firestore_fields/index.dart';
import 'package:ecokuha/features/messaging/data/services/conversation_sync_service.dart';
import '../models/posting_model.dart';

// Model for completed collection history
class CompletedCollection {
  final String id;
  final String householdId;
  final List<String> items;
  final List<Map<String, dynamic>> itemsData; // Full item data with prices
  final double totalValue;
  final String? status;
  final DateTime? createdAt;
  final DateTime? scheduledDate;
  final DateTime? collectedAt;
  final DateTime? reviewedAt;
  final DateTime? declinedAt;
  final String? junkshopName;
  final String? junkshopId;
  final String? collectorName;
  final String? collectorId;
  final String? collectorPhoto;
  final String? addressShort;
  final String? specialInstructions;
  final Map<String, List<String>> proofPhotos;
  final List<String> paymentProofUrls;
  final List<String> imageUrls;
  final bool? isCollectorRated;
  final bool? isJunkshopRated;
  final DateTime? ratingDeadline;
  final double? collectorRating;
  final double? junkshopRating;

  CompletedCollection({
    required this.id,
    required this.householdId,
    required this.items,
    required this.itemsData,
    required this.totalValue,
    this.status,
    this.createdAt,
    this.scheduledDate,
    this.collectedAt,
    this.reviewedAt,
    this.declinedAt,
    this.junkshopName,
    this.junkshopId,
    this.collectorName,
    this.collectorId,
    this.collectorPhoto,
    this.addressShort,
    this.specialInstructions,
    this.proofPhotos = const {},
    this.paymentProofUrls = const [],
    this.imageUrls = const [],
    this.isCollectorRated,
    this.isJunkshopRated,
    this.ratingDeadline,
    this.collectorRating,
    this.junkshopRating,
  });

  bool get canRateCollector {
    if (isCollectorRated == true) return false;
    if (collectedAt == null) return false;
    if (ratingDeadline != null && DateTime.now().isAfter(ratingDeadline!)) {
      return false;
    }
    return collectorName != null && collectorId != null;
  }

  bool get canRateJunkshop {
    if (isJunkshopRated == true) return false;
    if (collectedAt == null) return false;
    if (ratingDeadline != null && DateTime.now().isAfter(ratingDeadline!)) {
      return false;
    }
    return junkshopName != null && junkshopId != null;
  }
}

abstract class IHouseholdPostingRepository {
  Future<String> createPosting(PostingDto posting);
  Future<void> updatePosting(String postingId, PostingDto posting);
  Future<String?> cancelPosting(
    String postingId,
  ); // Returns conversation ID if exists
  Future<List<CompletedCollection>> fetchCompletedCollections();
  Future<void> submitCollectorRating({
    required String postingId,
    required double rating,
    required String reviewText,
    List<String>? selectedReasons,
  });
  Future<void> submitJunkshopRating({
    required String postingId,
    required double rating,
    required String reviewText,
    List<String>? selectedReasons,
  });
  Future<Map<String, dynamic>?> getCollectionRating(String postingId);
}

class HouseholdPostingRepository implements IHouseholdPostingRepository {
  final SupabaseClient _db;
  final FeatureFlags flags;

  HouseholdPostingRepository({SupabaseClient? supabase, required this.flags})
    : _db = supabase ?? Supabase.instance.client;

  @override
  Future<String> createPosting(PostingDto posting) async {
    final enabled = flags.isEnabled('firestore_posting');
    final platformOk = _isPlatformSupported();

    // Diagnostics
    try {
      // Using debugPrint to avoid flooding logs in release
      debugPrint('[PostingRepo] firestore_posting enabled: $enabled');
      debugPrint('[PostingRepo] platform supported: $platformOk');
      debugPrint('[PostingRepo] currentUser: ${_db.auth.currentUser?.id}');
    } catch (_) {}

    if (!enabled) {
      // Feature disabled: skip remote write
      return '';
    }
    if (!platformOk) {
      // Avoid crashes on unsupported platforms (e.g., Windows without Firebase config)
      return '';
    }
    // Use current authenticated user only; if absent, skip remote write
    final user = _db.auth.currentUser;
    if (user == null) {
      return '';
    }
    final uid = user.id;

    final data = posting.toMap();
    data['createdBy'] = uid;

    // Build nested household object with all relevant details
    final Map<String, dynamic> householdData = {UserFields.id: uid};

    try {
      final userRow = await _db
          .from('households')
          .select()
          .eq('id', uid)
          .maybeSingle();
      final userData = userRow == null ? null : rowToDoc('households', userRow);
      debugPrint('[PostingRepo] User data keys: ${userData?.keys.toList()}');

      // Extract household profile details
      final fullName =
          (userData?[UserFields.fullName] ?? userData?[UserFields.name])
              ?.toString();
      final phone = userData?[UserFields.phone]?.toString();
      final address = userData?[UserFields.address]?.toString();
      final photo = userData?[UserFields.profileImageUrl]?.toString();

      // Build household nested object with all details
      householdData[UserFields.id] = uid;

      if (fullName != null && fullName.isNotEmpty) {
        householdData[UserFields.fullName] = fullName;
      }
      if (phone != null && phone.isNotEmpty) {
        householdData[UserFields.phone] = phone;
      }
      if (photo != null && photo.isNotEmpty) {
        householdData[UserFields.profileImageUrl] = photo;
      }

      // Use address from posting if provided, otherwise from user profile
      final householdAddress = posting.householdAddress ?? address;
      if (householdAddress != null && householdAddress.isNotEmpty) {
        householdData[UserFields.address] = householdAddress;
      }

      // Add coordinates at household level for distance calculations
      // First try to use coordinates from posting (if provided), otherwise use user profile
      final postingLat = posting.householdLat;
      final postingLng = posting.householdLng;
      // Household registration stores coords nested under 'location': { lat, lng }
      // Fall back through: top-level lat/lng → location.lat/lng → location.latitude/longitude
      final locationMap =
          userData?[UserFields.location] is Map
          ? Map<String, dynamic>.from(userData![UserFields.location] as Map)
          : null;
      final profileLat =
          userData?[UserFields.lat] ??
          locationMap?[UserFields.lat] ??
          locationMap?[UserFields.latitude];
      final profileLng =
          userData?[UserFields.lng] ??
          locationMap?[UserFields.lng] ??
          locationMap?[UserFields.longitude];

      final lat = postingLat ?? profileLat;
      final lng = postingLng ?? profileLng;

      debugPrint(
        '[PostingRepo] Posting coords: lat=$postingLat, lng=$postingLng',
      );
      debugPrint(
        '[PostingRepo] Profile coords: lat=$profileLat, lng=$profileLng',
      );
      debugPrint('[PostingRepo] Using coords: lat=$lat, lng=$lng');

      if (lat != null && lng != null) {
        final latDouble = lat is num
            ? lat.toDouble()
            : double.tryParse(lat.toString());
        final lngDouble = lng is num
            ? lng.toDouble()
            : double.tryParse(lng.toString());

        if (latDouble != null && lngDouble != null) {
          householdData[UserFields.lat] = latDouble;
          householdData[UserFields.lng] = lngDouble;
          debugPrint(
            '[PostingRepo] Added household coords: lat=$latDouble, lng=$lngDouble',
          );
        }
      }

      // Add address note if provided
      if (posting.pickupLocation != null &&
          posting.pickupLocation!.isNotEmpty) {
        householdData[UserFields.note] = posting.pickupLocation;
      }
    } catch (e) {
      debugPrint('[PostingRepo] Failed to build household data: $e');
    }

    // Add household nested object to posting
    data[PostingFields.household] = householdData;

    // Build junkshop nested object if assigned
    if (posting.assignedJunkshopId != null) {
      final junkshopData = <String, dynamic>{
        UserFields.id: posting.assignedJunkshopId!,
      };

      if (posting.assignedJunkshopName != null &&
          posting.assignedJunkshopName!.isNotEmpty) {
        junkshopData[UserFields.fullName] = posting.assignedJunkshopName;
      }
      if (posting.assignedJunkshopAddress != null &&
          posting.assignedJunkshopAddress!.isNotEmpty) {
        junkshopData[UserFields.address] = posting.assignedJunkshopAddress;
      }
      if (posting.assignedJunkshopPhone != null &&
          posting.assignedJunkshopPhone!.isNotEmpty) {
        junkshopData[UserFields.phone] = posting.assignedJunkshopPhone;
      }
      if (posting.assignedJunkshopRating != null) {
        junkshopData[UserFields.rating] = posting.assignedJunkshopRating;
      }

      // Add junkshop coordinates for distance calculations
      if (posting.assignedJunkshopLat != null &&
          posting.assignedJunkshopLng != null) {
        junkshopData[UserFields.lat] = posting.assignedJunkshopLat;
        junkshopData[UserFields.lng] = posting.assignedJunkshopLng;
        debugPrint(
          '[PostingRepo] Added junkshop coords: lat=${posting.assignedJunkshopLat}, lng=${posting.assignedJunkshopLng}',
        );
      }

      data[PostingFields.junkshop] = junkshopData;
      debugPrint('[PostingRepo] Added junkshop object: $junkshopData');
    }

    debugPrint('[PostingRepo] Final posting data keys: ${data.keys.toList()}');
    debugPrint(
      '[PostingRepo] Household object: ${data[PostingFields.household]}',
    );

    // Initialize post_attempt counter for decline tracking
    data['post_attempt'] = 0;

    // 6. Insert the posting row
    try {
      final row = docToRow('postings', data, forUpdate: false);
      row['household_id'] = uid;
      if (posting.assignedJunkshopId != null &&
          posting.assignedJunkshopId!.isNotEmpty) {
        row['junkshop_id'] = posting.assignedJunkshopId;
      }
      final inserted = await _db
          .from('postings')
          .insert(row)
          .select('id')
          .single();
      final id = inserted['id'].toString();
      debugPrint('[PostingRepo] posting saved: $id');
      return id;
    } on PostgrestException catch (e) {
      debugPrint(
        '[PostingRepo] PostgrestException on save: ${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  @override
  Future<void> updatePosting(String postingId, PostingDto posting) async {
    final enabled = flags.isEnabled('firestore_posting');
    final platformOk = _isPlatformSupported();

    debugPrint('[PostingRepo] Updating posting $postingId');
    debugPrint('[PostingRepo] firestore_posting enabled: $enabled');
    debugPrint('[PostingRepo] platform supported: $platformOk');

    if (!enabled || !platformOk) {
      return;
    }

    final user = _db.auth.currentUser;
    if (user == null) {
      debugPrint('[PostingRepo] No user logged in, cannot update posting');
      return;
    }
    final uid = user.id;

    final data = posting.toMap();
    data['householdId'] = uid;

    try {
      // Get current posting to check if it was declined
      final currentRow = await _db
          .from('postings')
          .select('status, post_attempt')
          .eq('id', postingId)
          .eq('household_id', uid)
          .maybeSingle();

      final wasDeclined = currentRow?['status'] == 'declined';
      final currentAttempt = (currentRow?['post_attempt'] as num?)?.toInt() ?? 0;

      // If reposting after decline, increment post_attempt and reset to pending
      if (wasDeclined) {
        data['post_attempt'] = currentAttempt + 1;
        data['status'] = 'pending';
        debugPrint(
          '[PostingRepo] Reposting after decline: attempt ${data['post_attempt']}',
        );
      }

      // Rebuild junkshop nested object so any future junkshop updates are persisted
      if (posting.assignedJunkshopId != null) {
        final junkshopData = <String, dynamic>{
          UserFields.id: posting.assignedJunkshopId!,
        };
        if (posting.assignedJunkshopName != null &&
            posting.assignedJunkshopName!.isNotEmpty) {
          junkshopData[UserFields.fullName] = posting.assignedJunkshopName;
        }
        if (posting.assignedJunkshopAddress != null &&
            posting.assignedJunkshopAddress!.isNotEmpty) {
          junkshopData[UserFields.address] = posting.assignedJunkshopAddress;
        }
        if (posting.assignedJunkshopPhone != null &&
            posting.assignedJunkshopPhone!.isNotEmpty) {
          junkshopData[UserFields.phone] = posting.assignedJunkshopPhone;
        }
        if (posting.assignedJunkshopRating != null) {
          junkshopData[UserFields.rating] = posting.assignedJunkshopRating;
        }
        if (posting.assignedJunkshopLat != null &&
            posting.assignedJunkshopLng != null) {
          junkshopData[UserFields.lat] = posting.assignedJunkshopLat;
          junkshopData[UserFields.lng] = posting.assignedJunkshopLng;
        }
        data[PostingFields.junkshop] = junkshopData;
      }

      final row = docToRow('postings', data);
      // household_id is immutable; never send it on update
      row.remove('household_id');
      if (posting.assignedJunkshopId != null &&
          posting.assignedJunkshopId!.isNotEmpty) {
        row['junkshop_id'] = posting.assignedJunkshopId;
      }

      await _db
          .from('postings')
          .update(row)
          .eq('id', postingId)
          .eq('household_id', uid);

      // If reposting, send system message and cancel scheduled deletion
      if (wasDeclined) {
        await _handleRepostSystemMessage(
          uid,
          postingId,
          data['post_attempt'] as int,
        );
      }

      debugPrint('[PostingRepo] Posting updated successfully: $postingId');
    } on PostgrestException catch (e) {
      debugPrint(
        '[PostingRepo] PostgrestException on update: ${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// Handle system message when posting is reposted after decline
  Future<void> _handleRepostSystemMessage(
    String householdId,
    String postingId,
    int attempt,
  ) async {
    try {
      // Find conversation for this posting
      final conv = await _db
          .from('conversations')
          .select('id')
          .eq('posting_id', postingId)
          .limit(1)
          .maybeSingle();

      if (conv == null) {
        debugPrint('[PostingRepo] No conversation found for repost message');
        return;
      }

      final conversationId = conv['id'].toString();

      // Cancel scheduled deletion
      final syncService = ConversationSyncService();
      await syncService.cancelScheduledDeletion(conversationId);

      // Send system message about repost
      String attemptText = '';
      if (attempt == 2) {
        attemptText = ' (2nd attempt)';
      } else if (attempt == 3) {
        attemptText = ' (3rd attempt)';
      } else if (attempt > 3) {
        attemptText = ' (${attempt}th attempt)';
      }

      final text =
          '🔄 Collection request has been reposted$attemptText. The junkshop will review your updated request.';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await _db.from('messages').insert({
        'conversation_id': conversationId,
        'text': text,
        'sender_id': 'ecokuha_assistant',
        'sender_name': 'EcoKuha Assistant',
        'type': 'system',
        'read_by': <String>[],
        'metadata': {'action': 'reposted'},
      });

      // Update conversation's last message
      await _db
          .from('conversations')
          .update({
            'last_message': text,
            'last_message_sender_id': 'ecokuha_assistant',
            'last_message_sender_name': 'EcoKuha Assistant',
            'last_message_timestamp': nowIso,
          })
          .eq('id', conversationId);

      debugPrint(
        '[PostingRepo] ✅ Sent repost system message to conversation $conversationId',
      );
    } catch (e) {
      debugPrint('[PostingRepo] ❌ Failed to send repost system message: $e');
    }
  }

  @override
  Future<String?> cancelPosting(String postingId) async {
    final enabled = flags.isEnabled('firestore_posting');
    final platformOk = _isPlatformSupported();

    debugPrint('[PostingRepo] Deleting posting $postingId');
    debugPrint('[PostingRepo] firestore_posting enabled: $enabled');
    debugPrint('[PostingRepo] platform supported: $platformOk');

    if (!enabled || !platformOk) {
      return null;
    }

    final user = _db.auth.currentUser;
    if (user == null) {
      debugPrint('[PostingRepo] No user logged in, cannot delete posting');
      return null;
    }
    final uid = user.id;

    try {
      // Get the posting row to retrieve image URLs and conversation info
      final data = await _db
          .from('postings')
          .select()
          .eq('id', postingId)
          .eq('household_id', uid)
          .maybeSingle();

      String? conversationId;
      final List<String> imageUrls = [];

      if (data != null) {
        // Conversation ID follows the pattern 'posting_{postingId}'
        conversationId = 'posting_$postingId';
        debugPrint('[PostingRepo] Associated conversation ID: $conversationId');

        // Extract image URLs from all items in the posting
        if (data['items'] != null) {
          // Handle both new nested structure and legacy flat structure
          List<dynamic> items = [];

          if (data['items'] is Map) {
            // New nested structure: items.list
            final itemsMap = data['items'] as Map;
            items = (itemsMap['list'] ?? []) as List<dynamic>;
          } else if (data['items'] is List) {
            // Legacy flat structure
            items = data['items'] as List<dynamic>;
          }

          for (final item in items) {
            if (item is Map && item['imagePaths'] != null) {
              final itemImages = item['imagePaths'] as List<dynamic>;
              for (final imageUrl in itemImages) {
                if (imageUrl is String && imageUrl.isNotEmpty) {
                  imageUrls.add(imageUrl);
                }
              }
            }
          }
          debugPrint(
            '[PostingRepo] Found ${imageUrls.length} images to delete from ${items.length} items',
          );
        }
      }

      // Delete images from Storage
      if (imageUrls.isNotEmpty) {
        await _deletePostingImages(imageUrls);
      }

      // Delete the posting row
      await _db
          .from('postings')
          .delete()
          .eq('id', postingId)
          .eq('household_id', uid);

      debugPrint('[PostingRepo] Posting deleted successfully: $postingId');
      return conversationId;
    } on PostgrestException catch (e) {
      debugPrint(
        '[PostingRepo] PostgrestException on delete: ${e.code} ${e.message}',
      );
      rethrow;
    }
  }

  /// Deletes images from Supabase Storage given their public URLs
  Future<void> _deletePostingImages(List<String> imageUrls) async {
    debugPrint(
      '[PostingRepo] Deleting ${imageUrls.length} images from Storage',
    );

    const marker = '/object/public/posting-images/';
    for (final url in imageUrls) {
      try {
        final idx = url.indexOf(marker);
        if (idx < 0) continue; // not one of our posting images
        var path = url.substring(idx + marker.length);
        final q = path.indexOf('?');
        if (q >= 0) path = path.substring(0, q);
        path = Uri.decodeComponent(path);
        await deleteStorageObject('posting-images', path);
        debugPrint('[PostingRepo] Deleted image: $path');
      } catch (e) {
        // Log error but continue deleting other images
        debugPrint('[PostingRepo] Failed to delete image $url: $e');
      }
    }

    debugPrint('[PostingRepo] Finished deleting images');
  }
  bool _isPlatformSupported() {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
        return true;
      default:
        return false;
    }
  }

  @override
  Future<List<CompletedCollection>> fetchCompletedCollections() async {
    debugPrint('[PostingRepo] fetchCompletedCollections() called - START');

    if (!_isPlatformSupported()) {
      debugPrint('[PostingRepo] Platform not supported');
      return [];
    }

    // Get current household user ID
    final user = _db.auth.currentUser;
    if (user == null) {
      debugPrint('[PostingRepo] No user logged in');
      return [];
    }

    final householdId = user.id;
    debugPrint('[PostingRepo] Current household ID = $householdId');

    try {
      // Query the household's completed, cancelled, and declined postings
      final rawRows = await _db
          .from('postings')
          .select()
          .eq('household_id', householdId)
          .inFilter('status', ['completed', 'cancelled', 'declined']);
      final rows = rowsToDocs('postings', rawRows);

      debugPrint(
        '[PostingRepo] Fetched ${rows.length} completed postings from Supabase',
      );
      final collections = rows.map((data) {
        final docId = data['id'].toString();
        debugPrint('[PostingRepo] Processing doc $docId');
        debugPrint(
          '[PostingRepo] Doc $docId ALL KEYS: ${data.keys.toList()}',
        );

        // Priority: purchasedItems > verifiedItems > items
        final purchasedItems = data['purchasedItems'];
        final verifiedItems = data['verifiedItems'];
        final items = data['items'];

        List<dynamic> rawItemsData = [];
        String dataSource = 'items';

        // Extract items from purchasedItems (final junkshop pricing)
        if (purchasedItems is Map<String, dynamic> &&
            purchasedItems['list'] is List) {
          rawItemsData = purchasedItems['list'] as List<dynamic>;
          dataSource = 'purchasedItems';
          debugPrint('[PostingRepo] Using purchasedItems.list');
        }
        // Extract items from verifiedItems (collector verification)
        else if (verifiedItems is Map<String, dynamic> &&
            verifiedItems['items'] is List) {
          rawItemsData = verifiedItems['items'] as List<dynamic>;
          dataSource = 'verifiedItems';
          debugPrint('[PostingRepo] Using verifiedItems.items');
        }
        // Legacy: verifiedItems as direct list
        else if (verifiedItems is List) {
          rawItemsData = verifiedItems;
          dataSource = 'verifiedItems (list)';
          debugPrint('[PostingRepo] Using verifiedItems as list');
        }
        // Fallback to items
        else if (items is List) {
          rawItemsData = items;
          dataSource = 'items';
          debugPrint('[PostingRepo] Using items');
        } else if (items is Map && items['itemsList'] is List) {
          rawItemsData = items['itemsList'] as List<dynamic>;
          dataSource = 'items.itemsList';
          debugPrint('[PostingRepo] Using items.itemsList');
        }

        debugPrint(
          '[PostingRepo] Data source: $dataSource, count: ${rawItemsData.length}',
        );

        // Convert to full item data maps and display strings
        final List<Map<String, dynamic>> fullItemsData = [];
        final itemsList = rawItemsData.map((item) {
          if (item is Map<String, dynamic>) {
            // Store full item data with all pricing info
            fullItemsData.add(Map<String, dynamic>.from(item));

            // Support both 'name' (household posting) and 'type' (collector verified)
            final name =
                item['name']?.toString() ??
                item['type']?.toString() ??
                'Unknown Item';
            final quantity = item['quantity']?.toString() ?? '0';
            final unit = item['unit']?.toString() ?? 'pcs';
            return '$name ($quantity $unit)';
          }
          return item.toString();
        }).toList();

        debugPrint(
          '[PostingRepo] Parsed ${itemsList.length} items with full data',
        );

        // Parse timestamps
        final createdTs = data['createdAt'];
        DateTime? createdAt;
        createdAt = toDateTime(createdTs);

        final scheduledTs = data['scheduledDate'];
        DateTime? scheduledDate;
        scheduledDate = toDateTime(scheduledTs);

        final collectedTs = data['dateOfCollection'];
        DateTime? collectedAt;
        collectedAt = toDateTime(collectedTs);

        final reviewedTs = data['reviewedAt'];
        DateTime? reviewedAt;
        reviewedAt = toDateTime(reviewedTs);

        // Parse declinedAt from declines map
        DateTime? declinedAt;
        final declinesData = data['declines'];
        if (declinesData != null && declinesData is Map<String, dynamic>) {
          final firstDecline = declinesData['1st'];
          if (firstDecline != null && firstDecline is Map<String, dynamic>) {
            final declinedAtTs = firstDecline['declinedAt'];
            declinedAt = toDateTime(declinedAtTs);
          }
        }

        // Parse rating deadline
        final ratingDeadlineTs = data['ratingDeadline'];
        DateTime? ratingDeadline;
        if (ratingDeadlineTs != null) {
          ratingDeadline = toDateTime(ratingDeadlineTs);
        } else if (collectedAt != null) {
          // Set default 30-day deadline if not set
          ratingDeadline = collectedAt.add(const Duration(days: 30));
        }

        // Parse proof photos
        final proofPhotos = <String, List<String>>{};
        final paymentProofUrls = <String>[];
        final rawPhotos = data['photos'];
        if (rawPhotos is Map<String, dynamic>) {
          for (final category in ['arrival', 'collection', 'before_after']) {
            final categoryPhotos = rawPhotos[category];
            if (categoryPhotos is List) {
              proofPhotos[category] = categoryPhotos
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          }

          // Extract payment proof
          final paymentPhotos = rawPhotos['payment'];
          if (paymentPhotos is List) {
            paymentProofUrls.addAll(
              paymentPhotos
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty)
                  .toList(),
            );
          }
        }

        // Extract image URLs from items
        final imageUrls = <String>[];
        if (rawItemsData.isNotEmpty) {
          for (final item in rawItemsData) {
            if (item is Map<String, dynamic>) {
              final itemImages = item['imagePaths'];
              if (itemImages is List) {
                for (final img in itemImages) {
                  if (img is String && img.isNotEmpty) {
                    imageUrls.add(img);
                  }
                }
              }
            }
          }
        }

        // Extract collector and junkshop data from nested objects
        final collectorData = data['collector'];
        final junkshopData = data['junkshop'];

        debugPrint(
          '[PostingRepo] Doc $docId: RAW collector = $collectorData',
        );
        debugPrint('[PostingRepo] Doc $docId: RAW junkshop = $junkshopData');
        debugPrint(
          '[PostingRepo] Doc $docId: collector type = ${collectorData.runtimeType}',
        );
        debugPrint(
          '[PostingRepo] Doc $docId: junkshop type = ${junkshopData.runtimeType}',
        );

        String? collectorName;
        String? collectorId;
        String? collectorPhoto;
        if (collectorData is Map<String, dynamic>) {
          debugPrint(
            '[PostingRepo] Doc $docId: collector MAP keys = ${collectorData.keys.toList()}',
          );
          collectorName = collectorData['full_name']?.toString();
          collectorId = collectorData['id']?.toString();
          collectorPhoto = collectorData['profile_image_url']?.toString();
          debugPrint(
            '[PostingRepo] Doc $docId: ✅ Extracted collectorName = "$collectorName"',
          );
        } else {
          debugPrint(
            '[PostingRepo] Doc $docId: ❌ collectorData is NOT a Map, it is ${collectorData.runtimeType}',
          );
        }

        String? junkshopName;
        String? junkshopId;
        if (junkshopData is Map<String, dynamic>) {
          debugPrint(
            '[PostingRepo] Doc $docId: junkshop MAP keys = ${junkshopData.keys.toList()}',
          );
          junkshopName = junkshopData['full_name']?.toString();
          junkshopId = junkshopData['id']?.toString();
          debugPrint(
            '[PostingRepo] Doc $docId: ✅ Extracted junkshopName = "$junkshopName"',
          );
        } else {
          debugPrint(
            '[PostingRepo] Doc $docId: ❌ junkshopData is NOT a Map, it is ${junkshopData.runtimeType}',
          );
        }

        return CompletedCollection(
          id: docId,
          householdId: householdId,
          items: itemsList,
          itemsData: fullItemsData,
          totalValue: (data['totalEstimatedValue'] as num?)?.toDouble() ?? 0.0,
          status: data['status']?.toString() ?? 'completed',
          createdAt: createdAt,
          scheduledDate: scheduledDate,
          collectedAt: collectedAt,
          reviewedAt: reviewedAt,
          declinedAt: declinedAt,
          junkshopName: junkshopName,
          junkshopId: junkshopId,
          collectorName: collectorName,
          collectorId: collectorId,
          collectorPhoto: collectorPhoto,
          addressShort: data['addressShort']?.toString(),
          specialInstructions: data['specialInstructions']?.toString(),
          proofPhotos: proofPhotos,
          paymentProofUrls: paymentProofUrls,
          imageUrls: imageUrls,
          isCollectorRated: data['isCollectorRated'] as bool?,
          isJunkshopRated: data['isJunkshopRated'] as bool?,
          ratingDeadline: ratingDeadline,
          collectorRating: (data['collectorRating'] as num?)?.toDouble(),
          junkshopRating: (data['junkshopRating'] as num?)?.toDouble(),
        );
      }).toList();

      debugPrint(
        '[PostingRepo] Created ${collections.length} CompletedCollection objects',
      );
      for (final c in collections) {
        debugPrint(
          '[PostingRepo] Collection ${c.id}: ${c.items.length} items, totalValue: ${c.totalValue}',
        );
      }

      // Sort by reviewedAt or collectedAt descending (newest first)
      collections.sort((a, b) {
        final aDate = a.reviewedAt ?? a.collectedAt ?? a.createdAt;
        final bDate = b.reviewedAt ?? b.collectedAt ?? b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      debugPrint(
        '[PostingRepo] Returning ${collections.length} completed collections',
      );
      return collections;
    } catch (e) {
      debugPrint('[PostingRepo] Error fetching completed collections: $e');
      return [];
    }
  }

  @override
  Future<void> submitCollectorRating({
    required String postingId,
    required double rating,
    required String reviewText,
    List<String>? selectedReasons,
  }) async {
    await _submitRating(
      targetType: 'collector',
      postingId: postingId,
      rating: rating,
      reviewText: reviewText,
      selectedReasons: selectedReasons,
    );
  }

  @override
  Future<void> submitJunkshopRating({
    required String postingId,
    required double rating,
    required String reviewText,
    List<String>? selectedReasons,
  }) async {
    await _submitRating(
      targetType: 'junkshop',
      postingId: postingId,
      rating: rating,
      reviewText: reviewText,
      selectedReasons: selectedReasons,
    );
  }

  /// Inserts into `ratings`; a DB trigger updates the posting + aggregates.
  Future<void> _submitRating({
    required String targetType, // 'collector' | 'junkshop'
    required String postingId,
    required double rating,
    required String reviewText,
    List<String>? selectedReasons,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final posting = await _db
          .from('postings')
          .select('collector_id, junkshop_id, collector, junkshop')
          .eq('id', postingId)
          .maybeSingle();
      if (posting == null) throw Exception('Posting not found');

      String? targetId = posting['${targetType}_id']?.toString();
      if (targetId == null || targetId.isEmpty) {
        final nested = posting[targetType];
        if (nested is Map) targetId = nested['id']?.toString();
      }
      if (targetId == null || targetId.isEmpty) {
        throw Exception('This posting has no $targetType to rate');
      }

      await _db.from('ratings').insert({
        'posting_id': postingId,
        'target_type': targetType,
        'target_id': targetId,
        'rated_by': user.id,
        'rating': rating,
        'review_text': reviewText,
        'selected_reasons': selectedReasons ?? <String>[],
      });

      debugPrint('[PostingRepo] $targetType rating submitted');
    } on PostgrestException catch (e) {
      debugPrint('[PostingRepo] Error submitting $targetType rating: $e');
      if (e.code == '23505') {
        throw Exception('You have already rated this $targetType');
      }
      if (e.code == '42501') {
        throw Exception(
          'Rating is not allowed (collection not completed or rating period has ended)',
        );
      }
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[PostingRepo] Error submitting $targetType rating: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getCollectionRating(String postingId) async {
    final user = _db.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _db
          .from('postings')
          .select()
          .eq('id', postingId)
          .eq('household_id', user.id)
          .maybeSingle();

      if (row == null) return null;

      final data = rowToDoc('postings', row);
      if (data['isRated'] == true && data['ratingData'] is Map) {
        return Map<String, dynamic>.from(data['ratingData'] as Map);
      }
      return null;
    } catch (e) {
      debugPrint('[PostingRepo] Error getting rating: $e');
      return null;
    }
  }
}
