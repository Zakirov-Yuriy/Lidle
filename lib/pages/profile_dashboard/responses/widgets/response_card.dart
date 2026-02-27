import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/reject_offer_dialog.dart';
import 'package:lidle/pages/profile_dashboard/responses/response_chat_page.dart';
import 'package:lidle/pages/profile_dashboard/responses/accept_response_page.dart';
import 'package:lidle/pages/profile_dashboard/responses/completion_deal_page.dart';
import 'package:lidle/pages/profile_dashboard/responses/user_account_page.dart';

class ResponseCard extends StatelessWidget {
  final ResponseModel response;
  final String? status;
  final VoidCallback? onArchive;
  final VoidCallback? onReject;
  final String? archiveReason;
  final bool isSelected;
  final Function(bool)? onSelectionChanged;
  final bool showCheckbox;
  final VoidCallback? onLongPress;

  const ResponseCard({
    super.key,
    required this.response,
    this.status,
    this.onArchive,
    this.onReject,
    this.archiveReason,
    this.isSelected = false,
    this.onSelectionChanged,
    this.showCheckbox = false,
    this.onLongPress,
  });

  String get _buttonText =>
      status == 'Выполянется' ? 'Завершить' : 'Принять заявку';

  @override
  Widget build(BuildContext context) {
    if (status == 'Архив') {
      return GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showCheckbox) ...[
                    CustomCheckbox(
                      value: isSelected,
                      onChanged: (value) {
                        onSelectionChanged?.call(value);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    response.category,
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    archiveReason == 'rejected' ? 'Отказано' : 'Выполнена',
                    style: TextStyle(
                      color: archiveReason == 'rejected'
                          ? Colors.red
                          : Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                '${response.title}: ${response.price.toInt()} ₽ за услугу',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // print();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              UserAccountPage(response: response),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 32,
                      backgroundImage: AssetImage(response.userAvatar),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            // print();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserAccountPage(response: response),
                              ),
                            );
                          },
                          child: Text(
                            response.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Рейтинг',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < response.rating.floor()
                                  ? Icons.star
                                  : index < response.rating
                                  ? Icons.star_half
                                  : Icons.star_border,
                              color: Colors.orange,
                              size: 16,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ResponseChatPage(response: response),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00B7FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Написать',
                        style: TextStyle(color: Color(0xFF00B7FF)),
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

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (showCheckbox) ...[
                        CustomCheckbox(
                          value: isSelected,
                          onChanged: (value) {
                            onSelectionChanged?.call(value);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          response.category,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    status!,
                    style: TextStyle(
                      color: status == 'Выполняется'
                          ? const Color.fromARGB(255, 255, 193, 7)
                          : Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${response.title}: ${response.price.toInt()} ₽ за услугу',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // print('🔄 Переход на UserAccountPage из response_card...');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            UserAccountPage(response: response),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: AssetImage(response.userAvatar),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // print();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserAccountPage(response: response),
                            ),
                          );
                        },
                        child: Text(
                          response.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Рейтинг',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < response.rating.floor()
                                ? Icons.star
                                : index < response.rating
                                ? Icons.star_half
                                : Icons.star_border,
                            color: Colors.orange,
                            size: 16,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (status == 'Выполняется') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ResponseChatPage(response: response),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00B7FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Написать',
                        style: TextStyle(color: Color(0xFF00B7FF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CompletionDealPage(
                              response: response,
                              onArchive: onArchive,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1ED760),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Завершить',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const RejectOfferDialog(),
                        ).then((_) {
                          // After dialog is closed, call the reject callback if provided
                          onReject?.call();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Отклонить',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ResponseChatPage(response: response),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00B7FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Написать',
                        style: TextStyle(color: Color(0xFF00B7FF)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AcceptResponsePage(
                          response: response,
                          status: status,
                          onArchive: onArchive,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1ED760),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    _buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


