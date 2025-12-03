import 'package:flutter/material.dart';
import 'package:lidle/constants.dart'; // Assuming constants.dart has required colors
import 'package:url_launcher/url_launcher.dart'; // For making phone calls

class PhoneDialog extends StatelessWidget {
  final List<String> phoneNumbers;

  const PhoneDialog({super.key, required this.phoneNumbers});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'\D'), ''), // Clean the number for dialing
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      // Optionally show an error message if the call cannot be made
      // For example, ScaffoldMessenger.of(context).showSnackBar(...)
      print('Could not launch $launchUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground, // Make dialog background transparent
      insetPadding: const EdgeInsets.symmetric(horizontal: 40), // Padding from screen edges
      child: Container(
        decoration: BoxDecoration(
          color: primaryBackground, // Dark background as per image, assuming from constants.dart
          borderRadius: BorderRadius.circular(5), // Rounded corners
        ),
        padding: const EdgeInsets.only(left: 25.0, right: 25.0, bottom: 43.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content vertically
          
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                      icon: const Icon(Icons.close, color: Colors.white), // Close button
                      onPressed: () => Navigator.of(context).pop(),
                    ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Телефоны",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                
              ],
            ),
            const SizedBox(height: 20),
            ...phoneNumbers.map((number) => Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    number,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _makePhoneCall(number),
                    child: Container(
                      height: 43,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF19D849)), // Green border
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          "Позвонить",
                          style: TextStyle(color: Color(0xFF19D849), fontSize: 16), // Green text
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}
