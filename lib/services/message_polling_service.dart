// ============================================================
// Message Polling Service
// ============================================================
// Periodically checks for new messages and sends push notifications
// for incoming messages from other users (not own messages)

import 'dart:async';
import 'package:lidle/services/notification_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:logger/logger.dart';

class MessagePollingService {
  static final MessagePollingService _instance =
      MessagePollingService._internal();
  static final _logger = Logger();

  late Timer _pollingTimer;
  bool _isPolling = false;

  // Stores the last message ID for each chat
  // Used to detect new messages
  final Map<int, dynamic> _lastMessageIds = {};

  factory MessagePollingService() {
    return _instance;
  }

  MessagePollingService._internal();

  /// Start polling for new messages
  void startPolling({Duration interval = const Duration(seconds: 10)}) {
    if (_isPolling) {
      _logger.w('Polling already running');
      return;
    }

    _isPolling = true;
    _logger.i('Starting polling (interval: ${interval.inSeconds}s)');

    // First check immediately
    _checkNewMessages();

    // Then periodically
    _pollingTimer = Timer.periodic(interval, (_) {
      _checkNewMessages();
    });
  }

  /// Stop polling
  void stopPolling() {
    if (!_isPolling) {
      _logger.w('Polling not running');
      return;
    }

    _pollingTimer.cancel();
    _isPolling = false;
    _logger.i('Polling stopped');
  }

  /// Check for new messages in all chats
  Future<void> _checkNewMessages() async {
    try {
      _logger.d('Checking new messages in ${_lastMessageIds.length} chats');
      
      final chats = await ApiService.getChats();
      _logger.d('Loaded ${chats.length} chats');

      for (final chat in chats) {
        final chatId = chat['id'] as int?;
        if (chatId == null) continue;

        await _checkChatMessages(chatId, chat);
      }
      
      _logger.d('Message check completed');
    } catch (e) {
      _logger.e('Error polling messages: $e');
    }
  }

