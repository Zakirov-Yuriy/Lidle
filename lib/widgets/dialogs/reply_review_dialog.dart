import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class ReplyReviewDialog extends StatefulWidget {
  const ReplyReviewDialog({super.key});

  @override
  State<ReplyReviewDialog> createState() => _ReplyReviewDialogState();
}

class _ReplyReviewDialogState extends State<ReplyReviewDialog> {
  final TextEditingController _replyController = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Ответить на отзыв',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
              ],
            ),
            const SizedBox(height: 13
            ),
            Row(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Оставить оценку',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final starWidth = constraints.maxWidth / 5;
                    final rating = (details.localPosition.dx / starWidth).ceil().clamp(1, 5);
                    setState(() => _rating = rating);
                  },
                  onHorizontalDragUpdate: (details) {
                    final starWidth = constraints.maxWidth / 5;
                    final rating = (details.localPosition.dx / starWidth).ceil().clamp(1, 5);
                    setState(() => _rating = rating);
                  },
                  child: Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < _rating ? Icons.star : Icons.star,
                        color: index < _rating ? Colors.amber : Colors.white54,
                        size: 20,
                      );
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Оставить ответ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _replyController,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Сообщение продавцу',
                hintStyle: const TextStyle(color: Colors.white54),
                fillColor: formBackground,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      inherit: false,
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                      decorationThickness: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 21),
                OutlinedButton(
                  onPressed: () {
                    // TODO: Implement send reply functionality
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: activeIconColor, width: 1.4),
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Отправить',
                    style: TextStyle(
                      color: activeIconColor,
                      fontSize: 16,
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
