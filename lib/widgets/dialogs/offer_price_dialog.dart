// ============================================================
//  "Диалог предложения цены"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class OfferPriceDialog extends StatelessWidget {
  const OfferPriceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor:
          primaryBackground, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.only(top: 25.0, left: 12.0, right: 12.0,  bottom: 37.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Предложить свою цену",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                const Text(
                  "Ваша цена",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _buildInputField(
              hintText: "Сумма",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Text(
                  "Почему, вы предлагаете другую цену",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _buildInputField(hintText: "Сообщение продавцу", maxLines: 5),
            // Add a button here if needed, or other actions
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.blue, // A distinct color for the action button
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 110,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  "Отправить",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor:
            formBackground, // Assuming formBackground is a slightly lighter dark color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
      ),
    );
  }
}
