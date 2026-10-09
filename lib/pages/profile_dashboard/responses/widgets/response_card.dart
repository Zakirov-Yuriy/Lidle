import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/response_model.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/dialogs/reject_offer_dialog.dart';
import 'package:lidle/pages/profile_dashboard/responses/accept_response_page.dart';
import 'package:lidle/pages/profile_dashboard/responses/completion_deal_page.dart';
import 'package:lidle/pages/profile_dashboard/responses/user_account_page.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/message_model.dart';
import 'package:lidle/pages/messages/chat_page.dart';

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

  /// Принять отклик (09.10.2026).
  ///
  /// Передан — кнопка «Принять заявку» меняет состояние отклика на сервере,
  /// а не открывает экран-макет. Не передан — поведение прежнее.
  final VoidCallback? onAccept;

  /// Завершить работу по отклику (09.10.2026).
  ///
  /// Передан — кнопка «Завершить» меняет состояние на сервере, а не
  /// открывает экран-макет.
  final VoidCallback? onComplete;

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
    this.onAccept,
    this.onComplete,
  });

  String get _buttonText =>
      status == 'Выполянется' ? 'Завершить' : 'Принять заявку';

  /// Заголовок с ценой.
  ///
  /// Цены может не быть вовсе: в отклике она необязательна, а дописывать
  /// «0 ₽ за услугу» значит показывать человеку неправду.
  String get _titleLine {
    final title = response.title.trim().isEmpty ? 'Объявление' : response.title;

    return response.price > 0
        ? '$title: ${response.price.toInt()} ₽'
        : title;
  }

  /// Аватарка.
  ///
  /// Сетевая, если она есть, иначе заглушка. Раньше здесь был безусловный
  /// `AssetImage(response.userAvatar)`, и с настоящими данными это ссылка
  /// вида https://..., то есть пустой серый круг или ошибка.
  Widget _avatar() {
    final url = response.avatarUrl;

    if (url != null && url.startsWith('http')) {
      return CircleAvatar(radius: 32, backgroundImage: NetworkImage(url));
    }

    if (response.userAvatar.isNotEmpty && !response.userAvatar.startsWith('http')) {
      return CircleAvatar(
        radius: 32,
        backgroundImage: AssetImage(response.userAvatar),
      );
    }

    return const CircleAvatar(
      radius: 32,
      backgroundColor: Color(0xFF374B5C),
      child: Icon(Icons.person, color: Colors.white54, size: 32),
    );
  }

  /// Открыть переписку с этим человеком.
  ///
  /// Плашку над диалогом собирает сервер по виду и номеру источника, поэтому
  /// передаём `response` и номер отклика: в шапке появится то объявление, на
  /// которое откликнулись.
  void _openChat(BuildContext context) {
    final message = Message(
      senderName: response.userName,
      senderAvatar: response.avatarUrl,
      lastMessageTime: '',
      unreadCount: 0,
      isInternal: true,
      isCompany: false,
      userId: response.userId,
      advertTitle: response.title,
      advertImage: response.advertImage,
      advertPrice: response.price > 0 ? '${response.price.toInt()}' : null,
      advertisementId: response.advertId?.toString(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          message: message,
          sourceType: 'response',
          sourceId: response.responseId,
        ),
      ),
    );
  }

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
                _titleLine,
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
                      // log.d();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              UserAccountPage(response: response),
                        ),
                      );
                    },
                    child: _avatar(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            // log.d();
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
                        // Рейтинг показываем ТОЛЬКО когда он есть. Пустые
                        // звёзды читаются как «плохой исполнитель», а не как
                        // «его ещё никто не оценивал».
                        if (response.rating > 0) ...[
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
                      onPressed: () => _openChat(context),
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
              _titleLine,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Текст отклика. Это главное в отклике: автор объявления решает
            // по нему, а не по цене.
            if ((response.message ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                response.message!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // log.d('🔄 Переход на UserAccountPage из response_card...');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            UserAccountPage(response: response),
                      ),
                    );
                  },
                  child: _avatar(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // log.d();
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
                      if (response.rating > 0) ...[
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Решать судьбу отклика может только автор объявления. На
            // вкладке «Мои отклики» экран не передаёт колбэков, и тогда
            // остаётся одна кнопка «Написать»: принимать собственный отклик
            // человеку нечего.
            if (onAccept == null && onReject == null && status != 'Выполняется') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _openChat(context),
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
            ] else if (status == 'Выполняется') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openChat(context),
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
                        if (onComplete != null) {
                          onComplete!.call();

                          return;
                        }

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
                      onPressed: () => _openChat(context),
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
                    if (onAccept != null) {
                      onAccept!.call();

                      return;
                    }

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


