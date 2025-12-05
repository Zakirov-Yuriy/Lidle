import 'package:flutter/material.dart';

class CustomErrorSnackBar extends StatelessWidget {
  final String message;
  final VoidCallback? onClose;

  const CustomErrorSnackBar({super.key, required this.message, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // Make the material transparent to show the custom background
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C), // Dark background color from the image
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded, // Warning icon (closest Flutter icon)
              color: Color(0xFFEF5350), // Red color for the icon
              size: 24.0,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (onClose != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }
}
