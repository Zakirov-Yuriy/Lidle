import 'package:flutter/material.dart';
import 'package:lidle/models/message_model.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

class MessageCard extends StatelessWidget {
  final Message message;
  final bool isSelected;
  final ValueChanged<bool?> onCheckboxChanged;
  final VoidCallback? onTap;
  final bool showCheckboxes;

  const MessageCard({
    super.key,
    required this.message,
    required this.isSelected,
    required this.onCheckboxChanged,
    this.onTap,
    required this.showCheckboxes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      child: Row(
        children: [
          if (showCheckboxes)
            CustomCheckbox(
              value: isSelected,
              onChanged: (newValue) => onCheckboxChanged(newValue),
            ),
          if (showCheckboxes) const SizedBox(width: 8),
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white10,
            backgroundImage: message.senderAvatar != null
                ? AssetImage(message.senderAvatar!)
                : null,
            child: message.senderAvatar == null
                ? const Icon(
                    Icons.person,
                    color: Colors.white54,
                    size: 28,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.senderName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    message.lastMessageTime,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          if (message.unreadCount > 0)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: message.unreadCount >= 10 ? 5 : 9,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00B7FF) : Colors.transparent, // Blue background when selected
                border: isSelected ? null : Border.all(color: Colors.grey, width: 1), // Gray border when not selected
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                message.unreadCount.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey, // White text when selected, gray when not
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