  /// Check for new messages in a specific chat
  Future<void> _checkChatMessages(int chatId, Map<String, dynamic> chat) async {
    try {
      // Load messages from chat
      final messages = await ApiService.getChatMessages(chatId);

      if (messages.isEmpty) {
        _logger.w('Chat #$chatId: no messages');
        return;
      }

      // Get sender info from chat data
      final senderName = chat['participant_name'] ?? chat['name'] ?? 'New message';
      final senderImage = chat['participant_avatar'];
      
      _logger.d('[CHAT#$chatId] senderName=$senderName, hasAvatar=${senderImage != null}');
      
      // Get last message (first item, as list is sorted by descending ID)
      final lastMessage = messages.isNotEmpty ? messages.first : null;

      if (lastMessage == null) {
        _logger.w('Chat #$chatId: last message is null');
        return;
      }

      final lastMessageId = lastMessage['id'];
      final messageText = lastMessage['content'] ?? lastMessage['message'] ?? '';
      
      // DEBUG: Log FULL message structure to understand what fields exist
      _logger.i('═════════════════════════════════════════════════════');
      _logger.i('FULL MESSAGE STRUCTURE FOR CHAT #$chatId:');
      _logger.i('─────────────────────────────────────────────────────');
      _logger.i('Keys in message: ${lastMessage.keys.toList()}');
      lastMessage.forEach((key, value) {
        _logger.i('  $key: $value (type: ${value.runtimeType})');
      });
      _logger.i('═════════════════════════════════════════════════════');
      
      // Try to find sender ID in different possible fields
      final userId = lastMessage['user_id'];
      final senderId2 = lastMessage['sender_id'];
      final authorId = lastMessage['author_id'];
      final fromId = lastMessage['from_id'];
      final user = lastMessage['user'];
      final sender = lastMessage['sender'];
      
      _logger.i('[FIELDS] Checking possible sender ID fields:');
      _logger.i('  user_id: $userId');
      _logger.i('  sender_id: $senderId2');
      _logger.i('  author_id: $authorId');
      _logger.i('  from_id: $fromId');
      _logger.i('  user (object): $user');
      _logger.i('  sender (object): $sender');
      
      // Extract senderId - try multiple field names
      dynamic senderId = userId ?? senderId2 ?? authorId ?? fromId;
      
      // If senderId is still null, try extracting from user/sender objects
      if (senderId == null && user is Map<String, dynamic>) {
        senderId = user['id'];
        _logger.i('  Extracted senderId from user.id: $senderId');
      }
      if (senderId == null && sender is Map<String, dynamic>) {
        senderId = sender['id'];
        _logger.i('  Extracted senderId from sender.id: $senderId');
      }
      
      _logger.i('[SENDER] Final senderId: $senderId (type: ${senderId.runtimeType})');

      // First time seeing this chat - just save the ID
      if (!_lastMessageIds.containsKey(chatId)) {
        _lastMessageIds[chatId] = lastMessageId;
        _logger.i('[CHAT#$chatId] First check - saving ID=$lastMessageId');
        await _saveLastMessageId(chatId, lastMessageId);
        return;
      }

      // Check if there are new messages
      final previousLastMessageId = _lastMessageIds[chatId];
      
      // Compare as strings for reliability
      final lastMessageIdStr = lastMessageId.toString();
      final previousLastMessageIdStr = previousLastMessageId.toString();

      if (lastMessageIdStr != previousLastMessageIdStr) {
        _logger.i('[MSG#$lastMessageId] New message detected in chat #$chatId from $senderName');

        // CRITICAL: Get current user ID
        final currentUserId = UserService.getLocal('userId');
        
        _logger.i('═════════════════════════════════════════════════════');
        _logger.i('SENDER VERIFICATION:');
        _logger.i('─────────────────────────────────────────────────────');
        _logger.i('senderId (from message): $senderId');
        _logger.i('  type: ${senderId.runtimeType}');
        _logger.i('  string value: "${senderId?.toString()}"');
        _logger.i('');
        _logger.i('currentUserId (from UserService): $currentUserId');
        _logger.i('  type: ${currentUserId.runtimeType}');
        _logger.i('  string value: "$currentUserId"');
        _logger.i('═════════════════════════════════════════════════════');
        
        // Safe comparison
        final senderIdStr = senderId?.toString().trim();
        final currentUserIdStr = currentUserId?.toString().trim();
        
        _logger.i('[COMPARISON]');
        _logger.i('  senderIdStr: "$senderIdStr" (isEmpty: ${senderIdStr?.isEmpty ?? "null"})');
        _logger.i('  currentUserIdStr: "$currentUserIdStr" (isEmpty: ${currentUserIdStr?.isEmpty ?? "null"})');
        
        final isOwnMessage = senderIdStr != null && 
                             currentUserIdStr != null && 
                             senderIdStr.isNotEmpty && 
                             currentUserIdStr.isNotEmpty &&
                             senderIdStr == currentUserIdStr;
        
        _logger.i('  Result: "$senderIdStr" == "$currentUserIdStr" = $isOwnMessage');
        
        if (isOwnMessage) {
          _logger.w('⛔ OWN MESSAGE - BLOCKING NOTIFICATION');
          _logger.w('   senderId=$senderIdStr matches currentUserId=$currentUserIdStr');
          _lastMessageIds[chatId] = lastMessageId;
          await _saveLastMessageId(chatId, lastMessageId);
          return;
        }
        
        _logger.i('✅ INCOMING MESSAGE - SENDING NOTIFICATION');
        _logger.i('   senderId=$senderIdStr DIFFERS FROM currentUserId=$currentUserIdStr');
        
        // Send push notification
        await NotificationService().showChatMessageNotification(
          senderName: senderName,
          messageText: messageText,
          chatId: chatId,
          senderImage: senderImage,
        );

        // Update last message ID
        _lastMessageIds[chatId] = lastMessageId;

        // Save to local storage
        await _saveLastMessageId(chatId, lastMessageId);
      } else {
        _logger.d('[CHAT#$chatId] No new messages (same ID=$lastMessageId)');
      }
    } catch (e) {
      _logger.e('Error checking messages in chat #$chatId: $e');
    }
  }

  /// Execute one-time message check (for background tasks)
  Future<void> checkNewMessagesOnce() async {
    try {
      _logger.i('One-time message check (background)');
      
      // Load saved IDs if not already loaded
      if (_lastMessageIds.isEmpty) {
        await loadLastMessageIds();
      }
      
      // Perform check
      await _checkNewMessages();
      
      _logger.i('One-time check completed');
    } catch (e) {
      _logger.e('Error in one-time check: $e');
    }
  }

  /// Load saved message IDs from storage
  Future<void> loadLastMessageIds() async {
    try {
      _logger.i('Loading saved message IDs from Hive');
      
      final stored =
          HiveService.getUserData('last_message_ids') as Map<dynamic, dynamic>?;
      if (stored != null) {
        _lastMessageIds.clear();
        stored.forEach((key, value) {
          final chatId = int.tryParse(key.toString());
          if (chatId != null) {
            _lastMessageIds[chatId] = value;
          }
        });
        _logger.i('Loaded IDs for ${_lastMessageIds.length} chats');
      } else {
        _logger.i('No saved message IDs found (first run)');
      }
    } catch (e) {
      _logger.e('Error loading saved IDs: $e');
    }
  }

  /// Save last message ID to storage
  Future<void> _saveLastMessageId(int chatId, dynamic messageId) async {
    try {
      final stored = HiveService.getUserData('last_message_ids') as Map<dynamic, dynamic>? ?? {};
      final mutableMap = Map<dynamic, dynamic>.from(stored);
      mutableMap[chatId.toString()] = messageId;
      await HiveService.saveUserData('last_message_ids', mutableMap);
    } catch (e) {
      _logger.e('Error saving message ID: $e');
    }
  }

  /// Get polling status
  bool get isPolling => _isPolling;

  /// Get number of monitored chats
  int get monitoredChatsCount => _lastMessageIds.length;
}
