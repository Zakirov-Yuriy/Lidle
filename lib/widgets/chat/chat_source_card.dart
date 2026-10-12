import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/chat_source.dart';

/// Карточка «откуда покупатель написал» (09.10.2026, задача 15).
///
/// Одна вёрстка на все пять видов: объявление, товар, предложение цены,
/// отклик, бронь. Отличия только в двух необязательных строках.
///
///   note       жёлтая строка, предложенная цена
///   startsAt   дата и время брони
///
/// Переход наружу делает не карточка, а тот, кто её поставил: экран знает,
/// куда идти и что делать с навигацией.
///
/// С 12.10.2026 у карточки два вида.
///
/// Обычный это прежняя плашка в шапке переписки, со своими отступами и
/// фоном. Сейчас в чате она не используется, но остаётся: вёрстка может
/// понадобиться на других экранах.
///
/// `inBubble` это карточка ВНУТРИ пузыря сообщения. Она появляется у того
/// сообщения, с которого начался разговор о конкретном объявлении, товаре
/// или брони, и остаётся в ленте навсегда. У неё нет внешних отступов, а фон
/// полупрозрачный тёмный: пузырь бывает и синим, и серым, и карточка обязана
/// читаться на обоих.
class ChatSourceCard extends StatelessWidget {
  final ChatSource source;
  final VoidCallback? onOpen;

  /// Карточка рисуется внутри пузыря сообщения, а не в шапке переписки.
  final bool inBubble;

  const ChatSourceCard({
    super.key,
    required this.source,
    this.onOpen,
    this.inBubble = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(inBubble ? 8 : 3),
      child: Container(
        decoration: BoxDecoration(
          color: inBubble ? const Color(0x33000000) : formBackground,
        ),
        padding: EdgeInsets.all(inBubble ? 8 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _image(),
            const SizedBox(width: 12),
            Expanded(child: _texts()),
          ],
        ),
      ),
    );

    if (inBubble) {
      return card;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: card,
    );
  }

  Widget _image() {
    const double side = 66;
    final url = source.image;

    if (url == null || !url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 86,
          height: side,
          color: const Color(0xFF2A3942),
          child: const Icon(Icons.image_outlined, color: Colors.white38),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 86,
        height: side,
        fit: BoxFit.cover,
        // Картинка может не дойти: объявление старое, файл убрали. Это не
        // повод оставлять дыру в шапке, показываем заглушку.
        errorBuilder: (_, __, ___) => Container(
          width: 86,
          height: side,
          color: const Color(0xFF2A3942),
          child: const Icon(Icons.image_outlined, color: Colors.white38),
        ),
      ),
    );
  }

  Widget _texts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          source.title ?? 'Без названия',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        if (source.price != null) ...[
          const SizedBox(height: 2),
          Text(
            source.price!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        // Предложенная цена. Жёлтым, потому что ради неё продавец и открыл
        // переписку.
        if (source.note != null) ...[
          const SizedBox(height: 2),
          Text(
            source.note!,
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        // Дата брони. Без неё продавец не поймёт, о каком визите речь, и
        // это первое, что он спросит.
        if (source.startsAt != null) ...[
          const SizedBox(height: 2),
          Text(
            source.startsAt!,
            style: const TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 4),
        if (onOpen != null)
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Перейти',
                  style: TextStyle(
                    color: Color(0xFF00B7FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF00B7FF),
                  size: 14,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
