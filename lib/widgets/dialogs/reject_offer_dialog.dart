import 'package:flutter/material.dart';
import 'package:lidle/pages/profile_dashboard/offers/incoming_price_offer_page.dart';

class RejectOfferDialog extends StatelessWidget {
  const RejectOfferDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: IncomingPriceOfferPage.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // Spacer for centering title
                
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const Text(
                  'Отклонить заявку',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            const SizedBox(height: 22),
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: 'Внимание: ',
                    style: TextStyle(
                      color: Color(0xFFD4E157), // Yellowish color from image
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: 'если вы хотите \nотклонить заявку.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Потрердите действие',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: IncomingPriceOfferPage.accentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      // Handle confirmation
                      Navigator.of(context).pop(true);
                    },
                    child: const Text(
                      'Потвердить',
                      style: TextStyle(
                        color: IncomingPriceOfferPage.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
