import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/chat_source.dart';

/// Плашка «откуда покупатель написал» (09.10.2026, задача 15).
///
/// Стоит под серой чертой в шапке переписки. Одна вёрстка на все пять
/// видов: объявление, товар, предложение цены, отклик, бронь. Отличия
/// только в двух необязательных строках.
///
///   note       жёлтая строка, предложенная цена
///   startsAt   дата и время брони
///
/// Переход наружу делает не плашка, а тот, кто её поставил: экран знает,
/// куда идти и что делать с навигацией.
class ChatSourceCard extends StatelessWidget {
  final ChatSource source;
  final VoidCallback? onOpen;

  const ChatSourceCard({super.key, required this.source, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          decoration: BoxDecoration(color: formBackground),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _image(),
              const SizedBox(width: 12),
              Expanded(child: _texts()),
            ],
          ),
        ),
      ),
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
