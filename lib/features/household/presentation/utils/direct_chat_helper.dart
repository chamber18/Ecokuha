import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../messaging/data/models/conversation_model.dart';
import '../../../messaging/data/repositories/chat_repository.dart';

/// Opens (or creates) the direct household <-> junkshop conversation
/// (`direct_{householdId}_{junkshopId}`) through [ChatRepository].
class DirectChatHelper {
  DirectChatHelper._();

  static Future<ConversationModel?> getOrCreate({
    required String currentUserId,
    required String junkshopId,
    required String junkshopName,
    String? junkshopProfileImage,
    bool sendInitialMessage = true,
  }) async {
    final db = Supabase.instance.client;
    final chatRepository = ChatRepository();
    final directConversationId = 'direct_${currentUserId}_$junkshopId';

    final existing = await db
        .from('conversations')
        .select()
        .eq('id', directConversationId)
        .maybeSingle();

    if (existing != null) {
      // If this user previously deleted the conversation, restore it so it
      // appears in the inbox again.
      final deletedBy = List<String>.from(
        (existing['deleted_by'] as List? ?? []).map((e) => e.toString()),
      );
      if (deletedBy.contains(currentUserId)) {
        await chatRepository.restoreConversationForUser(
          conversationId: directConversationId,
          userId: currentUserId,
        );
      }
      return ConversationModel.fromMap(existing);
    }

    final household = await db
        .from('households')
        .select('full_name, profile_image_url')
        .eq('id', currentUserId)
        .maybeSingle();
    final householdName = (household?['full_name'] as String?) ?? 'Household';
    final householdProfileImage = household?['profile_image_url'] as String?;

    String? shopImage = junkshopProfileImage;
    if (shopImage == null) {
      final shop = await db
          .from('junkshops')
          .select('profile_image_url')
          .eq('id', junkshopId)
          .maybeSingle();
      shopImage = shop?['profile_image_url'] as String?;
    }

    final conversationId = await chatRepository.createConversation(
      postingId: directConversationId,
      participants: [currentUserId, junkshopId],
      participantDetails: {
        currentUserId: ParticipantDetails(
          name: householdName,
          role: 'household',
          profileImage: householdProfileImage,
          joinedAt: DateTime.now(),
        ),
        junkshopId: ParticipantDetails(
          name: junkshopName,
          role: 'junkshop',
          profileImage: shopImage,
          joinedAt: DateTime.now(),
        ),
      },
      initialMessage: sendInitialMessage
          ? 'Chat started with $junkshopName'
          : null,
    );

    final created = await db
        .from('conversations')
        .select()
        .eq('id', conversationId)
        .maybeSingle();
    return created == null ? null : ConversationModel.fromMap(created);
  }
}
